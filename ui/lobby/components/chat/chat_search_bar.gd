extends HBoxContainer

## ChatSearchBar - 訊息搜尋列
## 從 Tab 列的 🔍 按鈕展開，即時搜尋並高亮匹配

signal search_changed(query: String)
signal search_closed()

const C_TEXT := Color(0.90, 0.92, 0.95)
const C_TEXT_MUTED := Color(0.40, 0.45, 0.50)
const C_ACCENT_CYAN := Color(0.22, 0.74, 0.97)

var _line_edit: LineEdit
var _count_label: Label
var _close_btn: Button
var _match_count: int = 0
var _ui_animations: Node = null

func _ready() -> void:
	_ui_animations = UIAnimations
	_build_ui()

func _build_ui() -> void:
	add_theme_constant_override("separation", 6)
	custom_minimum_size = Vector2(0, 40)

	# Search icon
	var icon := Label.new()
	icon.text = "🔍"
	icon.add_theme_font_size_override("font_size", 14)
	icon.add_theme_color_override("font_color", C_ACCENT_CYAN)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)

	# Input
	_line_edit = LineEdit.new()
	_line_edit.placeholder_text = "搜尋訊息…"
	_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line_edit.custom_minimum_size = Vector2(0, 32)
	_line_edit.text_changed.connect(_on_text_changed)
	_line_edit.text_submitted.connect(func(_t): pass)
	add_child(_line_edit)

	# Match count
	_count_label = Label.new()
	_count_label.text = ""
	_count_label.add_theme_font_size_override("font_size", 11)
	_count_label.add_theme_color_override("font_color", C_TEXT_MUTED)
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count_label)

	# Close
	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.flat = true
	_close_btn.custom_minimum_size = Vector2(24, 24)
	_close_btn.add_theme_font_size_override("font_size", 12)
	_close_btn.add_theme_color_override("font_color", C_TEXT_MUTED)
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
	if count == 0:
		_count_label.text = ""
	else:
		_count_label.text = "%d 筆" % count

func focus_input() -> void:
	if _line_edit != null:
		_line_edit.grab_focus()

func get_query() -> String:
	return _line_edit.text
