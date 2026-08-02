# [3D_race (Copy)] Project Context File: .gd

## res://

**check_point_1.gd**
```gdscript
extends Area3D

@export var checkpoint_index: int = 1

@onready var race_manager: Node = $"../../RaceManager"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.name != "Player":
		return

	race_manager.register_checkpoint(checkpoint_index)

```

**dashboard.gd**
```gdscript
extends Control

@export var max_display_speed_kph: float = 160.0
@export var speed_smoothing: float = 8.0

@onready var player: VehicleBody3D = $"../../Player"
@onready var race_manager: Node = $"../../RaceManager"

var displayed_speed_kph: float = 0.0
var forward_speed_mps: float = 0.0
var gear_text: String = "1"
var displayed_rpm: int = 900

const PANEL_COLOR := Color(0.025, 0.035, 0.05, 0.9)
const PANEL_EDGE := Color(0.18, 0.24, 0.31, 0.95)
const GAUGE_DARK := Color(0.055, 0.075, 0.1, 1.0)
const GAUGE_TRACK := Color(0.18, 0.22, 0.27, 1.0)
const ACCENT := Color(0.1, 0.82, 1.0, 1.0)
const WARNING := Color(1.0, 0.27, 0.12, 1.0)
const TEXT_MAIN := Color(0.95, 0.98, 1.0, 1.0)
const TEXT_MUTED := Color(0.55, 0.66, 0.74, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(delta: float) -> void:
	visible = not bool(race_manager.get("waiting_for_player"))
	if not visible:
		return

	var target_speed_kph := player.linear_velocity.length() * 3.6
	var blend_weight := 1.0 - exp(-speed_smoothing * delta)
	displayed_speed_kph = lerpf(displayed_speed_kph, target_speed_kph, blend_weight)
	forward_speed_mps = player.linear_velocity.dot(-player.global_basis.z)
	gear_text = _get_gear_text()

	displayed_rpm = int(float(player.get("engine_rpm")))
	queue_redraw()


func _get_gear_text() -> String:
	if forward_speed_mps < -0.75:
		return "R"
	return str(int(player.get("current_gear")))


func _draw() -> void:
	var font := get_theme_default_font()
	var panel_rect := Rect2(Vector2.ZERO, size)
	draw_rect(panel_rect, PANEL_COLOR, true)
	draw_rect(panel_rect, PANEL_EDGE, false, 2.0)
	draw_rect(Rect2(0.0, 0.0, size.x, 4.0), ACCENT, true)

	var center := Vector2(100.0, 105.0)
	var radius := 76.0
	var start_angle := deg_to_rad(135.0)
	var end_angle := deg_to_rad(405.0)
	var speed_ratio := clampf(displayed_speed_kph / max_display_speed_kph, 0.0, 1.0)
	var needle_angle := lerpf(start_angle, end_angle, speed_ratio)

	draw_circle(center, radius + 7.0, GAUGE_DARK)
	draw_arc(center, radius, start_angle, end_angle, 72, GAUGE_TRACK, 7.0, true)
	draw_arc(center, radius, start_angle, needle_angle, 48, ACCENT, 7.0, true)

	for tick_index in range(9):
		var tick_ratio := float(tick_index) / 8.0
		var tick_angle := lerpf(start_angle, end_angle, tick_ratio)
		var direction := Vector2(cos(tick_angle), sin(tick_angle))
		var outer_point := center + direction * 69.0
		var inner_point := center + direction * 59.0
		draw_line(inner_point, outer_point, TEXT_MAIN, 2.0, true)

		var label := str(int(max_display_speed_kph * tick_ratio))
		var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12)
		var label_position := center + direction * 48.0
		label_position.x -= label_size.x * 0.5
		label_position.y += label_size.y * 0.35
		draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, TEXT_MUTED)

	var needle_direction := Vector2(cos(needle_angle), sin(needle_angle))
	draw_line(center, center + needle_direction * 54.0, WARNING, 4.0, true)
	draw_circle(center, 7.0, TEXT_MAIN)
	draw_circle(center, 3.5, WARNING)

	var speed_text := "%03d" % int(round(displayed_speed_kph))
	draw_string(font, Vector2(151.0, 75.0), speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 34, TEXT_MAIN)
	draw_string(font, Vector2(157.0, 96.0), "km/h", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, TEXT_MUTED)

	draw_string(font, Vector2(151.0, 25.0), "AUTO 5-SPEED", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, ACCENT)
	draw_circle(Vector2(185.0, 128.0), 24.0, GAUGE_DARK)
	var gear_size := font.get_string_size(gear_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30)
	draw_string(
		font,
		Vector2(185.0 - gear_size.x * 0.5, 128.0 + gear_size.y * 0.35),
		gear_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		30,
		ACCENT if gear_text != "R" else WARNING
	)

	draw_string(font, Vector2(224.0, 121.0), "RPM", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, TEXT_MUTED)
	draw_string(font, Vector2(224.0, 140.0), str(displayed_rpm), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, TEXT_MAIN)
	var rpm_ratio := clampf(float(displayed_rpm - 900) / 6900.0, 0.0, 1.0)
	draw_rect(Rect2(154.0, 166.0, 124.0, 6.0), GAUGE_TRACK, true)
	draw_rect(Rect2(154.0, 166.0, 124.0 * rpm_ratio, 6.0), ACCENT if rpm_ratio < 0.82 else WARNING, true)

```

