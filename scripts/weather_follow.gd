extends GPUParticles3D

## WeatherFollow.gd
## Keeps weather emitters above the player camera so precipitation always
## surrounds the car, even as it races across the map.

@export var target_node_path: NodePath = "../Player/Camera3D"
@export var vertical_offset: float = 18.0


func _process(_delta: float) -> void:
	var target := get_node_or_null(target_node_path) as Node3D
	if target == null:
		return
	var pos := target.global_position
	pos.y += vertical_offset
	global_position = pos
