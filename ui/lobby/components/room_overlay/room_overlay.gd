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

@onready var _ui_animations: UIAnimations = UIAnimations

const CHIP_DEFS := [
	["map", "地圖", ["東京灣夜景", "阿爾卑斯山道", "城市街道"]],
	["mode", "模式", ["經典競速", "淘汰賽", "計時挑戰"]],
	["maxp", "最大人數", []],
	["privacy", "隱私設定", ["公開", "私人", "好友"]],
	["carr", "車輛限制", ["全開放", "僅S級", "僅A級"]],
	["dmg", "傷害模式", ["關閉", "輕度", "完整"]],
	["auto", "自動開始", ["立即開始", "倒數10秒"]],
]

func _get_maxp_options() -> Array:
	var max_p := int(room_config.get("max_players", 0))
	if max_p <= 0:
		max_p = 4
	var opts := []
	for i in range(2, max_p + 1):
		opts.append("%d人" % i)
	return opts

var room_config: Dictionary = {}
var is_host: bool = false

var _dim: ColorRect
var _panel: PanelContainer
var _room_name_input: LineEdit
var _spectator_btn: Button
var _spectator_visual: PanelContainer
var _invite_value: Label
var _chip_rows: Dictionary = {}

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func open(config: Dictionary, host: bool = false) -> void:
	room_config = config.duplicate(true)
	is_host = host
	if _room_name_input != null:
		_room_name_input.text = str(room_config.get("name", ""))
	_update_chips()
	_update_spectator()
	_invite_value.text = str(room_config.get("invite_code", ""))
	_ui_animations.kill_tweens(self)
	_ui_animations.panel_open(self, 0.25)
	_toggle_host_controls(is_host)

func close() -> void:
	_ui_animations.kill_tweens(self)
	var tween := _ui_animations.panel_close(self, 0.2)
	await tween.finished
	visible = false

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
	
	# Visual container for animations (like ChipRow)
	_spectator_visual = PanelContainer.new()
	_spectator_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spectator_visual.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spectator_visual.offset_left = 0
	_spectator_visual.offset_top = 0
	_spectator_visual.offset_right = 0
	_spectator_visual.offset_bottom = 0
	
	# Initial stylebox for visual container
	var initial_sb := StyleBoxFlat.new()
	initial_sb.bg_color = Color(1, 1, 1, 0.05)
	initial_sb.set_border_width_all(1)
	initial_sb.border_color = C_BORDER
	initial_sb.set_corner_radius_all(6)
	initial_sb.content_margin_left = 8
	initial_sb.content_margin_right = 8
	initial_sb.content_margin_top = 4
	initial_sb.content_margin_bottom = 4
	_spectator_visual.add_theme_stylebox_override("panel", initial_sb)
	
	_spectator_btn.add_child(_spectator_visual)
	
	var spec_label := Label.new()
	spec_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spec_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	spec_label.add_theme_font_size_override("font_size", 12)
	spec_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spec_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	spec_label.offset_left = 8
	spec_label.offset_right = -8
	spec_label.offset_top = 4
	spec_label.offset_bottom = -4
	_spectator_visual.add_child(spec_label)
	_spectator_btn.set_meta("_label", spec_label)
	
	# Make Button itself transparent
	var transparent_sb := StyleBoxFlat.new()
	transparent_sb.bg_color = Color(0, 0, 0, 0)
	_spectator_btn.add_theme_stylebox_override("normal", transparent_sb)
	_spectator_btn.add_theme_stylebox_override("hover", transparent_sb)
	_spectator_btn.add_theme_stylebox_override("pressed", transparent_sb)
	_spectator_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	# Connect animation signals
	_spectator_btn.mouse_entered.connect(_on_spectator_mouse_entered)
	_spectator_btn.mouse_exited.connect(_on_spectator_mouse_exited)
	_spectator_btn.gui_input.connect(_on_spectator_gui_input)
	
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
	cancel_btn.pressed.connect(func(): cancelled.emit(); close())
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
	
	# 對 maxp 使用動態選項
	var opts: Array = def[2]
	if str(def[0]) == "maxp":
		opts = _get_maxp_options()
	
	row.setup(str(def[0]), str(def[1]), opts, initial)
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
			return "%d人" % int(room_config.get("max_players", 4))
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
	var spec_label: Label = _spectator_btn.get_meta("_label")
	spec_label.text = "● 開啟" if on else "○ 關閉"
	_style_toggle(_spectator_visual, on)

