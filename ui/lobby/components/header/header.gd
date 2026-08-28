extends Control

## Header - 頂部導航列：ProfileBox + RoomCapsule + ActionButtons
## 自建子節點，場景只需掛一個空的 Control 加此腳本。

signal room_settings_requested()
signal system_settings_requested()
signal invite_requested()
signal leave_room_requested()
signal browser_requested()

const C_TEXT := Color(0.85, 0.88, 0.92)
const C_MUTED := Color(0.5, 0.55, 0.6)
const C_ACCENT := Color(0.3, 0.85, 0.95)
const C_DANGER := Color(0.8, 0.2, 0.2)
const C_DANGER_BORDER := Color(0.8, 0.2, 0.2, 0.6)
const C_DANGER_BG := Color(0.35, 0.1, 0.1)
const C_GREEN := Color(0.3, 0.9, 0.4)

var _name_label: Label
var _level_label: Label
var _puid_label: Label
var _ping_label: Label
var _room_name_label: Label
var _player_count_label: Label
var _invite_btn: Button
var _browser_btn: Button
var _leave_btn: Button
var _capsule_style: StyleBoxFlat
var _capsule: PanelContainer
var _max_players: int = 4

func _ready() -> void:
	custom_minimum_size = Vector2(0, 64)
	clip_contents = false

	# VBoxContainer CENTER with full-rect anchors for proper fill in Control parent
	var center_wrap := VBoxContainer.new()
	center_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_wrap.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center_wrap.grow_vertical = Control.GROW_DIRECTION_BOTH
	center_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	center_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_wrap)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.clip_contents = false
	row.custom_minimum_size.y = 44
	row.add_theme_constant_override("separation", 12)
	center_wrap.add_child(row)

	_build_profile_box(row)
	_build_room_capsule(row)
	_build_action_buttons(row)

func _draw() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.1, 0.13)
	bg.set_corner_radius_all(10)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))

## ── ProfileBox ──────────────────────────────────────────────

func _build_profile_box(parent: Node) -> void:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(240, 60)
	box.size_flags_horizontal = 0 # SHRINK_BEGIN
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18)
	style.set_corner_radius_all(8)
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	box.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(row)

	# Avatar emoji
	var avatar := Label.new()
	avatar.text = "🏎️"
	avatar.add_theme_font_size_override("font_size", 20)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(avatar)

	# Info column
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)

	# Name + Level row
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	col.add_child(name_row)

	_name_label = Label.new()
	_name_label.text = "Player"
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", C_TEXT)
	name_row.add_child(_name_label)

	_level_label = Label.new()
	_level_label.text = "Lv.1 🥉 青銅 I"
	_level_label.add_theme_font_size_override("font_size", 11)
	_level_label.add_theme_color_override("font_color", C_MUTED)
	name_row.add_child(_level_label)

	# PUID row (clickable capsule)
	var puid_row := HBoxContainer.new()
	puid_row.add_theme_constant_override("separation", 4)
	col.add_child(puid_row)

	_puid_label = Label.new()
	_puid_label.text = "PUID: ------"
	_puid_label.add_theme_font_size_override("font_size", 10)
	_puid_label.add_theme_color_override("font_color", C_MUTED)
	puid_row.add_child(_puid_label)

	var copy_btn := Button.new()
	copy_btn.text = "📋"
	copy_btn.add_theme_font_size_override("font_size", 10)
	copy_btn.custom_minimum_size = Vector2(20, 18)
	copy_btn.pressed.connect(_on_copy_puid)
	puid_row.add_child(copy_btn)

	# Ping row
	_ping_label = Label.new()
	_ping_label.text = "📶 --ms 🟢"
	_ping_label.add_theme_font_size_override("font_size", 10)
	_ping_label.add_theme_color_override("font_color", C_GREEN)
	col.add_child(_ping_label)

	parent.add_child(box)

## ── RoomCapsule ─────────────────────────────────────────────
# Structure: LeftSpacer → RoomNameLabel (centered) → RightSpacer → PlayerCountLabel

func _build_room_capsule(parent: Node) -> void:
	_capsule = PanelContainer.new()
	_capsule.name = "RoomCapsule"
	_capsule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_capsule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_capsule.custom_minimum_size = Vector2(200, 50)
	_capsule.size_flags_stretch_ratio = 3.0
	_capsule.clip_contents = false

	_capsule_style = StyleBoxFlat.new()
	_capsule_style.bg_color = Color(0.10, 0.13, 0.17)
	_capsule_style.set_corner_radius_all(12)
	_capsule_style.content_margin_top = 8
	_capsule_style.content_margin_bottom = 8
	_capsule_style.content_margin_left = 16
	_capsule_style.content_margin_right = 16
	_capsule_style.set_border_width_all(1)
	_capsule_style.border_color = Color(0.3, 0.85, 0.95, 0.4)
	_capsule_style.shadow_color = Color(0.3, 0.85, 0.95, 0.1)
	_capsule_style.shadow_size = 4
	_capsule.add_theme_stylebox_override("panel", _capsule_style)

	# Click anywhere on capsule → room settings
	_capsule.gui_input.connect(_on_capsule_gui_input)
	# Hover glow
	_capsule.mouse_entered.connect(_on_capsule_hover.bind(true))
	_capsule.mouse_exited.connect(_on_capsule_hover.bind(false))

	var capsule_hbox := HBoxContainer.new()
	capsule_hbox.name = "CapsuleHBox"
	capsule_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capsule_hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	capsule_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	capsule_hbox.add_theme_constant_override("separation", 8)
	_capsule.add_child(capsule_hbox)

	# Left spacer (pushes room name to absolute center)
	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capsule_hbox.add_child(left_spacer)

	# Room name with globe icon (18px Bold, absolutely centered)
	_room_name_label = Label.new()
	_room_name_label.text = "🌐 我的房間"
	_room_name_label.add_theme_font_size_override("font_size", 18)
	_room_name_label.add_theme_color_override("font_color", C_TEXT)
	_room_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_room_name_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_room_name_label.custom_minimum_size = Vector2(150, 0)
	_room_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	capsule_hbox.add_child(_room_name_label)

	# Right spacer (pushes room name to absolute center)
	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capsule_hbox.add_child(right_spacer)

	# Player count (dynamic from room_config.max_players)
	_player_count_label = Label.new()
	_player_count_label.text = "👥 0/4"
	_player_count_label.add_theme_font_size_override("font_size", 12)
	_player_count_label.add_theme_color_override("font_color", C_TEXT)
	_player_count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_player_count_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	_player_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	capsule_hbox.add_child(_player_count_label)

	# Ensure all children inside capsule_hbox have proper vertical centering
	for child in capsule_hbox.get_children():
		if child is Control:
			child.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if child is Label:
			child.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	parent.add_child(_capsule)