**finish.gd**
```gdscript
extends Area3D

@onready var race_manager: Node = $"../RaceManager"

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		print("抵達終點！")
		race_manager.finish_race()

```

### network

**lobby_manager.gd**
```gdscript
extends Node

## 房間 / 大廳管理（佔位）
## EOS Lobbies 部分先註解：開房(12人)、搜尋、加入、就緒、開始。
## 目前只留資料結構與訊號，遊戲層可以先吃這些介面。

@warning_ignore("unused_signal")
signal lobby_created(lobby_info: Dictionary)
@warning_ignore("unused_signal")
signal lobby_joined(lobby_info: Dictionary)
@warning_ignore("unused_signal")
signal member_joined(member_id: String)
@warning_ignore("unused_signal")
signal member_left(member_id: String)
signal ready_state_changed(ready_map: Dictionary)
signal match_started(peer_order: Array)

const MAX_PLAYERS := 12

var current_lobby: Dictionary = {}
var is_host: bool = false
## players: [{ "peer_id": int, "name": String, "ready": bool }]
var players: Array = []


func create_lobby() -> void:
	# EOS：HLobbies.create_lobby_async({ max_lobby_members = MAX_PLAYERS, ... })
	# 先註解。目前直接在本機登記 host。
	is_host = true
	players = []
	players.append({"peer_id": 1, "name": "P1", "ready": false})


func join_lobby(_lobby_info: Dictionary) -> void:
	# EOS：HLobbies.join_async(lobby)
	pass


func add_player(peer_id: int, display_name: String) -> void:
	players.append({"peer_id": peer_id, "name": display_name, "ready": false})
	ready_state_changed.emit(get_ready_map())


func set_ready(is_ready: bool) -> void:
	# 在多人時由 UI 呼叫；目前先寫入本機玩家狀態
	for player in players:
		if player["peer_id"] == NetworkManager.LOCAL_PEER_ID:
			player["ready"] = is_ready
			break
	ready_state_changed.emit(get_ready_map())


func get_ready_map() -> Dictionary:
	var map := {}
	for player in players:
		map[player["peer_id"]] = player["ready"]
	return map


func start_match() -> void:
	# 所有人就緒後由 host 觸發；目前直接廣播本機單人順序
	match_started.emit([1])

```

