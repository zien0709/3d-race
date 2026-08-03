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
	var spawn_slot: Dictionary = StartGrid.get_single_player_slot()
	player.position = spawn_slot["position"]
	player.rotation = Vector3(0.0, float(spawn_slot["yaw"]), 0.0)
	player.linear_velocity = Vector3.ZERO
	player.angular_velocity = Vector3.ZERO
	player.spawn_transform = player.global_transform


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
	var checkpoint_label := get_node("UI/HUD/Margin/VBox/CheckpointLabel") as Label
	checkpoint_label.text = "檢查點：0 / %d" % TOTAL_CHECKPOINTS


func _setup_ranking() -> void:
	var race_manager := get_node("RaceManager")
	var checkpoint_positions: Array[Vector3] = []
	for checkpoint_data: Dictionary in CHECKPOINTS:
		checkpoint_positions.append(checkpoint_data["position"])
	race_manager.setup_ranking(
		checkpoint_positions,
		FINISH_POSITION,
		StartGrid.get_single_player_slot()["position"]
	)
