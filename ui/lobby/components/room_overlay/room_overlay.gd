extends Control

## RoomOverlay - 房間設定彈窗（全屏遮罩 + 設定面板）
## 自建子節點，場景只需掛一個空的 Control 加此腳本。

signal config_changed(row: String, value: String)
signal saved()
signal cancelled()

const C_MUTED := Color(0.6, 0.65, 0.7)
const C_ACCENT := Color(0.22, 0.74, 0.97)
const C_SELF := Color(0.062, 0.724, 0.508)
const C_BORDER := Color(0.545, 0.608, 0.706, 0.18)

const CHIP_DEFS := [
	["map", "地圖", ["東京灣夜景", "阿爾卑斯山道", "城市街道"]],
	["mode", "模式", ["經典競速", "淘汰賽", "計時挑戰"]],
	["maxp", "最大人數", ["2人", "3人", "4人"]],
	["privacy", "隱私設定", ["公開", "私人", "好友"]],
	["carr", "車輛限制", ["全開放", "僅S級", "僅A級"]],
	["dmg", "傷害模式", ["關閉", "輕度", "完整"]],
	["auto", "自動開始", ["立即開始", "倒數10秒"]],
]

var room_config: Dictionary = {}

var _dim: ColorRect
var _panel: PanelContainer
var _room_name_input: LineEdit
var _spectator_btn: Button
var _invite_value: Label
var _chip_rows: Dictionary = {}

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func open(config: Dictionary) -> void:
	room_config = config.duplicate(true)
	if _room_name_input != null:
		_room_name_input.text = str(room_config.get("name", ""))
	_update_chips()
	_update_spectator()
	_invite_value.text = str(room_config.get("invite_code", ""))
	visible = true

func get_room_name() -> String:
	return _room_name_input.text.strip_edges() if _room_name_input != null else ""

func update_chips() -> void:
	_update_chips()

## --- UI building ---

func _build_ui() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.031, 0.059, 0.85)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(640, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#131b29")
	sb.set_border_width_all(1)
	sb.border_color = C_ACCENT
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "房間設定"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	## 房間名稱
	vbox.add_child(_make_row("房間名稱", _make_line_edit()))
	_room_name_input = vbox.get_child(vbox.get_child_count() - 1).get_child(1)

	_divider(vbox, "比賽設定")
	for def in CHIP_DEFS.slice(0, 4):
		_add_chip_row(vbox, def)

	_divider(vbox, "進階規則")
	for def in CHIP_DEFS.slice(4):
		_add_chip_row(vbox, def)

	## 觀戰席
	var spec_row := HBoxContainer.new()
	spec_row.add_theme_constant_override("separation", 12)
	var spec_lbl := Label.new()
	spec_lbl.text = "觀戰席"
	spec_lbl.custom_minimum_size = Vector2(90, 0)
	spec_lbl.add_theme_font_size_override("font_size", 13)
	spec_lbl.add_theme_color_override("font_color", C_MUTED)
	spec_row.add_child(spec_lbl)
	_spectator_btn = Button.new()
	_spectator_btn.custom_minimum_size = Vector2(80, 28)
	_spectator_btn.add_theme_font_size_override("font_size", 12)
	_spectator_btn.pressed.connect(_on_spectator_pressed)
	spec_row.add_child(_spectator_btn)
	vbox.add_child(spec_row)

	_divider(vbox, "邀請")
	var inv_row := HBoxContainer.new()
	inv_row.add_theme_constant_override("separation", 12)
	var inv_lbl := Label.new()
	inv_lbl.text = "邀請碼"
	inv_lbl.custom_minimum_size = Vector2(90, 0)
	inv_lbl.add_theme_font_size_override("font_size", 13)
	inv_lbl.add_theme_color_override("font_color", C_MUTED)
	inv_row.add_child(inv_lbl)
	_invite_value = Label.new()
	_invite_value.add_theme_font_size_override("font_size", 13)
	_invite_value.add_theme_color_override("font_color", C_ACCENT)
	inv_row.add_child(_invite_value)
	var copy_btn := Button.new()
	copy_btn.text = "📋 複製"
	copy_btn.custom_minimum_size = Vector2(80, 28)
	copy_btn.add_theme_font_size_override("font_size", 12)
	copy_btn.pressed.connect(_on_copy_pressed)
	inv_row.add_child(copy_btn)
	vbox.add_child(inv_row)

	## 取消 / 儲存
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 12)
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(80, 34)
	cancel_btn.pressed.connect(func(): cancelled.emit(); visible = false)
	btn_row.add_child(cancel_btn)
	var save_btn := Button.new()
	save_btn.text = "儲存"
	save_btn.custom_minimum_size = Vector2(80, 34)
	save_btn.pressed.connect(_on_save_pressed)
	btn_row.add_child(save_btn)
	vbox.add_child(btn_row)