**network_manager.gd**
```gdscript
extends Node

## 網路管理（佔位）
## EOS 連線部分目前先註解掉，保留結構，之後再啟用：
## 1. 安裝 EOSG 插件後，在 init_eos() 填入憑證並初始化 SDK
## 2. host_game() / join_game() 建立 EOSGMultiplayerPeer 並指定給 multiplayer
## 3. 透過 peer_connected / peer_disconnected 通知遊戲層

enum Mode {
	SINGLEPLAYER,  ## 單機計時賽（現在用的模式）
	HOST,          ## 開房（listen server，peer id = 1）
	CLIENT,        ## 加入別人的房
}

signal mode_changed(mode: int)
@warning_ignore("unused_signal")
signal peer_connected(peer_id: int)
@warning_ignore("unused_signal")
signal peer_disconnected(peer_id: int)

const LOCAL_PEER_ID := 1
const MAX_PLAYERS := 12  ## 連線數上限（配合 12 格出發位置）

var mode: int = Mode.SINGLEPLAYER


func set_mode(new_mode: int) -> void:
	mode = new_mode
	mode_changed.emit(mode)


func is_online() -> bool:
	return mode != Mode.SINGLEPLAYER


func is_host() -> bool:
	return mode == Mode.HOST


# ==========================================================================
# EOS（未啟用 — 先註解）
# 所需外掛：Epic Online Services Godot (EOSG) -> EOSGMultiplayerPeer
# ==========================================================================
#
# func init_eos() -> void:
# 	# 1) 用 ProductId / SandboxId / DeploymentId / ClientId / ClientSecret /
# 	#    EncryptionKey 初始化 HPlatform
# 	# 2) HAuth.login_async(...) 登入（DevAuth 或 Epic 帳號）
# 	pass
#
# func host_game() -> void:
# 	# var peer := EOSGMultiplayerPeer.new()
# 	# var err := peer.create_server("game", 0)
# 	# peer.set_server_auto_accept_connection_requests(true)
# 	# multiplayer.multiplayer_peer = peer
# 	# multiplayer.peer_connected.connect(_on_peer_connected)
# 	# multiplayer.peer_disconnected.connect(_on_peer_disconnected)
# 	# set_mode(Mode.HOST)
# 	pass
#
# func join_game() -> void:
# 	# var peer := EOSGMultiplayerPeer.new()
# 	# peer.create_client("game", 0)
# 	# multiplayer.multiplayer_peer = peer
# 	# multiplayer.connected_to_server.connect(_on_connected_to_server)
# 	# multiplayer.connection_failed.connect(_on_connection_failed)
# 	# set_mode(Mode.CLIENT)
# 	pass
#
# func _on_peer_connected(peer_id: int) -> void:
# 	peer_connected.emit(peer_id)
#
# func _on_peer_disconnected(peer_id: int) -> void:
# 	peer_disconnected.emit(peer_id)
#
# func _on_connected_to_server() -> void:
# 	pass
#
# func _on_connection_failed() -> void:
# 	pass

```

## res://

**player.gd**
```gdscript
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
	reset_physics_interpolation()

```

### race

**player_spawner.gd**
```gdscript
extends MultiplayerSpawner

## 遠端玩家車輛 spawner（佔位）
## EOS 連線啟用後，host 收到新 peer 連線時會透過 spawn_function 生出遠端車。
## 現在單機模式不會觸發（沒有 peer）。

const PLAYER_SCENE := preload("res://player.tscn")


func _ready() -> void:
	spawn_function = _spawn_remote_player


func _spawn_remote_player(data: Variant) -> Node:
	var peer_id: int = int(data.get("peer_id", 1))
	var player := PLAYER_SCENE.instantiate()
	player.name = "Player_%d" % peer_id
	player.set("is_local_player", false)
	var slot: Dictionary = StartGrid.get_slot(maxi(peer_id - 1, 0))
	player.position = slot["position"]
	player.rotation = Vector3(0.0, float(slot["yaw"]), 0.0)
	player.set_multiplayer_authority(peer_id)
	return player

```

