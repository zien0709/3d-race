extends VehicleBody3D

@export var engine_power: float = 2600.0
@export var reverse_engine_power: float = 900.0
@export var brake_power: float = 45.0
@export var rolling_brake: float = 1.5
@export var parking_brake: float = 12.0
@export var max_speed: float = 33.0
@export var reverse_speed: float = 9.0
@export var max_steer_angle_degrees: float = 24.0
@export var steering_speed: float = 2.4
@export var high_speed_steer_ratio: float = 0.28
@export var downforce: float = 38.0
@export var upright_strength: float = 16000.0
@export var upright_damping: float = 3400.0
@export var fall_respawn_height: float = -5.0
@export var shift_duration: float = 0.18
@export var road_tire_grip: float = 2.3
@export var grass_tire_grip: float = 1.25
@export var grass_engine_multiplier: float = 0.62
@export var grass_drag_acceleration: float = 1.4
@export var grass_coast_brake: float = 5.0
@export var is_local_player: bool = true

@onready var race_manager: Node = _find_race_manager()

var spawn_transform: Transform3D
var current_gear: int = 1
var engine_rpm: float = 900.0
var shift_timer: float = 0.0
var grass_contact_ratio: float = 0.0
var road_surface_lookup_ready: bool = false
var road_triangles: Array[PackedVector2Array] = []
var road_triangle_grid: Dictionary = {}

const MAX_FORWARD_GEAR := 5
const ROAD_GRID_CELL_SIZE := 4.0
const UPSHIFT_SPEEDS := [0.0, 8.5, 15.0, 22.0, 28.0, 999.0]
const DOWNSHIFT_SPEEDS := [0.0, 0.0, 6.5, 13.0, 20.0, 26.0]
const GEAR_FORCE_MULTIPLIERS := [0.0, 1.20, 1.08, 0.98, 0.89, 0.80]
const GEAR_RPM_SPEED_RANGES := [
	Vector2(0.0, 1.0),
	Vector2(0.0, 10.0),
	Vector2(5.0, 17.5),
	Vector2(12.0, 25.0),
	Vector2(19.0, 31.0),
	Vector2(25.0, 34.0),
]

const WHEEL_SETTINGS := {
	"FL": {
		"position": Vector3(-0.7095, 0.50, -1.2254),
		"steering": true,
		"traction": false,
	},
	"FR": {
		"position": Vector3(0.7095, 0.50, -1.2254),
		"steering": true,
		"traction": false,
	},
	"RL": {
		"position": Vector3(-0.7095, 0.50, 1.1637),
		"steering": false,
		"traction": true,
	},
	"RR": {
		"position": Vector3(0.7095, 0.50, 1.1637),
		"steering": false,
		"traction": true,
	},
}


func _ready() -> void:
	_configure_model_wheels()
	_build_road_surface_lookup()
	spawn_transform = global_transform
	_apply_local_player_state()


func _find_race_manager() -> Node:
	var nearby := get_node_or_null("../RaceManager")
	if nearby != null:
		return nearby
	var far := get_node_or_null("../../RaceManager")
	if far != null:
		return far
	return get_tree().get_first_node_in_group("race_manager")


func _apply_local_player_state() -> void:
	if not is_local_player:
		var camera := get_node_or_null("Camera3D") as Camera3D
		if camera != null:
			camera.current = false


func _physics_process(delta: float) -> void:
	if not is_local_player:
		return
	if global_position.y < fall_respawn_height and not race_manager.waiting_for_player:
		respawn_car()
		race_manager.restart_race()
		return

	if Input.is_physical_key_pressed(KEY_R) and not race_manager.waiting_for_player:
		respawn_car()
		race_manager.restart_race()
		return

	_update_surface_response()

	if (
		race_manager.waiting_for_player
		or not race_manager.race_started
		or race_manager.race_finished
	):
		engine_force = 0.0
		brake = parking_brake
		steering = move_toward(steering, 0.0, steering_speed * delta)
		return

	var throttle := 0.0
	var steering_input := 0.0

	if Input.is_physical_key_pressed(KEY_W):
		throttle += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		throttle -= 1.0
	if Input.is_physical_key_pressed(KEY_A):
		steering_input += 1.0
	if Input.is_physical_key_pressed(KEY_D):
		steering_input -= 1.0

	_update_automatic_gearbox(throttle, delta)
	_update_engine_and_brake(throttle)
	_update_steering(steering_input, delta)
	_apply_grass_drag()
	_apply_downforce()
	_apply_upright_stability()


func _update_surface_response() -> void:
	var grass_wheel_count := 0

	for wheel_name in WHEEL_SETTINGS:
		var wheel := get_node_or_null("Wheel%s" % wheel_name) as VehicleWheel3D
		if wheel == null:
			continue

		var wheel_on_grass := (
			wheel.is_in_contact()
			and not _is_point_on_road(wheel.global_position)
		)

		wheel.wheel_friction_slip = grass_tire_grip if wheel_on_grass else road_tire_grip
		if wheel_on_grass:
			grass_wheel_count += 1

	grass_contact_ratio = float(grass_wheel_count) / float(WHEEL_SETTINGS.size())


