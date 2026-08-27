extends PanelContainer

## Showcase - 中央車輛展示區（動態佈局 + 不對稱 3 人房）
## 自建子節點，場景只需掛一個空的 PanelContainer 加此腳本。

signal slot_selected(index: int, is_self: bool)

const CarSlotScript := preload("res://ui/lobby/components/showcase/car_slot.gd")

const C_PANEL := Color(0.08, 0.1, 0.13)

var slots: Array = []
var max_slots: int = 4

func _ready() -> void:
	# Dark background
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.set_corner_radius_all(10)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	# IMPORTANT: disable clip_contents so car_slot glow shadow is not clipped
	clip_contents = false
	_rebuild_slots()

func _rebuild_slots() -> void:
	for s in slots:
		s.queue_free()
	slots.clear()

	# Remove old container
	for child in get_children():
		if child is Container:
			child.queue_free()

	var container: Container
	if max_slots <= 2:
		# 2 players: 1x2 horizontal
		container = HBoxContainer.new()
		container.add_theme_constant_override("separation", 16)
		_add_slots(container, max_slots)
	elif max_slots == 3:
		# 3 players: asymmetric - 1 big top + 2 small bottom
		container = VBoxContainer.new()
		container.add_theme_constant_override("separation", 16)
		_build_asymmetric_3(container)
	else:
		# 4+ players: 2x2 grid
		container = GridContainer.new()
		container.columns = 2
		container.add_theme_constant_override("h_separation", 16)
		container.add_theme_constant_override("v_separation", 16)
		_add_slots(container, max_slots)

	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.clip_contents = false
	add_child(container)

func _build_asymmetric_3(parent: Node) -> void:
	# Top row: 1 big slot (player 0)
	var top_slot := _create_slot()
	top_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(top_slot)

	# Bottom row: 2 slots (players 1, 2)
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 16)
	bottom_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(bottom_row)

	for i in range(1, 3):
		var slot := _create_slot()
		bottom_row.add_child(slot)

func _add_slots(parent: Node, count: int) -> void:
	for i in count:
		var slot := _create_slot()
		parent.add_child(slot)

func _create_slot() -> PanelContainer:
	var slot := PanelContainer.new()
	slot.set_script(CarSlotScript)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.clip_contents = false
	slot.slot_clicked.connect(_on_slot_clicked.bind(slots.size()))
	slots.append(slot)
	return slot

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
			var is_sel: bool = str(p.get("id", "")) == selected_id
			var host: bool = bool(p.get("is_host", false))
			slot.update_player(p, is_sel, host)
		else:
			slot.set_empty()

func _on_slot_clicked(index: int, is_self: bool) -> void:
	slot_selected.emit(index, is_self)