**race_ranking.gd**
```gdscript
class_name RaceRanking
extends RefCounted

## 賽事名次（佔位）
## 進度 = 已通過的檢查點數 + 到下一個檢查點的完成比例(0~1)。
## 之後多人模式：每台車由各自 client 回報位置，host 用這份邏輯統一排序。
## 現在單機：RaceManager 每 0.15 秒餵一次本地玩家位置。

signal changed(entries: Array)

var checkpoint_positions: Array[Vector3] = []
var finish_position := Vector3.ZERO
var start_position := Vector3.ZERO
var segment_lengths: Array[float] = []

## car_id -> { "name": String, "next_index": int, "progress": float }
var cars: Dictionary = {}


func setup(positions: Array[Vector3], finish: Vector3, start: Vector3) -> void:
	checkpoint_positions = positions
	finish_position = finish
	start_position = start
	segment_lengths = []
	for i in positions.size():
		var from: Vector3 = positions[i - 1] if i > 0 else start
		segment_lengths.append(maxf(from.distance_to(positions[i]), 0.001))


func register_car(car_id: int, display_name: String) -> void:
	cars[car_id] = {
		"name": display_name,
		"next_index": 0,
		"progress": 0.0,
	}


func update_car(car_id: int, world_position: Vector3) -> void:
	if not cars.has(car_id):
		return
	var car: Dictionary = cars[car_id]
	var total: int = checkpoint_positions.size()
	var next_index: int = car["next_index"]

	if next_index >= total:
		# 已通過全部檢查點，正跑向終點
		if total == 0:
			car["progress"] = 1.0
			return
		var segment_len := maxf(
			checkpoint_positions[total - 1].distance_to(finish_position),
			0.001
		)
		var fraction := 1.0 - clampf(
			world_position.distance_to(finish_position) / segment_len,
			0.0,
			1.0
		)
		car["progress"] = float(total) + fraction
		return

	var target: Vector3 = checkpoint_positions[next_index]
	var remaining_segment_len: float = segment_lengths[next_index]
	var progress_fraction := 1.0 - clampf(
		world_position.distance_to(target) / remaining_segment_len,
		0.0,
		1.0
	)
	car["progress"] = float(next_index) + progress_fraction


func advance_car(car_id: int) -> void:
	if not cars.has(car_id):
		return
	var car: Dictionary = cars[car_id]
	if car["next_index"] < checkpoint_positions.size():
		car["next_index"] += 1


func mark_finished(car_id: int) -> void:
	if not cars.has(car_id):
		return
	cars[car_id]["next_index"] = checkpoint_positions.size()
	cars[car_id]["progress"] = float(checkpoint_positions.size()) + 1.0


func get_ordered() -> Array:
	var entries: Array = []
	for car_id in cars:
		var car: Dictionary = cars[car_id]
		entries.append({
			"car_id": car_id,
			"name": car.get("name", "玩家"),
			"progress": car.get("progress", 0.0),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["progress"] > b["progress"]
	)
	return entries


func emit_changed() -> void:
	changed.emit(get_ordered())

```

**rank_panel.gd**
```gdscript
extends PanelContainer

## 名次面板（佔位）
## 純文字列出 1. 2. 3. ...，之後再換成正式 UI。
## RaceManager 每 0.15 秒呼叫 update_entries()。

const MAX_ROWS := 12

var _row_labels: Array[Label] = []
var _rows: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "名次"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	for i in MAX_ROWS:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 20)
		_rows.add_child(label)
		_row_labels.append(label)
	vbox.add_child(_rows)

	add_child(vbox)


func update_entries(entries: Array) -> void:
	for i in _row_labels.size():
		if i < entries.size():
			var entry: Dictionary = entries[i]
			_row_labels[i].text = "%d. %s" % [i + 1, entry.get("name", "玩家")]
		else:
			_row_labels[i].text = ""


func clear_entries() -> void:
	for label in _row_labels:
		label.text = ""

```