func _build_road_surface_lookup() -> void:
	var road_mesh: MeshInstance3D = null
	var nearby := get_node_or_null("../RaceMap/Roadbed_Shoulder") as MeshInstance3D
	if nearby != null:
		road_mesh = nearby
	else:
		var road_map := get_tree().get_first_node_in_group("race_map")
		if road_map != null:
			road_mesh = road_map.find_child("Roadbed_Shoulder", true, false) as MeshInstance3D
	if road_mesh == null or road_mesh.mesh == null:
		push_warning("Roadbed_Shoulder mesh is missing; grass response is disabled")
		return

	var faces := road_mesh.mesh.get_faces()
	for face_index in range(0, faces.size(), 3):
		var world_a: Vector3 = road_mesh.global_transform * faces[face_index]
		var world_b: Vector3 = road_mesh.global_transform * faces[face_index + 1]
		var world_c: Vector3 = road_mesh.global_transform * faces[face_index + 2]
		var a := Vector2(world_a.x, world_a.z)
		var b := Vector2(world_b.x, world_b.z)
		var c := Vector2(world_c.x, world_c.z)
		if absf((b - a).cross(c - a)) < 0.0001:
			continue

		var triangle_index := road_triangles.size()
		road_triangles.append(PackedVector2Array([a, b, c]))
		var minimum := Vector2(
			minf(a.x, minf(b.x, c.x)),
			minf(a.y, minf(b.y, c.y))
		)
		var maximum := Vector2(
			maxf(a.x, maxf(b.x, c.x)),
			maxf(a.y, maxf(b.y, c.y))
		)
		var minimum_cell := Vector2i(
			floori(minimum.x / ROAD_GRID_CELL_SIZE),
			floori(minimum.y / ROAD_GRID_CELL_SIZE)
		)
		var maximum_cell := Vector2i(
			floori(maximum.x / ROAD_GRID_CELL_SIZE),
			floori(maximum.y / ROAD_GRID_CELL_SIZE)
		)

		for cell_x in range(minimum_cell.x, maximum_cell.x + 1):
			for cell_y in range(minimum_cell.y, maximum_cell.y + 1):
				var cell := Vector2i(cell_x, cell_y)
				var triangle_indices: Array = road_triangle_grid.get(cell, [])
				triangle_indices.append(triangle_index)
				road_triangle_grid[cell] = triangle_indices

	road_surface_lookup_ready = not road_triangles.is_empty()


func _is_point_on_road(world_position: Vector3) -> bool:
	if not road_surface_lookup_ready:
		return true
	var point := Vector2(world_position.x, world_position.z)
	var cell := Vector2i(
		floori(point.x / ROAD_GRID_CELL_SIZE),
		floori(point.y / ROAD_GRID_CELL_SIZE)
	)
	var triangle_indices: Array = road_triangle_grid.get(cell, [])
	for triangle_index in triangle_indices:
		var triangle: PackedVector2Array = road_triangles[int(triangle_index)]
		if _point_in_triangle(point, triangle[0], triangle[1], triangle[2]):
			return true
	return false


