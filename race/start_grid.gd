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


static func get_single_player_slot() -> Dictionary:
	return {
		"index": 0,
		"position": GRID_CENTER,
		"yaw": GRID_YAW,
		"label": "P1",
	}


static func get_slot(slot_index: int, is_single_player: bool = false) -> Dictionary:
	if is_single_player and slot_index == 0:
		return get_single_player_slot()

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
		"label": "P1" if is_single_player else "P%d" % (slot_index + 1),
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
