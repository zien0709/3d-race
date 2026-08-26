extends HBoxContainer

## StatBar - 車輛性能條（標籤 + 進度條）

const C_MUTED := Color(0.6, 0.65, 0.7)
@onready var _ui_animations := UIAnimations

var _name_label: Label
var _progress_bar: ProgressBar

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	custom_minimum_size = Vector2(0, 18)
	_name_label = Label.new()
	_name_label.text = "極速"
	_name_label.custom_minimum_size = Vector2(48, 0)
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_color", C_MUTED)
	add_child(_name_label)
	_progress_bar = ProgressBar.new()
	_progress_bar.max_value = 100
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0, 6)
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.05)
	track.set_corner_radius_all(3)
	_progress_bar.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.22, 0.74, 0.97)
	fill.set_corner_radius_all(3)
	_progress_bar.add_theme_stylebox_override("fill", fill)
	add_child(_progress_bar)

func set_stat_name(text: String) -> void:
	if _name_label != null:
		_name_label.text = text

func set_value(value: float, color: Color) -> void:
	if _progress_bar == null:
		return
	_ui_animations.animate_progress_bar(_progress_bar, value, 0.5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	_progress_bar.add_theme_stylebox_override("fill", fill)
