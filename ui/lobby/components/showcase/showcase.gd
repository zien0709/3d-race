extends PanelContainer

## Showcase - 中央車輛展示區（2 個車位）
## 自建子節點，場景只需掛一個空的 PanelContainer 加此腳本。

signal slot_selected(index: int, is_self: bool)

const CarSlotScript := preload("res://ui/lobby/components/showcase/car_slot.gd")

var slots: Array = []

func _ready() -> void:
	add_theme_constant_override("separation", 20)
	for i in 2:
		var slot := PanelContainer.new()
		slot.set_script(CarSlotScript)
		add_child(slot)
		slot.slot_clicked.connect(_on_slot_clicked.bind(i))
		slots.append(slot)

func update_slots(players: Array, selected_id: String) -> void:
	if slots.is_empty():
		return
	for i in slots.size():
		var slot = slots[i]
		if i < players.size():
			var p: Dictionary = players[i]
			slot.update_player(p, str(p.get("id", "")) == selected_id)
		else:
			slot.set_empty()

func _on_slot_clicked(index: int, is_self: bool) -> void:
	slot_selected.emit(index, is_self)