func _point_in_triangle(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := (point.x - b.x) * (a.y - b.y) - (a.x - b.x) * (point.y - b.y)
	var d2 := (point.x - c.x) * (b.y - c.y) - (b.x - c.x) * (point.y - c.y)
	var d3 := (point.x - a.x) * (c.y - a.y) - (c.x - a.x) * (point.y - a.y)
	var has_negative := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var has_positive := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (has_negative and has_positive)


func _apply_grass_drag() -> void:
	if grass_contact_ratio <= 0.0:
		return
	var planar_velocity := linear_velocity.slide(Vector3.UP)
	if planar_velocity.length_squared() < 0.25:
		return
	var drag_force := (
		-planar_velocity.normalized()
		* grass_drag_acceleration
		* mass
		* grass_contact_ratio
	)
	apply_central_force(drag_force)


func _update_automatic_gearbox(throttle: float, delta: float) -> void:
	var forward_speed := linear_velocity.dot(-global_basis.z)
	shift_timer = maxf(shift_timer - delta, 0.0)

	if forward_speed < -0.75:
		current_gear = 1
		var reverse_ratio := clampf(absf(forward_speed) / reverse_speed, 0.0, 1.0)
		var reverse_rpm := lerpf(1200.0, 5200.0, reverse_ratio)
		engine_rpm = move_toward(engine_rpm, reverse_rpm, 12000.0 * delta)
		return

	var speed := maxf(forward_speed, 0.0)
	if shift_timer <= 0.0:
		if current_gear < MAX_FORWARD_GEAR and speed >= UPSHIFT_SPEEDS[current_gear]:
			current_gear += 1
			shift_timer = shift_duration
		elif current_gear > 1 and speed < DOWNSHIFT_SPEEDS[current_gear]:
			current_gear -= 1
			shift_timer = shift_duration

	var rpm_speed_range: Vector2 = GEAR_RPM_SPEED_RANGES[current_gear]
	var rpm_ratio := clampf(
		inverse_lerp(rpm_speed_range.x, rpm_speed_range.y, speed),
		0.0,
		1.0
	)
	var target_rpm := lerpf(1200.0, 6800.0, rpm_ratio)
	if speed < 0.75:
		target_rpm = lerpf(900.0, 1750.0, maxf(throttle, 0.0))
	if shift_timer > 0.0:
		target_rpm = maxf(target_rpm * 0.78, 1100.0)
	engine_rpm = move_toward(engine_rpm, target_rpm, 12000.0 * delta)


func _update_engine_and_brake(throttle: float) -> void:
	var forward_speed := linear_velocity.dot(-global_basis.z)
	brake = 0.0

	if throttle > 0.0:
		var shift_power := 0.30 if shift_timer > 0.0 else 1.0
		var gear_power: float = GEAR_FORCE_MULTIPLIERS[current_gear]
		var surface_power := lerpf(1.0, grass_engine_multiplier, grass_contact_ratio)
		engine_force = -engine_power * gear_power * shift_power * surface_power if forward_speed < max_speed else 0.0
		return

	if throttle < 0.0:
		if forward_speed > 1.0:
			engine_force = 0.0
			brake = brake_power
		elif forward_speed > -reverse_speed:
			var reverse_surface_power := lerpf(1.0, grass_engine_multiplier, grass_contact_ratio)
			engine_force = reverse_engine_power * reverse_surface_power
		else:
			engine_force = 0.0
		return

	engine_force = 0.0
	brake = lerpf(rolling_brake, grass_coast_brake, grass_contact_ratio)


func _update_steering(steering_input: float, delta: float) -> void:
	var speed_ratio := clampf(linear_velocity.length() / max_speed, 0.0, 1.0)
	var steering_ratio := lerpf(1.0, high_speed_steer_ratio, speed_ratio)
	var steering_limit := deg_to_rad(max_steer_angle_degrees) * steering_ratio
	var target_steering := steering_input * steering_limit
	steering = move_toward(steering, target_steering, steering_speed * delta)


func _apply_downforce() -> void:
	if linear_velocity.length_squared() < 1.0:
		return
	apply_central_force(-global_basis.y * downforce * linear_velocity.length())


func _apply_upright_stability() -> void:
	var body_up := global_basis.y.normalized()
	var correction_axis := body_up.cross(Vector3.UP)
	apply_torque(correction_axis * upright_strength)

	# Preserve yaw rotation while damping only roll and pitch movement.
	var yaw_velocity := Vector3.UP * angular_velocity.dot(Vector3.UP)
	var tilt_velocity := angular_velocity - yaw_velocity
	apply_torque(-tilt_velocity * upright_damping)


func _configure_model_wheels() -> void:
	var car_model := get_node_or_null("AE86_2")
	if car_model == null:
		push_error("AE86_2 model is missing; four-wheel physics could not be configured")
		return

	for wheel_name in WHEEL_SETTINGS:
		var visual_wheel := car_model.find_child(wheel_name, true, false) as VehicleWheel3D
		var wheel := get_node_or_null("Wheel%s" % wheel_name) as VehicleWheel3D
		if visual_wheel == null:
			push_error("Missing AE86 wheel node: %s" % wheel_name)
			continue
		if wheel == null:
			push_error("Missing physics wheel node: Wheel%s" % wheel_name)
			continue

		var settings: Dictionary = WHEEL_SETTINGS[wheel_name]
		for visual_child in visual_wheel.get_children():
			if visual_child is MeshInstance3D:
				visual_child.reparent(wheel, false)
		visual_wheel.queue_free()

		wheel.position = settings["position"]
		wheel.rotation = Vector3.ZERO
		wheel.scale = Vector3.ONE
		wheel.use_as_steering = bool(settings["steering"])
		wheel.use_as_traction = bool(settings["traction"])
		wheel.wheel_radius = 0.31
		wheel.wheel_rest_length = 0.18
		wheel.suspension_travel = 0.12
		wheel.suspension_stiffness = 32.0
		wheel.suspension_max_force = 9000.0
		wheel.damping_compression = 2.0
		wheel.damping_relaxation = 2.4
		wheel.wheel_friction_slip = road_tire_grip
		wheel.wheel_roll_influence = 0.02


func respawn_car() -> void:
	engine_force = 0.0
	brake = parking_brake
	steering = 0.0
	current_gear = 1
	engine_rpm = 900.0
	shift_timer = 0.0
	grass_contact_ratio = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = spawn_transform
	sleeping = false

	# PhysicsServer3D explicit state reset to guarantee immediate teleport without residual momentum
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, spawn_transform)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)

	reset_physics_interpolation()