func _make_row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(90, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", C_MUTED)
	row.add_child(lbl)
	row.add_child(control)
	return row

func _make_line_edit() -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = "輸入房間名稱…"
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0, 30)
	return edit

func _add_chip_row(parent: VBoxContainer, def: Array) -> void:
	var chip_script := load("res://ui/lobby/components/room_overlay/chip_row.gd")
	var row := HBoxContainer.new()
	row.set_script(chip_script)
	var initial := _config_value_for(str(def[0]))
	row.setup(str(def[0]), str(def[1]), def[2], initial)
	row.value_changed.connect(_on_chip_changed)
	parent.add_child(row)
	_chip_rows[str(def[0])] = row

func _divider(parent: VBoxContainer, label_text: String) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", C_ACCENT)
	parent.add_child(lbl)

## --- State helpers ---

func _config_value_for(row_key: String) -> String:
	match row_key:
		"maxp":
			return "%d人" % int(room_config.get("max_players", 3))
		"privacy":
			for pair in [["公開", "public"], ["私人", "private"], ["好友", "friends"]]:
				if room_config.get("privacy", "public") == pair[1]:
					return pair[0]
			return "公開"
		_:
			return str(room_config.get(row_key, ""))

func _update_chips() -> void:
	for key in _chip_rows:
		var row = _chip_rows[key]
		row.set_value(_config_value_for(key))

func _update_spectator() -> void:
	var on: bool = bool(room_config.get("spectator", false))
	_spectator_btn.text = "● 開啟" if on else "○ 關閉"
	_style_toggle(_spectator_btn, on)

func _style_toggle(b: Button, on: bool) -> void:
	var bg := Color(0.062, 0.724, 0.508, 0.25) if on else Color(1, 1, 1, 0.05)
	var border := C_SELF if on else C_BORDER
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", sb)
	b.remove_theme_stylebox_override("hover")
	b.remove_theme_stylebox_override("pressed")

## --- Handlers ---

func _on_chip_changed(row: String, value: String) -> void:
	match row:
		"maxp":
			room_config["max_players"] = int(value.replace("人", ""))
		"privacy":
			for pair in [["公開", "public"], ["私人", "private"], ["好友", "friends"]]:
				if value == pair[0]:
					room_config["privacy"] = pair[1]
		"carr":
			room_config["car_restriction"] = value
		"dmg":
			room_config["damage_mode"] = value
		"auto":
			room_config["auto_start"] = value
		_:
			room_config[row] = value
	config_changed.emit(row, value)

func _on_spectator_pressed() -> void:
	room_config["spectator"] = not bool(room_config.get("spectator", false))
	_update_spectator()

func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(str(room_config.get("invite_code", "")))
	var toast_node := get_node_or_null("../../Toast")
	if toast_node != null and toast_node.has_method("show_message"):
		toast_node.show_message("已複製邀請碼")

func _on_save_pressed() -> void:
	var name_input := get_room_name()
	if name_input != "":
		room_config["name"] = name_input
	visible = false
	saved.emit()
