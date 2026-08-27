class_name TrackConfig
extends Resource

## 賽道可變資料單一來源 (B1 解耦: 取代 race_course_setup.gd 的硬編碼常量)
## 預設賽道 = res://tracks/default.tres
## 未來第二賽道只需新增 res://tracks/<id>.tres + 對應 glb，不改 race_course_setup.gd 邏輯碼。

@export var track_id: StringName = &"default"
@export var display_name: String = "預設賽道"
@export var scene_path: String = "res://race_map.glb"

@export var gate_size: Vector3 = Vector3(14.0, 3.0, 4.0)

@export var checkpoint_positions: Array[Vector3] = []
@export var checkpoint_yaws: Array[float] = []

@export var finish_position: Vector3 = Vector3.ZERO
@export var finish_yaw: float = 0.0

@export var start_grid_center: Vector3 = Vector3.ZERO
@export var start_grid_yaw: float = 0.0
@export var grid_cols: int = 4
@export var grid_rows: int = 3
@export var col_spacing: float = 4.0
@export var row_spacing: float = 7.0

@export var roadbed_path: String = "RaceMap/Roadbed_Shoulder"


func total_checkpoints() -> int:
	return checkpoint_positions.size()


func checkpoint_transforms() -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for i in checkpoint_positions.size():
		var yaw := 0.0
		if i < checkpoint_yaws.size():
			yaw = checkpoint_yaws[i]
		out.append(_build_transform(checkpoint_positions[i], yaw))
	return out


func finish_transform() -> Transform3D:
	return _build_transform(finish_position, finish_yaw)


func _build_transform(pos: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)), pos)
