extends Node

## WaterSurface.gd
## Drives the Gerstner wave shader on a water MeshInstance3D.
## Uses EnvironmentManager for global wind/time where available.

@export var water_mesh: MeshInstance3D = null
@export var auto_animate: bool = true

var _time: float = 0.0


func _ready() -> void:
	if water_mesh == null:
		water_mesh = get_node_or_null("MeshInstance3D") as MeshInstance3D
	_update_initial_params()


func _process(delta: float) -> void:
	if not auto_animate or water_mesh == null:
		return
	_time += delta
	_set_shader_param("anim_time", _time)


func _update_initial_params() -> void:
	if water_mesh == null:
		return
	var env: Node = get_node_or_null("/root/EnvironmentManager")
	if env != null:
		var dir: Vector3 = env.get("wind_direction")
		_set_shader_param("wave_direction", Vector2(dir.x, dir.z))


func _set_shader_param(param: String, value: Variant) -> void:
	if water_mesh == null:
		return
	var mat := water_mesh.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(param, value)


func set_wave_params(wave_speed: float, wave_height: float, wave_length: float) -> void:
	_set_shader_param("wave_speed", wave_speed)
	_set_shader_param("wave_height", wave_height)
	_set_shader_param("wave_length", wave_length)


func set_water_color(color: Color) -> void:
	_set_shader_param("water_color", color)


func set_depth_fade(start: float, end: float) -> void:
	_set_shader_param("depth_fade_start", start)
	_set_shader_param("depth_fade_end", end)


func update_environment_params(wind_direction: Vector3, _wind_speed: float) -> void:
	_set_shader_param("wave_direction", Vector2(wind_direction.x, wind_direction.z))
