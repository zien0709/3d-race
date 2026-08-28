class_name CarRegistry
extends RefCounted

## 車型登錄表：car_id -> 車輛模型 PackedScene。
## 新增車型只需在 CAR_SCENES 加一筆，UI 與 spawner 自動生效。

const CAR_SCENES := {
	"concept": preload("res://Car Model/ConceptCar 050/scene.gltf"),
	"huracan": preload("res://Car Model/Huracan Black-Panther/scene.gltf"),
}

const DEFAULT_CAR_ID := "concept"


static func get_car_scene(car_id: String) -> PackedScene:
	if CAR_SCENES.has(car_id):
		return CAR_SCENES[car_id]
	return CAR_SCENES.get(DEFAULT_CAR_ID)


static func get_available_car_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in CAR_SCENES.keys():
		ids.append(id)
	return ids
