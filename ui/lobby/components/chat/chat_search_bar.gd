extends HBoxContainer

## ChatSearchBar - 訊息搜尋列
## 從 Tab 列的 🔍 按鈕展開，即時搜尋並高亮匹配

signal search_changed(query: String)
signal search_closed()

const C_TEXT := Color(0.90, 0.92, 0.95)
const C_TEXT_MUTED := Color(0.40, 0.45, 0.50)
const C_ACCENT_CYAN := Color(0.22, 0.74, 0.97)
const C_ICON_GRAY := Color(0.6, 0.6, 0.6)
const C_FIELD_BG := Color(0, 0, 0, 0.3)
const C_FIELD_BG_FOCUS := Color(0, 0, 0, 0.45)

var _line_edit: LineEdit
var _close_btn: Button
var _match_count: int = 0
var _ui_animations: Node = null

func _ready() -> void:
	_ui_animations = UIAnimations
	_build_ui()

func _build_ui() -> void:
	add_theme_constant_override("separation", 6)
	custom_minimum_size = Vector2(0, 28)

	# Search icon (pure decoration, gray)
	var icon := Label.new()
	icon.text = "🔍"
	icon.add_theme_font_size_override("font_size", 14)
	icon.add_theme_color_override("font_color", C_ICON_GRAY)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)

	# Input: borderless dark translucent field; focus only brightens bg.
	# NOTE: never set vertical_alignment on LineEdit (no such property).
	_line_edit = LineEdit.new()
	_line_edit.placeholder_text = "搜尋訊息…"
	_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_line_edit.custom_minimum_size = Vector2(0, 28)
	_line_edit.add_theme_font_size_override("font_size", 14)
	_line_edit.add_theme_color_override("font_color", C_TEXT)
	_line_edit.add_theme_color_override("font_placeholder_color", C_TEXT_MUTED)
	var field_normal := StyleBoxFlat.new()
	field_normal.bg_color = C_FIELD_BG
	field_normal.set_corner_radius_all(6)
	field_normal.set_border_width_all(0)
	field_normal.content_margin_left = 8.0
	field_normal.content_margin_right = 8.0
	field_normal.content_margin_top = 2.0
	field_normal.content_margin_bottom = 2.0
	_line_edit.add_theme_stylebox_override("normal", field_normal)
	var field_focus := StyleBoxFlat.new()
	field_focus.bg_color = C_FIELD_BG_FOCUS
	field_focus.set_corner_radius_all(6)
	field_focus.set_border_width_all(0)
	field_focus.content_margin_left = 8.0
	field_focus.content_margin_right = 8.0
	field_focus.content_margin_top = 2.0
	field_focus.content_margin_bottom = 2.0
	_line_edit.add_theme_stylebox_override("focus", field_focus)
	_line_edit.text_changed.connect(_on_text_changed)
	_line_edit.text_submitted.connect(func(_t): pass)
	add_child(_line_edit)

	# Close
	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.flat = true
	_close_btn.custom_minimum_size = Vector2(24, 24)
	_close_btn.add_theme_font_size_override("font_size", 12)
	_close_btn.add_theme_color_override("font_color", C_TEXT_MUTED)
	_close_btn.tooltip_text = "清除搜尋"
	_close_btn.pressed.connect(func(): search_closed.emit())
	_close_btn.mouse_entered.connect(func():
		if _ui_animations: _ui_animations.scale_to(_close_btn, 1.1, 0.1)
	)
	_close_btn.mouse_exited.connect(func():
		if _ui_animations: _ui_animations.scale_to(_close_btn, 1.0, 0.1)
	)
	add_child(_close_btn)

func _on_text_changed(text: String) -> void:
	search_changed.emit(text)

func set_match_count(count: int) -> void:
	_match_count = count
	if _close_btn == null:
		return
	if count == 0:
		_close_btn.tooltip_text = "清除搜尋"
	else:
		_close_btn.tooltip_text = "清除搜尋（%d 筆符合）" % count

func focus_input() -> void:
	if _line_edit != null:
		_line_edit.call_deferred("grab_focus")

func release_search_focus() -> void:
	if _line_edit != null:
		_line_edit.release_focus()

func clear_query() -> void:
	if _line_edit != null:
		# NOTE: programmatic clear() does not emit text_changed;
		# the panel resets the query explicitly on close.
		_line_edit.clear()

func get_query() -> String:
	return _line_edit.text
