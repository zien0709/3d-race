extends PanelContainer

## Showcase - 中央車輛展示區（動態車位依 max_players）
## 自建子節點，場景只需掛一個空的 PanelContainer 加此腳本。

signal slot_selected(index: int, is_self: bool)

const CarSlotScript := preload("res://ui/lobby/components/showcase/car_slot.gd")

var slots: Array = []
var max_slots: int = 4

func _ready() -> void:
	_rebuild_slots()

func _rebuild_slots() -> void:
	# 清除現有
	for s in slots:
		s.queue_free()
	slots.clear()
	
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(row)
	for i in max_slots:
		var slot := PanelContainer.new()
		slot.set_script(CarSlotScript)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slot)
		slot.slot_clicked.connect(_on_slot_clicked.bind(i))
		slots.append(slot)

func set_max_slots(max_p: int) -> void:
	max_slots = max(max_p, 2)
	_rebuild_slots()

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
