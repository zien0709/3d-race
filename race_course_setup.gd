extends Node3D

## B1+B2 賽道解耦: 可變資料移到 TrackConfig，並透過 TrackRegistry Autoload 跨場景傳遞選中的賽道。
## 無 TrackConfig 時回退下方硬編碼常數，舊流程 100% 不變。

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

var _track: TrackConfig = null


func _ready() -> void:
	_apply_track_config()
	_remove_test_course()
	_configure_player()
	_create_finish_gate()
	_create_checkpoint_gates()
	_configure_race_manager()
	_apply_match_config()
	_setup_ranking()
	_register_groups()


func _apply_track_config() -> void:
	## 優先從 TrackRegistry 取得選中的賽道 (跨場景傳遞)，回退到 default.tres，再回退到硬編碼常數
	var cfg: TrackConfig = null
	if TrackRegistry != null:
		cfg = TrackRegistry.get_selected_track()
	if cfg == null:
		cfg = load("res://tracks/default.tres") as TrackConfig
	if cfg == null:
		push_warning("TrackConfig 皆缺失，使用硬編碼預設賽道")
		return
	_track = cfg
	if cfg.has_method("apply_config"):
		StartGrid.apply_config(cfg)


func _checkpoint_transforms() -> Array[Transform3D]:
	if _track != null:
		return _track.checkpoint_transforms()
	var out: Array[Transform3D] = []
	for d in CHECKPOINTS:
		out.append(Transform3D(Basis.from_euler(Vector3(0.0, float(d["yaw"]), 0.0)), d["position"]))
	return out


func _finish_transform() -> Transform3D:
	if _track != null:
		return _track.finish_transform()
	return Transform3D(Basis.from_euler(Vector3(0.0, FINISH_YAW, 0.0)), FINISH_POSITION)


func _gate_size() -> Vector3:
	if _track != null:
		return _track.gate_size
	return GATE_SIZE


func _total_checkpoints() -> int:
	if _track != null:
		return _track.total_checkpoints()
	return TOTAL_CHECKPOINTS


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
	# 本機玩家車型：從 MatchConfig 讀取（單機無 lobby 時用預設車）
	var local_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var car_id := "concept"
	if LobbyManager != null and LobbyManager.match_config.has("players"):
		for p in LobbyManager.match_config["players"]:
			if int(p.get("peer_id", -1)) == local_id:
				car_id = str(p.get("car_id", "concept"))
				break
	if player.has_method("set_car_id"):
		player.set_car_id(car_id)


func _create_finish_gate() -> void:
	var finish := Area3D.new()
	finish.name = "Finish"
	finish.set_script(FINISH_SCRIPT)
	var t := _finish_transform()
	finish.position = t.origin
	finish.rotation.y = float(t.basis.get_euler().y)
	finish.collision_layer = 0
	finish.collision_mask = 1
	finish.add_child(_create_gate_shape())
	add_child(finish)


func _create_checkpoint_gates() -> void:
	var checkpoint_root := Node3D.new()
	checkpoint_root.name = "CheckPoints"
	add_child(checkpoint_root)

	var transforms := _checkpoint_transforms()
	for checkpoint_offset in range(transforms.size()):
		var checkpoint_index := checkpoint_offset + 1
		var t := transforms[checkpoint_offset]
		var checkpoint := Area3D.new()
		checkpoint.name = "CheckPoint%d" % checkpoint_index
		checkpoint.set_script(CHECKPOINT_SCRIPT)
		checkpoint.set("checkpoint_index", checkpoint_index)
		checkpoint.position = t.origin
		checkpoint.rotation.y = float(t.basis.get_euler().y)
		checkpoint.collision_layer = 0
		checkpoint.collision_mask = 1
		checkpoint.add_child(_create_gate_shape())
		checkpoint_root.add_child(checkpoint)


func _create_gate_shape() -> CollisionShape3D:
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var box_shape := BoxShape3D.new()
	box_shape.size = _gate_size()
	collision_shape.shape = box_shape
	return collision_shape


func _configure_race_manager() -> void:
	var race_manager := get_node("RaceManager")
	race_manager.set("total_checkpoints", _total_checkpoints())
	var time_trial_hud := get_node("UI/HUD")
	time_trial_hud.reset(_total_checkpoints())


## 將 MatchConfig 的賽制欄位帶入 RaceManager（本輪先存欄位，賽制分支留待下一輪）
func _apply_match_config() -> void:
	if LobbyManager == null or LobbyManager.match_config.is_empty():
		return
	var race_manager := get_node_or_null("RaceManager")
	if race_manager == null:
		return
	race_manager.set("race_mode", LobbyManager.match_config.get("mode", "time_trial"))
	race_manager.set("damage_mode", LobbyManager.match_config.get("damage_mode", "off"))


func _setup_ranking() -> void:
	var race_manager := get_node("RaceManager")
	var checkpoint_positions: Array[Vector3] = []
	for t in _checkpoint_transforms():
		checkpoint_positions.append(t.origin)
	var finish_t := _finish_transform()
	var start_pos: Vector3 = StartGrid.get_single_player_slot()["position"]
	race_manager.setup_ranking(
		checkpoint_positions,
		finish_t.origin,
		start_pos
	)