func _style_toggle(visual: PanelContainer, on: bool) -> void:
	var target_bg := Color(0.062, 0.724, 0.508, 0.25) if on else Color(1, 1, 1, 0.05)
	var target_border := C_SELF if on else C_BORDER
	
	# Animate background color transition over 0.15s
	_ui_animations.kill_tweens(visual)
	var current_sb: StyleBoxFlat = visual.get_theme_stylebox("panel") as StyleBoxFlat
	var tween := create_tween().set_parallel(true)
	
	# Animate bg_color
	tween.tween_property(current_sb, "bg_color", target_bg, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Animate border_color
	tween.tween_property(current_sb, "border_color", target_border, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Create hover/pressed states
	var hover_sb := current_sb.duplicate()
	hover_sb.bg_color = target_bg.lightened(0.12)
	visual.add_theme_stylebox_override("panel_hover", hover_sb)
	
	var pressed_sb := current_sb.duplicate()
	pressed_sb.bg_color = target_bg.darkened(0.12)
	visual.add_theme_stylebox_override("panel_pressed", pressed_sb)
	
	# Scale pop animation on toggle (1.1x -> 1.0x with TRANS_BACK/EASE_OUT)
	visual.scale = Vector2(1.1, 1.1)
	var scale_tween := create_tween()
	scale_tween.tween_property(visual, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _toggle_host_controls(host: bool) -> void:
	# 針對 carr (車輛限制) 和 dmg (傷害模式) 兩個進階規則
	if _chip_rows.has("carr"):
		var row = _chip_rows["carr"]
		row.set_disabled(not host)
		if not host:
			row.set_chip_tooltip("高級規則 - 僅房主開放 (Future feature)")
	if _chip_rows.has("dmg"):
		var row = _chip_rows["dmg"]
		row.set_disabled(not host)
		if not host:
			row.set_chip_tooltip("高級規則 - 僅房主開放 (Future feature)")

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
			if not is_host:
				push_warning("車輛限制：僅房主可修改")
				_update_chips()
				return
			room_config["car_restriction"] = value
		"dmg":
			if not is_host:
				push_warning("傷害模式：僅房主可修改")
				_update_chips()
				return
			room_config["damage_mode"] = value
		"auto":
			room_config["auto_start"] = value
		_:
			room_config[row] = value
	config_changed.emit(row, value)

func _on_spectator_pressed() -> void:
	room_config["spectator"] = not bool(room_config.get("spectator", false))
	_update_spectator()

func _on_spectator_mouse_entered() -> void:
	_ui_animations.kill_tweens(_spectator_visual)
	var tween := create_tween()
	tween.tween_property(_spectator_visual, "scale", Vector2(1.03, 1.03), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_spectator_mouse_exited() -> void:
	_ui_animations.kill_tweens(_spectator_visual)
	var tween := create_tween()
	tween.tween_property(_spectator_visual, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_spectator_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_ui_animations.kill_tweens(_spectator_visual)
			var tween := create_tween()
			tween.tween_property(_spectator_visual, "scale", Vector2(0.95, 0.95), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			_ui_animations.kill_tweens(_spectator_visual)
			var is_hovered := _spectator_visual.get_rect().has_point(_spectator_visual.get_local_mouse_position())
			var target_scale = Vector2(1.03, 1.03) if is_hovered else Vector2(1.0, 1.0)
			var tween := create_tween()
			tween.tween_property(_spectator_visual, "scale", target_scale, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(str(room_config.get("invite_code", "")))
	var toast_node := get_node_or_null("../../Toast")
	if toast_node != null and toast_node.has_method("show_message"):
		toast_node.show_message("已複製邀請碼")

func _on_save_pressed() -> void:
	var name_input := get_room_name()
	if name_input != "":
		room_config["name"] = name_input
	close()
	saved.emit()
