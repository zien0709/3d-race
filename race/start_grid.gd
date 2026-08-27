class_name StartGrid
extends RefCounted

## 出發格位（預留位置）
## 12 台車：3 排 x 4 台。單機只用 slot 0。
## B1 解耦: 格位參數可由 TrackConfig 覆寫 (apply_config)。無覆寫時回退下方常數。

const GRID_SLOT_COUNT := 12
const GRID_COLS := 4
const GRID_ROWS := 3

const GRID_CENTER := Vector3(-115.077791, 1.35, 10.5)
const COL_SPACING := 4.0
const ROW_SPACING := 7.0
const GRID_YAW := 0.0

static var _overrides: Dictionary = {}


static func apply_config(cfg: TrackConfig) -> void:
	_overrides = {
		"center": cfg.start_grid_center,
		"yaw": cfg.start_grid_yaw,
		"cols": cfg.grid_cols,
		"rows": cfg.grid_rows,
		"col_spacing": cfg.col_spacing,
		"row_spacing": cfg.row_spacing,
	}


static func _center() -> Vector3:
	return _overrides.get("center", GRID_CENTER)


static func _yaw() -> float:
	return _overrides.get("yaw", GRID_YAW)


static func _cols() -> int:
	return _overrides.get("cols", GRID_COLS)


static func _rows() -> int:
	return _overrides.get("rows", GRID_ROWS)


static func _col_spacing() -> float:
	return _overrides.get("col_spacing", COL_SPACING)


static func _row_spacing() -> float:
	return _overrides.get("row_spacing", ROW_SPACING)


static func get_single_player_slot() -> Dictionary:
	return {
		"index": 0,
		"position": _center(),
		"yaw": _yaw(),
		"label": "P1",
	}


static func get_slot(slot_index: int, is_single_player: bool = false) -> Dictionary:
	if is_single_player and slot_index == 0:
		return get_single_player_slot()

	slot_index = clampi(slot_index, 0, GRID_SLOT_COUNT - 1)
	@warning_ignore("integer_division")
	var row := slot_index / _cols()
	var col := slot_index % _cols()
	var lateral := (col - (_cols() - 1) * 0.5) * _col_spacing()
	return {
		"index": slot_index,
		"position": Vector3(
			_center().x + lateral,
			_center().y,
			_center().z + row * _row_spacing()
		),
		"yaw": _yaw(),
		"label": "P1" if is_single_player else "P%d" % (slot_index + 1),
	}


static func grid_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for i in GRID_SLOT_COUNT:
		slots.append(get_slot(i))
	return slots


static func assign_slots(peer_ids: Array) -> Dictionary:
	var assignment := {}
	for i in mini(peer_ids.size(), GRID_SLOT_COUNT):
		assignment[peer_ids[i]] = get_slot(i)
	return assignment
