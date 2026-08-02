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