**start_grid.gd**
```gdscript
class_name StartGrid
extends RefCounted

## 出發格位（預留位置）
## 12 台車：3 排 x 4 台，座標之後再依賽道微調。
## 單機模式只用 slot 0（也就是原本的出生點）。

const GRID_SLOT_COUNT := 12
const GRID_COLS := 4
const GRID_ROWS := 3

const GRID_CENTER := Vector3(-115.077791, 1.35, 10.5)
const COL_SPACING := 4.0
const ROW_SPACING := 7.0
const GRID_YAW := 0.0


static func get_slot(slot_index: int) -> Dictionary:
	slot_index = clampi(slot_index, 0, GRID_SLOT_COUNT - 1)
	@warning_ignore("integer_division")
	var row := slot_index / GRID_COLS
	var col := slot_index % GRID_COLS
	var lateral := (col - (GRID_COLS - 1) * 0.5) * COL_SPACING
	return {
		"index": slot_index,
		"position": Vector3(
			GRID_CENTER.x + lateral,
			GRID_CENTER.y,
			GRID_CENTER.z + row * ROW_SPACING
		),
		"yaw": GRID_YAW,
		"label": "P%d" % (slot_index + 1),
	}


static func grid_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for i in GRID_SLOT_COUNT:
		slots.append(get_slot(i))
	return slots


## 依連線順序分配格位：peer_ids[0] -> P1 ... peer_ids[11] -> P12
static func assign_slots(peer_ids: Array) -> Dictionary:
	var assignment := {}
	for i in mini(peer_ids.size(), GRID_SLOT_COUNT):
		assignment[peer_ids[i]] = get_slot(i)
	return assignment

```

## res://

**race_course_setup.gd**
```gdscript
extends Node3D

const TOTAL_CHECKPOINTS: int = 7
const PLAYER_SPAWN_POSITION := Vector3(-115.077791, 1.35, 10.5)
const FINISH_POSITION := Vector3(-115.077791, 1.5, 6.507477)
const FINISH_YAW: float = 3.105172
const GATE_SIZE := Vector3(14.0, 3.0, 4.0)

const CHECKPOINT_SCRIPT := preload("res://check_point_1.gd")
const FINISH_SCRIPT := preload("res://finish.gd")

const CHECKPOINTS := [
	{"position": Vector3(-79.422614, 1.5, -86.009814), "yaw": 1.452350},
	{"position": Vector3(92.437632, 1.5, -72.305016), "yaw": 2.753624},
	{"position": Vector3(-2.679414, 1.5, 49.549295), "yaw": 0.273751},
	{"position": Vector3(94.540360, 1.5, 81.506703), "yaw": 4.264791},
	{"position": Vector3(-37.868606, 1.5, 49.272107), "yaw": 1.712538},
	{"position": Vector3(-58.480451, 1.5, 38.233451), "yaw": -1.013083},
	{"position": Vector3(-97.884251, 1.5, 59.579426), "yaw": 0.011061},
]


func _ready() -> void:
	_remove_test_course()
	_configure_player()
	_create_finish_gate()
	_create_checkpoint_gates()
	_configure_race_manager()
	_setup_ranking()
	_register_groups()


func _register_groups() -> void:
	get_node("RaceMap").add_to_group("race_map")
	get_node("RaceManager").add_to_group("race_manager")


func _remove_test_course() -> void:
	for node_name in [&"Track", &"Finish", &"CheckPoints"]:
		var old_node := get_node_or_null(NodePath(String(node_name)))
		if old_node != null:
			old_node.free()


func _configure_player() -> void:
	var player := get_node("Player") as VehicleBody3D
	var spawn_slot: Dictionary = StartGrid.get_slot(0)
	player.position = spawn_slot["position"]
	player.rotation = Vector3(0.0, float(spawn_slot["yaw"]), 0.0)
	player.linear_velocity = Vector3.ZERO
	player.angular_velocity = Vector3.ZERO
	player.set("spawn_transform", player.global_transform)


func _create_finish_gate() -> void:
	var finish := Area3D.new()
	finish.name = "Finish"
	finish.set_script(FINISH_SCRIPT)
	finish.position = FINISH_POSITION
	finish.rotation.y = FINISH_YAW
	finish.collision_layer = 0
	finish.collision_mask = 1
	finish.add_child(_create_gate_shape())
	add_child(finish)


func _create_checkpoint_gates() -> void:
	var checkpoint_root := Node3D.new()
	checkpoint_root.name = "CheckPoints"
	add_child(checkpoint_root)

	for checkpoint_offset in range(CHECKPOINTS.size()):
		var checkpoint_index := checkpoint_offset + 1
		var checkpoint_data: Dictionary = CHECKPOINTS[checkpoint_offset]
		var checkpoint := Area3D.new()
		checkpoint.name = "CheckPoint%d" % checkpoint_index
		checkpoint.set_script(CHECKPOINT_SCRIPT)
		checkpoint.set("checkpoint_index", checkpoint_index)
		checkpoint.position = checkpoint_data["position"]
		checkpoint.rotation.y = float(checkpoint_data["yaw"])
		checkpoint.collision_layer = 0
		checkpoint.collision_mask = 1
		checkpoint.add_child(_create_gate_shape())
		checkpoint_root.add_child(checkpoint)


func _create_gate_shape() -> CollisionShape3D:
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var box_shape := BoxShape3D.new()
	box_shape.size = GATE_SIZE
	collision_shape.shape = box_shape
	return collision_shape


func _configure_race_manager() -> void:
	var race_manager := get_node("RaceManager")
	race_manager.set("total_checkpoints", TOTAL_CHECKPOINTS)
	var checkpoint_label := get_node("UI/CheckpointLabel") as Label
	checkpoint_label.text = "檢查點：0 / %d" % TOTAL_CHECKPOINTS


func _setup_ranking() -> void:
	var race_manager := get_node("RaceManager")
	var checkpoint_positions: Array[Vector3] = []
	for checkpoint_data: Dictionary in CHECKPOINTS:
		checkpoint_positions.append(checkpoint_data["position"])
	race_manager.setup_ranking(
		checkpoint_positions,
		FINISH_POSITION,
		StartGrid.get_slot(0)["position"]
	)

```

