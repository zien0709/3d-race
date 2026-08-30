extends HBoxContainer

## ChatTabs - 現代化 Ribbon 風格分頁列（Office 風格）
## 特點：漸層背景、發光下劃線、動態 hover、未讀 Badge、震動提示

signal tab_selected(tab_id: String)
signal search_button_pressed()

const C_TEXT := Color(0.85, 0.88, 0.92)
const C_TEXT_MUTED := Color(0.50, 0.55, 0.60)
const C_ACCENT_CYAN := Color(0.22, 0.74, 0.97)
const C_ACCENT_RED := Color(0.95, 0.30, 0.35)
const C_BG_RIBBON := Color(0.08, 0.10, 0.14, 0.95)
const C_HOVER_GLOW := Color(0.22, 0.74, 0.97, 0.15)

const TAB_DEFS := [
	["room", "🏠", "房間"],
	["team", "👥", "隊伍"],
	["global", "🌍", "世界"],
	["system", "⚙️", "系統"],
]

var _tab_buttons: Dictionary = {}
var _tab_badges: Dictionary = {}
var _tab_underlines: Dictionary = {}
var _active_tab: String = "room"
var _unread_counts: Dictionary = {}
var _ui_animations: Node = null
var _ribbon_style: StyleBoxFlat

func _ready() -> void:
	_ui_animations = UIAnimations
	_build_ui()

func _build_ui() -> void:
	# Ribbon 背景樣式
	_ribbon_style = StyleBoxFlat.new()
	_ribbon_style.bg_color = C_BG_RIBBON
	_ribbon_style.set_corner_radius_all(8)
	_ribbon_style.set_content_margin_all(4)
	add_theme_stylebox_override("panel", _ribbon_style)

	add_theme_constant_override("separation", 2)
	custom_minimum_size = Vector2(0, 44)

	# Tab 容器
	var tab_container := HBoxContainer.new()
	tab_container.add_theme_constant_override("separation", 0)
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(tab_container)

	for def in TAB_DEFS:
		var tab_id: String = str(def[0])
		var icon: String = str(def[1])
		var label: String = str(def[2])

		# Tab 按鈕容器（含下劃線）
		var tab_wrap := VBoxContainer.new()
		tab_wrap.add_theme_constant_override("separation", 0)
		tab_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_container.add_child(tab_wrap)

		var btn := Button.new()
		btn.flat = true
		btn.custom_minimum_size = Vector2(56, 32)
		btn.add_theme_font_size_override("font_size", 12)
		btn.text = "%s %s" % [icon, label]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func(): _on_tab_pressed(tab_id))
		btn.mouse_entered.connect(_on_tab_hover.bind(true, btn))
		btn.mouse_exited.connect(_on_tab_hover.bind(false, btn))

		# 按鈕背景透明
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color.TRANSPARENT
		btn_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", btn_style)

		var btn_hover := btn_style.duplicate()
		btn_hover.bg_color = C_HOVER_GLOW
		btn.add_theme_stylebox_override("hover", btn_hover)

		var btn_pressed := btn_style.duplicate()
		btn_pressed.bg_color = Color(0.22, 0.74, 0.97, 0.2)
		btn.add_theme_stylebox_override("pressed", btn_pressed)

		tab_wrap.add_child(btn)
		_tab_buttons[tab_id] = btn
		_unread_counts[tab_id] = 0

		# 發光下劃線（選中時顯示）
		var underline := ColorRect.new()
		underline.color = C_ACCENT_CYAN
		underline.custom_minimum_size = Vector2(0, 3)
		underline.visible = (tab_id == _active_tab)
		underline.modulate.a = 0.0 if tab_id != _active_tab else 1.0
		tab_wrap.add_child(underline)
		_tab_underlines[tab_id] = underline

		# Unread badge（覆蓋在按鈕右上角）
		var badge := _create_badge()
		btn.add_child(badge)
		_tab_badges[tab_id] = badge

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(spacer)

	# Search 按鈕
	var search_btn := Button.new()
	search_btn.text = "🔍"
	search_btn.flat = true
	search_btn.custom_minimum_size = Vector2(32, 32)
	search_btn.add_theme_font_size_override("font_size", 14)
	search_btn.pressed.connect(func(): search_button_pressed.emit())
	search_btn.mouse_entered.connect(func():
		if _ui_animations: _ui_animations.scale_to(search_btn, 1.1, 0.1)
	)
	search_btn.mouse_exited.connect(func():
		if _ui_animations: _ui_animations.scale_to(search_btn, 1.0, 0.1)
	)
	add_child(search_btn)

func _create_badge() -> Label:
	var badge := Label.new()
	badge.text = ""
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_right = -4
	badge.offset_top = 2
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := StyleBoxFlat.new()
	bg.set_corner_radius_all(7)
	bg.bg_color = C_ACCENT_RED
	bg.content_margin_left = 3
	bg.content_margin_right = 3
	bg.content_margin_top = 1
	bg.content_margin_bottom = 1
	badge.add_theme_stylebox_override("normal", bg)
	return badge

func _on_tab_pressed(tab_id: String) -> void:
	set_active_tab(tab_id)
	tab_selected.emit(tab_id)

func _on_tab_hover(_entered: bool, btn: Button) -> void:
	if _ui_animations:
		_ui_animations.scale_to(btn, 1.03 if _entered else 1.0, 0.1)

func set_active_tab(tab_id: String) -> void:
	_active_tab = tab_id
	_clear_unread(tab_id)
	for id in _tab_buttons:
		var btn: Button = _tab_buttons[id]
		var underline: ColorRect = _tab_underlines[id]
		var on: bool = id == tab_id

		if on:
			btn.add_theme_color_override("font_color", C_ACCENT_CYAN)
			# 下劃線淡入動畫
			var tween := create_tween()
			tween.tween_property(underline, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE)
			underline.visible = true
		else:
			btn.add_theme_color_override("font_color", C_TEXT_MUTED)
			# 下劃線淡出動畫
			var tween := create_tween()
			tween.tween_property(underline, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
			tween.tween_callback(func(): underline.visible = false)

func get_active_tab() -> String:
	return _active_tab

func add_unread(tab_id: String) -> void:
	if tab_id == _active_tab:
		return
	if not _unread_counts.has(tab_id):
		_unread_counts[tab_id] = 0
	_unread_counts[tab_id] += 1
	_update_badge(tab_id)
	_vibrate_tab(tab_id)

func _update_badge(tab_id: String) -> void:
	var badge: Label = _tab_badges.get(tab_id)
	if badge == null:
		return
	var count: int = _unread_counts.get(tab_id, 0)
	if count > 0:
		badge.text = str(count) if count < 100 else "99+"
		badge.visible = true
	else:
		badge.visible = false

func _clear_unread(tab_id: String) -> void:
	_unread_counts[tab_id] = 0
	_update_badge(tab_id)

func _vibrate_tab(tab_id: String) -> void:
	var btn: Button = _tab_buttons.get(tab_id)
	if btn == null or _ui_animations == null:
		return
	var base_pos := btn.position
	var tween := create_tween().set_parallel(false)
	for i in range(3):
		tween.tween_property(btn, "position", base_pos + Vector2(0.5, 0), 0.05)
		tween.tween_property(btn, "position", base_pos - Vector2(0.5, 0), 0.05)
	tween.tween_property(btn, "position", base_pos, 0.05)
