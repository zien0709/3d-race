extends MultiMeshInstance3D

## GrassManager.gd
## Manages large-scale grass rendering using MultiMeshInstance3D.
## Features:
## - Procedural grass placement on the terrain
## - Wind animation via the grass shader
## - Vehicle interaction (bending away from the car)

@export var placement_area: Vector2 = Vector2(80, 80)
@export var max_instances: int = 20000
@export var grass_mesh: Mesh = null
@export var grass_material: ShaderMaterial = null
@export var grass_height: float = 0.5
@export var interaction_radius: float = 4.0
@export var interaction_strength: float = 1.0

var instances_placed: int = 0
var _vehicle: Node3D = null
var _time: float = 0.0


func _ready() -> void:
	_find_vehicle()
	_setup_multimesh()
	if multimesh != null and multimesh.mesh != null:
		_place_grass()


func _find_vehicle() -> void:
	if get_tree() == null:
		return
	var root := get_tree().current_scene
	if root == null:
		return
	_vehicle = root.get_node_or_null("Player") as Node3D


func _setup_multimesh() -> void:
	if grass_mesh == null:
		push_error("GrassManager: grass_mesh not assigned")
		return
	if grass_material == null:
		push_error("GrassManager: grass_material not assigned")
		return

	var mm := MultiMesh.new()
	mm.mesh = grass_mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	multimesh = mm
	## MultiMesh has no material_override; apply the shader to the blade mesh
	## via its surface 0 material slot.
	if grass_mesh.get_surface_count() > 0:
		grass_mesh.surface_set_material(0, grass_material)


func _place_grass() -> void:
	if multimesh == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var transforms: Array[Transform3D] = []
	transforms.resize(max_instances)
	var count := 0
	var half_w := placement_area.x * 0.5
	var half_h := placement_area.y * 0.5

	while count < max_instances:
		var local_x := rng.randf_range(-half_w, half_w)
		var local_z := rng.randf_range(-half_h, half_h)
		## Ray-cast in world space from above the emitter.
		var origin := to_global(Vector3(local_x, 100.0, local_z))
		var ground_y := _get_ground_height(origin)
		if ground_y == -100.0:
			continue
		## Place in local space so the emitter's transform applies normally.
		var local_pos := to_local(Vector3(origin.x, ground_y, origin.z))
		var rot := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		var scale := rng.randf_range(0.7, 1.3)
		var blade_center_y := local_pos.y + grass_height * 0.5
		transforms[count] = Transform3D(rot, Vector3(local_pos.x, blade_center_y, local_pos.z)).scaled_local(Vector3(scale, scale, scale))
		count += 1

	instances_placed = count
	multimesh.instance_count = count
	for i in count:
		multimesh.set_instance_transform(i, transforms[i])
	print("GrassManager: placed %d instances" % count)


func _get_ground_height(origin: Vector3) -> float:
	if get_world_3d() == null:
		return -100.0
	var space := get_world_3d().direct_space_state
	if space == null:
		return -100.0
	var params := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 200.0)
	params.collision_mask = 1
	var result := space.intersect_ray(params)
	if result.is_empty():
		return -100.0
	return result["position"].y


func _process(delta: float) -> void:
	if multimesh == null or grass_material == null:
		return
	_time += delta
	grass_material.set_shader_parameter("anim_time", _time)
	grass_material.set_shader_parameter("grass_height", grass_height)
	grass_material.set_shader_parameter("interaction_radius", interaction_radius)
	grass_material.set_shader_parameter("interaction_strength", interaction_strength)

	var env: Node = get_node_or_null("/root/EnvironmentManager")
	if env != null:
		grass_material.set_shader_parameter("wind_direction", env.get("wind_direction"))
		grass_material.set_shader_parameter("wind_speed", env.get("wind_speed"))

	if _vehicle == null:
		_find_vehicle()
	if _vehicle != null:
		grass_material.set_shader_parameter("vehicle_position", _vehicle.global_position)


func set_grass_parameters(density: float, height: float, _width: float) -> void:
	grass_height = height
	if multimesh != null and multimesh.mesh != null:
		var target := int(density * placement_area.x * placement_area.y)
		max_instances = clampi(target, 100, 60000)
		_place_grass()


func update_wind(wind_dir: Vector3, wind_spd: float) -> void:
	if grass_material != null:
		grass_material.set_shader_parameter("wind_direction", wind_dir)
		grass_material.set_shader_parameter("wind_speed", wind_spd)
