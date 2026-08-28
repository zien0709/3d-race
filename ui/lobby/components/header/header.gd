extends PanelContainer

## Header - 頂部導航列：ProfileBox + RoomCapsule + ActionButtons
## 自建子節點，場景只需掛一個空的 PanelContainer 加此腳本。

signal room_settings_requested()
signal system_settings_requested()
signal invite_requested()
signal leave_room_requested()

@onready var _ui_animations := UIAnimations

const C_TEXT := Color(0.85, 0.88, 0.92)
const C_MUTED := Color(0.5, 0.55, 0.6)
const C_ACCENT := Color(0.3, 0.85, 0.95)
const C_DANGER := Color(0.9, 0.25, 0.25)
const C_DANGER_BG := Color(0.35, 0.1, 0.1)
const C_GREEN := Color(0.3, 0.9, 0.4)

var _name_label: Label
var _level_label: Label
var _puid_label: Label
var _ping_label: Label
var _room_name_label: Label
var _badges_container: HBoxContainer
var _player_count_label: Label
var _gear_btn: Button
var _invite_btn: Button
var _leave_btn: Button

func _ready() -> void:
	custom_minimum_size = Vector2(0, 64)
	clip_contents = false

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.clip_contents = false
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	_build_profile_box(row)
	_build_room_capsule(row)
	_build_action_buttons(row)

## ── ProfileBox ──────────────────────────────────────────────

func _build_profile_box(parent: Node) -> void:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(240, 0)
	box.size_flags_horizontal = 0 # SHRINK_BEGIN

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	box.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	# Avatar emoji
	var avatar := Label.new()
	avatar.text = "🏎️"
	avatar.add_theme_font_size_override("font_size", 28)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(avatar)

	# Info column
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
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

	# PUID row
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

func _build_room_capsule(parent: Node) -> void:
	var capsule := PanelContainer.new()
	capsule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capsule.custom_minimum_size = Vector2(200, 48)
	capsule.size_flags_stretch_ratio = 3.0
	capsule.clip_contents = false

	var capsule_style := StyleBoxFlat.new()
	capsule_style.bg_color = Color(0.10, 0.13, 0.17)
	capsule_style.set_corner_radius_all(8)
	capsule_style.set_content_margin_all(10)
	capsule_style.set_border_width_all(1)
	capsule_style.border_color = Color(0.3, 0.85, 0.95, 0.6)
	capsule_style.shadow_color = Color(0.3, 0.85, 0.95, 0.15)
	capsule_style.shadow_size = 4
	capsule.add_theme_stylebox_override("panel", capsule_style)

	var inner := HBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 8)
	capsule.add_child(inner)

	# Globe icon
	var globe := Label.new()
	globe.text = "🌐"
	globe.add_theme_font_size_override("font_size", 16)
	globe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(globe)

	# Room name
	_room_name_label = Label.new()
	_room_name_label.text = "我的房間"
	_room_name_label.add_theme_font_size_override("font_size", 14)
	_room_name_label.add_theme_color_override("font_color", C_TEXT)
	_room_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_room_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inner.add_child(_room_name_label)

	# Badges container
	_badges_container = HBoxContainer.new()
	_badges_container.add_theme_constant_override("separation", 4)
	_badges_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badges_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	inner.add_child(_badges_container)

	# Spacer (pushes right-side items to capsule edge)
	var capsule_spacer := Control.new()
	capsule_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capsule_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(capsule_spacer)

	# Player count (inside capsule, right side)
	_player_count_label = Label.new()
	_player_count_label.text = "👥 0/0"
	_player_count_label.add_theme_font_size_override("font_size", 12)
	_player_count_label.add_theme_color_override("font_color", C_TEXT)
	_player_count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(_player_count_label)

	# Gear button (room settings, inside capsule right side)
	_gear_btn = _make_icon_button(inner, "⚙️", func(): room_settings_requested.emit())

	parent.add_child(capsule)

## ── Spacer ───────────────────────────────────────────────────

func _build_spacer(parent: Node) -> void:
	var spacer := Control.new()
	spacer.size_flags_horizontal = 3 # EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)

## ── ActionButtons ───────────────────────────────────────────

func _build_action_buttons(parent: Node) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.size_flags_vertical = 1 # SHRINK_CENTER
	box.size_flags_horizontal = 2 # SHRINK_END
	box.custom_minimum_size = Vector2(120, 0)

	# System settings button
	_make_icon_button(box, "⚙️", func(): system_settings_requested.emit())

	# Invite button
	_invite_btn = _make_icon_button(box, "🔗", func(): invite_requested.emit())

	# Leave button (danger)
	_leave_btn = _make_danger_button(box, "🚪")
	_leave_btn.custom_minimum_size = Vector2(36, 36)
	_leave_btn.pressed.connect(func(): leave_room_requested.emit())

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
		_room_name_label.text = room_config.get("name", "我的房間")
	if _player_count_label:
		var max_p = lobby_manager.max_members if lobby_manager else 4
		_player_count_label.text = "👥 %d/%d" % [players.size(), max_p]
	if _badges_container:
		_rebuild_badges(room_config)
	if _gear_btn:
		_gear_btn.visible = lobby_manager.is_host if lobby_manager else true

func set_in_room(in_room: bool) -> void:
	if _leave_btn:
		_leave_btn.visible = in_room

## ── Internal helpers ────────────────────────────────────────

func _rebuild_badges(config: Dictionary) -> void:
	for child in _badges_container.get_children():
		child.queue_free()

	var mode = config.get("mode", "")
	var map = config.get("map", "")
	var car = config.get("car_restriction", "")

	if mode != "":
		_add_badge(_badges_container, "[%s]" % mode)
	if map != "":
		_add_badge(_badges_container, "[%s]" % map)
	if car != "" and car != "all" and car != "全開放":
		_add_badge(_badges_container, "[僅 %s 級]" % car)

func _add_badge(parent: Node, text: String) -> void:
	var badge := Label.new()
	badge.text = text
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", C_ACCENT)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(badge)

func _on_copy_puid() -> void:
	var puid_text = _puid_label.tooltip_text if _puid_label else ""
	if puid_text != "":
		DisplayServer.clipboard_set(puid_text)

func _make_button(parent: Node, text: String, small: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 34) if small else Vector2(0, 36)
	b.add_theme_font_size_override("font_size", 12 if small else 12)
	b.size_flags_vertical = 1 # SHRINK_CENTER
	_apply_button_style(b, Color(0.15, 0.18, 0.22), C_TEXT)
	parent.add_child(b)
	return b

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
	b.custom_minimum_size = Vector2(0, 36)
	b.add_theme_font_size_override("font_size", 12)
	b.size_flags_vertical = 1 # SHRINK_CENTER
	_apply_button_style(b, C_DANGER_BG, C_DANGER)
	var style = b.get_theme_stylebox("normal")
	if style is StyleBoxFlat:
		style.set_border_width_all(1)
		style.border_color = C_DANGER
	parent.add_child(b)
	return b

func _apply_button_style(btn: Button, bg_color: Color, font_color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = bg_color.lightened(0.1)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = bg_color.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color.lightened(0.2))
