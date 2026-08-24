extends Control

## LobbyBrowser - 搜尋/加入公開房間的彈窗
## 自建子節點，場景只需掛一個空的 Control 加此腳本。

signal search_requested()
signal join_requested(lobby)
signal closed()

const C_MUTED := Color(0.6, 0.65, 0.7)
const C_ACCENT := Color(0.22, 0.74, 0.97)
const C_BORDER := Color(0.545, 0.608, 0.706, 0.18)

var _status_label: Label
var _list_root: VBoxContainer
var _scroll: ScrollContainer
var _busy := false

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func open() -> void:
	visible = true

func close() -> void:
	visible = false
	closed.emit()

func set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text

func is_busy() -> bool:
	return _busy

func set_busy(busy: bool) -> void:
	_busy = busy

func set_results(results: Array, lobby_manager) -> void:
	for c in _list_root.get_children():
		c.queue_free()
	if results.is_empty():
		set_status("找不到公開房間（確認 host 已開房且設為公開）")
		return
	set_status("找到 %d 間房間" % results.size())
	for lb in results:
		var info: Dictionary = {}
		if lobby_manager != null and lobby_manager.has_method("result_info"):
			info = lobby_manager.result_info(lb)
		else:
			info = {"lobby": lb, "room_name": "", "host_name": "Host",
					"max_members": int(lb.max_members), "available_slots": int(lb.available_slots)}
		_list_root.add_child(_make_row(info))

func _make_row(info: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.03)
	sb.set_border_width_all(1)
	sb.border_color = C_BORDER
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var info_col := VBoxContainer.new()
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_col)

	var room_name: String = str(info.get("room_name", ""))
	if room_name == "":
		room_name = str(info.get("host_name", "Host")) + " 的房間"
	var max_p := int(info.get("max_members", 0))
	var available := int(info.get("available_slots", 0))
	var count: int = max_p - available

	var title := Label.new()
	title.text = room_name
	title.add_theme_font_size_override("font_size", 16)
	info_col.add_child(title)
	var sub := Label.new()
	sub.text = "%s  ·  %d/%d" % [str(info.get("host_name", "Host")), count, max_p]
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", C_MUTED)
	info_col.add_child(sub)

	var lb = info.get("lobby")
	var join := Button.new()
	join.text = "加入"
	join.custom_minimum_size = Vector2(70, 30)
	join.add_theme_font_size_override("font_size", 13)
	join.pressed.connect(func(): join_requested.emit(lb))
	if count >= max_p and max_p > 0:
		join.disabled = true
		join.text = "已滿"
	hbox.add_child(join)
	return row

## --- UI building ---

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.031, 0.059, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 560)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#131b29")
	sb.set_border_width_all(1)
	sb.border_color = C_ACCENT
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "搜尋房間"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(26, 26)
	close_btn.flat = true
	close_btn.pressed.connect(close)
	header.add_child(close_btn)
	vbox.add_child(header)

	var refresh_btn := Button.new()
	refresh_btn.text = "⟳ 重新搜尋"
	refresh_btn.custom_minimum_size = Vector2(120, 30)
	refresh_btn.add_theme_font_size_override("font_size", 12)
	refresh_btn.pressed.connect(func(): search_requested.emit())
	vbox.add_child(refresh_btn)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll)

	_list_root = VBoxContainer.new()
	_list_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_root.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list_root)

	_status_label = Label.new()
	_status_label.text = "點擊「重新搜尋」尋找公開房間"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(_status_label)