**race_manager.gd**
```gdscript
extends Node

const SAVE_PATH: String = "user://race_scores.cfg"

@onready var player: VehicleBody3D = $"../Player"
@onready var timer_label: Label = $"../UI/TimerLabel"
@onready var countdown_label: Label = $"../UI/CountdownCenter/CountdownLabel"
@onready var checkpoint_label: Label = $"../UI/CheckpointLabel"
@onready var finish_center: CenterContainer = $"../UI/FinishCenter"
@onready var final_time_label: Label = $"../UI/FinishCenter/VBoxContainer/FinalTimeLabel"
@onready var best_time_label: Label = $"../UI/BestTimeLabel"
@onready var start_center: CenterContainer = $"../UI/StartCenter"
@onready var name_input: LineEdit = $"../UI/StartCenter/MainVBox/FormCenter/FormVBox/NameInput"
@onready var start_button: Button = $"../UI/StartCenter/MainVBox/FormCenter/FormVBox/StartButton"
@onready var leaderboard_button: Button = %LeaderboardButton
@onready var leaderboard_center: CenterContainer = %LeaderboardCenter
@onready var leaderboard_grid: GridContainer = %LeaderboardGrid
@onready var close_leaderboard_button: Button = %CloseLeaderboardButton
@onready var next_player_button: Button = %NextPlayerButton
@onready var rank_panel: PanelContainer = $"../UI/RankPanel"
@export var total_checkpoints: int = 2

const RANKING_UPDATE_INTERVAL: float = 0.15

var ranking := RaceRanking.new()
var ranking_update_accum: float = 0.0

var leaderboard: Array = []
var player_name: String = ""
var waiting_for_player: bool = true
var best_time: float = -1.0
var race_started: bool = false
var countdown_time: float = 3.0
var go_display_time: float = 0.0

var next_checkpoint: int = 1
var race_time: float = 0.0
var race_finished: bool = false

func restart_race() -> void:
	race_time = 0.0
	race_finished = false
	race_started = false

	next_checkpoint = 1

	countdown_time = 3.0
	go_display_time = 0.0

	timer_label.text = "0.00"
	checkpoint_label.text = "檢查點：0 / %d" % total_checkpoints
	countdown_label.text = "3"
	
	finish_center.visible = false

func _process(delta: float) -> void:
	if waiting_for_player:
		return
	
	update_start_countdown(delta)

	if not race_started or race_finished:
		return

	race_time += delta
	timer_label.text = "%.2f" % race_time

	ranking_update_accum += delta
	if ranking_update_accum >= RANKING_UPDATE_INTERVAL:
		ranking_update_accum = 0.0
		ranking.update_car(1, player.global_position)
		ranking.emit_changed()

func _ready() -> void:
	load_leaderboard()
	load_best_time()
	refresh_best_time_label()
	
	start_center.visible = true
	
	leaderboard_button.pressed.connect(open_leaderboard)
	close_leaderboard_button.pressed.connect(close_leaderboard)
	next_player_button.pressed.connect(prepare_next_player)
	
	countdown_label.text = ""
	start_button.pressed.connect(start_race)
	name_input.call_deferred("grab_focus")

	rank_panel.visible = false

func setup_ranking(
	checkpoint_positions: Array,
	finish_position: Vector3,
	start_position: Vector3
) -> void:
	ranking.setup(checkpoint_positions, finish_position, start_position)
	ranking.register_car(1, "玩家")
	ranking.changed.connect(rank_panel.update_entries)

func start_race() -> void:
	var entered_name := name_input.text.strip_edges()

	if entered_name.is_empty():
		name_input.placeholder_text = "名字不能空白"
		return

	player_name = entered_name
	waiting_for_player = false

	start_center.visible = false
	restart_race()

	ranking.cars[1]["name"] = player_name
	ranking.emit_changed()
	rank_panel.visible = true

func finish_race() -> void:
	if race_finished:
		return

	if next_checkpoint <= total_checkpoints:
		print("還沒有通過所有檢查點！")
		return

	race_finished = true

	ranking.mark_finished(1)
	ranking.emit_changed()

	register_score(player_name, race_time)
	
	timer_label.text = "%.2f" % race_time
	finish_center.visible = true

	if best_time < 0.0 or race_time < best_time:
		best_time = race_time

		save_best_time()
		refresh_best_time_label()

		final_time_label.text = "%s\n新紀錄：%.2f 秒" % [
			player_name,
			race_time
		]
	else:
		final_time_label.text = "%s\n成績：%.2f 秒" % [
			player_name,
			race_time
		]
		
func register_checkpoint(checkpoint_index: int) -> void:
	if race_finished:
		return

	if checkpoint_index != next_checkpoint:
		print("檢查點順序錯誤")
		return

	next_checkpoint += 1
	checkpoint_label.text = "檢查點：%d / %d" % [
		checkpoint_index,
		total_checkpoints
	]

	ranking.advance_car(1)
	ranking.emit_changed()

	print(
		"通過檢查點：",
		checkpoint_index,
		"/",
		total_checkpoints
	)
	
func update_start_countdown(delta: float) -> void:
	if not race_started:
		countdown_time -= delta

		if countdown_time > 0.0:
			countdown_label.text = str(ceili(countdown_time))
		else:
			race_started = true
			countdown_label.text = "GO!"
			go_display_time = 1.0

		return

	if go_display_time > 0.0:
		go_display_time -= delta

		if go_display_time <= 0.0:
			countdown_label.text = ""

func load_best_time() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)

	if error != OK:
		return

	best_time = float(
		config.get_value("scores", "best_time", -1.0)
	)
	
func save_best_time() -> void:
	var config := ConfigFile.new()

	# 避免儲存最佳成績時清掉排行榜
	config.load(SAVE_PATH)
	
	config.set_value(
		"scores",
		"best_time",
		best_time
	)

	var error := config.save(SAVE_PATH)

	if error != OK:
		push_error("無法儲存最佳成績")
		
func refresh_best_time_label() -> void:
	if best_time < 0.0:
		best_time_label.text = "最佳：--"
		return

	best_time_label.text = "最佳：%.2f 秒" % best_time

func load_leaderboard() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)

	if error != OK:
		return

	var saved_leaderboard = config.get_value(
		"scores",
		"leaderboard",
		[]
	)

	if saved_leaderboard is Array:
		leaderboard = saved_leaderboard
		
func save_leaderboard() -> void:
	var config := ConfigFile.new()

	# 先讀取原本的檔案，避免清掉 best_time
	config.load(SAVE_PATH)

	config.set_value(
		"scores",
		"leaderboard",
		leaderboard
	)

	var error := config.save(SAVE_PATH)

	if error != OK:
		push_error("無法儲存排行榜")
		
func register_score(score_name: String, score_time: float) -> void:
	var existing_index: int = -1

	for index in range(leaderboard.size()):
		var score: Dictionary = leaderboard[index]

		if str(score.get("name", "")) == score_name:
			existing_index = index
			break
	
	if existing_index == -1:
		# 第一次使用這個名字
		leaderboard.append({
			"name": score_name,
			"time": score_time
		})

	elif score_time < float(leaderboard[existing_index]["time"]):
		# 同名，但這次成績更快
		leaderboard[existing_index]["time"] = score_time

	else:
		# 同名，而且沒有刷新紀錄
		return

	leaderboard.sort_custom(is_score_faster)

	#if leaderboard.size() > 10:
		#leaderboard.resize(10)

	save_leaderboard()
	refresh_leaderboard_ui()

	print("目前排行榜：", leaderboard)
	
func is_score_faster(score_a: Dictionary, score_b: Dictionary) -> bool:
	return float(score_a["time"]) < float(score_b["time"])
	
func open_leaderboard() -> void:
	refresh_leaderboard_ui()

	start_center.visible = false
	leaderboard_center.visible = true


func close_leaderboard() -> void:
	leaderboard_center.visible = false
	start_center.visible = true

	name_input.call_deferred("grab_focus")
	
func refresh_leaderboard_ui() -> void:
	for child in leaderboard_grid.get_children():
		child.queue_free()

	add_leaderboard_cell(
		"名次",
		100.0
	)

	add_leaderboard_cell(
		"姓名",
		300.0
	)

	add_leaderboard_cell(
		"時間",
		100.0
	)

	if leaderboard.is_empty():
		add_leaderboard_cell(
			"",
			100.0
		)

		add_leaderboard_cell(
			"尚無紀錄",
			300.0
		)

		add_leaderboard_cell(
			"",
			100.0
		)

		return

	var display_count: int = mini(10, leaderboard.size())
		
	for index in range(display_count):
		var score: Dictionary = leaderboard[index]
#
		var score_name: String = str(
			score.get("name", "未知")
		)

		var score_time: float = float(
			score.get("time", 0.0)
		)
		
		

		add_leaderboard_cell(
			str(index + 1),
			100.0
		)

		add_leaderboard_cell(
			score_name,
			300.0
		)

		add_leaderboard_cell(
			"%.2f 秒" % score_time,
			100.0
		)

func add_leaderboard_cell(
	cell_text: String,
	minimum_width: float
) -> void:
	var cell_label := Label.new()

	cell_label.text = cell_text
	cell_label.custom_minimum_size.x = minimum_width
	cell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell_label.add_theme_font_size_override("font_size", 24)

	cell_label.add_theme_font_size_override(
		"font_size",
		24
	)

	leaderboard_grid.add_child(cell_label)

func prepare_next_player() -> void:
	player.respawn_car()

	player_name = ""
	name_input.text = ""

	waiting_for_player = true
	race_started = false
	race_finished = false

	race_time = 0.0
	next_checkpoint = 1

	countdown_time = 3.0
	go_display_time = 0.0

	timer_label.text = "0.00"
	checkpoint_label.text = "檢查點：0 / %d" % total_checkpoints
	countdown_label.text = ""

	finish_center.visible = false
	leaderboard_center.visible = false
	start_center.visible = true

	if ranking.cars.has(1):
		ranking.cars[1]["next_index"] = 0
		ranking.cars[1]["progress"] = 0.0
		rank_panel.clear_entries()
	rank_panel.visible = false

	name_input.call_deferred("grab_focus")

```