func _on_capsule_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		room_settings_requested.emit()

func _on_capsule_hover(entered: bool) -> void:
	if _capsule_style == null:
		return
	if entered:
		_capsule_style.border_color = Color(0.3, 0.85, 0.95, 0.8)
		_capsule_style.shadow_size = 6
		_capsule_style.shadow_color = Color(0.3, 0.85, 0.95, 0.2)
	else:
		_capsule_style.border_color = Color(0.3, 0.85, 0.95, 0.4)
		_capsule_style.shadow_size = 4
		_capsule_style.shadow_color = Color(0.3, 0.85, 0.95, 0.1)

## ── ActionButtons ───────────────────────────────────────────

func _build_action_buttons(parent: Node) -> void:
	var box := HBoxContainer.new()
	box.name = "ActionButtons"
	box.add_theme_constant_override("separation", 4)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.custom_minimum_size = Vector2(80, 0)

	# Invite button
	_invite_btn = _make_icon_button(box, "🔗", func(): invite_requested.emit())
	_invite_btn.custom_minimum_size = Vector2(38, 38)

	# Browser button (🔍)
	_browser_btn = _make_icon_button(box, "🔍", func(): browser_requested.emit())
	_browser_btn.custom_minimum_size = Vector2(38, 38)
	_browser_btn.tooltip_text = "房間瀏覽器"

	# Leave button (danger - dark red border)
	_leave_btn = _make_danger_button(box, "🚪")
	_leave_btn.custom_minimum_size = Vector2(38, 38)
	_leave_btn.pressed.connect(func(): leave_room_requested.emit())

	# Ensure all buttons have uniform size and vertical centering
	for btn in box.get_children():
		if btn is Button:
			btn.custom_minimum_size = Vector2(38, 38)
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	parent.add_child(box)

## ── Public API ──────────────────────────────────────────────

func update_profile(display_name: String, level: int, rank_label: String, puid: String, ping_ms: int) -> void:
	if _name_label:
		_name_label.text = display_name
	if _level_label:
		_level_label.text = "Lv.%d %s" % [level, rank_label]
	if _puid_label:
		if puid.length() > 16:
			_puid_label.text = "PUID: %s...%s" % [puid.substr(0, 6), puid.substr(-5)]
		else:
			_puid_label.text = "PUID: %s" % puid
		_puid_label.tooltip_text = puid
	if _ping_label:
		if ping_ms > 0:
			_ping_label.text = "📶 %dms 🟢" % ping_ms
			_ping_label.add_theme_color_override("font_color", C_GREEN)
		else:
			_ping_label.text = "📶 --ms 🟢"
			_ping_label.add_theme_color_override("font_color", C_MUTED)

func update_room_capsule(room_config: Dictionary, players: Array, lobby_manager: Object) -> void:
	if _room_name_label:
		var room_name = room_config.get("name", "我的房間")
		_room_name_label.text = "🌐 %s" % room_name
	if _player_count_label:
		var max_p = lobby_manager.max_members if lobby_manager else _max_players
		if max_p <= 0:
			max_p = room_config.get("max_players", _max_players)
			if max_p <= 0:
				max_p = 4
		_player_count_label.text = "👥 %d/%d" % [players.size(), max_p]

func set_in_room(in_room: bool) -> void:
	if _leave_btn:
		_leave_btn.visible = in_room

## ── Internal helpers ────────────────────────────────────────

func _on_copy_puid() -> void:
	var puid_text = _puid_label.tooltip_text if _puid_label else ""
	if puid_text != "":
		DisplayServer.clipboard_set(puid_text)

func _make_icon_button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(38, 38)
	b.add_theme_font_size_override("font_size", 16)
	b.size_flags_vertical = 1 # SHRINK_CENTER
	_apply_button_style(b, Color(0.14, 0.17, 0.22), C_TEXT)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _make_danger_button(parent: Node, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(38, 38)
	b.add_theme_font_size_override("font_size", 16)
	b.size_flags_vertical = 1 # SHRINK_CENTER
	_apply_button_style(b, C_DANGER_BG, C_DANGER)
	var style = b.get_theme_stylebox("normal")
	if style is StyleBoxFlat:
		style.set_border_width_all(1)
		style.border_color = C_DANGER_BORDER
	parent.add_child(b)
	return b

func _apply_button_style(btn: Button, bg_color: Color, font_color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = bg_color.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color.lightened(0.2))
