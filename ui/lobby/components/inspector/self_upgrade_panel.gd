extends VBoxContainer
class_name SelfUpgradePanel

## SelfUpgradePanel - 車輛升級面板
## 顯示 6 大類升級項目：引擎、變速箱、懸吊、輪胎、氮氣、空力套件

signal upgrade_requested(category: String, current_value: int)

const C_TEXT := Color(0.85, 0.88, 0.92)
const C_MUTED := Color(0.5, 0.55, 0.6)
const C_CYAN := Color(0.22, 0.74, 0.97)
const C_GREEN := Color(0.3, 0.9, 0.4)
const C_ORANGE := Color(0.95, 0.55, 0.13)
const C_BORDER := Color(0.3, 0.35, 0.4, 0.3)

@onready var engine_bar: ProgressBar = $StatsContainer/EngineRow/EngineBar
@onready var engine_value: Label = $StatsContainer/EngineRow/EngineValue
@onready var engine_upgrade_btn: Button = $StatsContainer/EngineRow/EngineUpgradeBtn
@onready var transmission_bar: ProgressBar = $StatsContainer/TransmissionRow/TransmissionBar
@onready var transmission_value: Label = $StatsContainer/TransmissionRow/TransmissionValue
@onready var transmission_upgrade_btn: Button = $StatsContainer/TransmissionRow/TransmissionUpgradeBtn
@onready var suspension_bar: ProgressBar = $StatsContainer/SuspensionRow/SuspensionBar
@onready var suspension_value: Label = $StatsContainer/SuspensionRow/SuspensionValue
@onready var suspension_upgrade_btn: Button = $StatsContainer/SuspensionRow/SuspensionUpgradeBtn
@onready var tires_bar: ProgressBar = $StatsContainer/TiresRow/TiresBar
@onready var tires_value: Label = $StatsContainer/TiresRow/TiresValue
@onready var tires_upgrade_btn: Button = $StatsContainer/TiresRow/TiresUpgradeBtn
@onready var nitro_bar: ProgressBar = $StatsContainer/NitroRow/NitroBar
@onready var nitro_value: Label = $StatsContainer/NitroRow/NitroValue
@onready var nitro_upgrade_btn: Button = $StatsContainer/NitroRow/NitroUpgradeBtn
@onready var aero_bar: ProgressBar = $StatsContainer/AeroRow/AeroBar
@onready var aero_value: Label = $StatsContainer/AeroRow/AeroValue
@onready var aero_upgrade_btn: Button = $StatsContainer/AeroRow/AeroUpgradeBtn
@onready var upgrade_selected_btn: Button = $ActionRow/UpgradeSelectedBtn
@onready var close_btn: Button = $ActionRow/CloseBtn

var _ui_animations := UIAnimations
var _selected_category: String = ""

const CATEGORIES := {
	"engine": {"bar": "engine_bar", "value": "engine_value", "btn": "engine_upgrade_btn", "color": C_CYAN, "name": "引擎"},
	"transmission": {"bar": "transmission_bar", "value": "transmission_value", "btn": "transmission_upgrade_btn", "color": C_GREEN, "name": "變速箱"},
	"suspension": {"bar": "suspension_bar", "value": "suspension_value", "btn": "suspension_upgrade_btn", "color": C_ORANGE, "name": "懸吊"},
	"tires": {"bar": "tires_bar", "value": "tires_value", "btn": "tires_upgrade_btn", "color": C_CYAN, "name": "輪胎"},
	"nitro": {"bar": "nitro_bar", "value": "nitro_value", "btn": "nitro_upgrade_btn", "color": C_GREEN, "name": "氮氣"},
	"aero": {"bar": "aero_bar", "value": "aero_value", "btn": "aero_upgrade_btn", "color": C_ORANGE, "name": "空力套件"},
}

func _ready() -> void:
	_ui_animations = UIAnimations
	_connect_upgrade_buttons()
	_style_buttons()

func _connect_upgrade_buttons() -> void:
	engine_upgrade_btn.pressed.connect(_on_category_upgrade.bind("engine"))
	transmission_upgrade_btn.pressed.connect(_on_category_upgrade.bind("transmission"))
	suspension_upgrade_btn.pressed.connect(_on_category_upgrade.bind("suspension"))
	tires_upgrade_btn.pressed.connect(_on_category_upgrade.bind("tires"))
	nitro_upgrade_btn.pressed.connect(_on_category_upgrade.bind("nitro"))
	aero_upgrade_btn.pressed.connect(_on_category_upgrade.bind("aero"))

	upgrade_selected_btn.pressed.connect(_on_upgrade_selected)
	close_btn.pressed.connect(_on_close_pressed)

func _style_buttons() -> void:
	var btns = [engine_upgrade_btn, transmission_upgrade_btn, suspension_upgrade_btn,
				 tires_upgrade_btn, nitro_upgrade_btn, aero_upgrade_btn]
	for btn in btns:
		if btn:
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.22, 0.74, 0.97, 0.2)
			style.set_corner_radius_all(6)
			style.set_border_width_all(1)
			style.border_color = C_CYAN
			style.content_margin_left = 8
			style.content_margin_right = 8
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_color_override("font_color", C_CYAN)
			
			var hover = style.duplicate()
			hover.bg_color = Color(0.22, 0.74, 0.97, 0.4)
			btn.add_theme_stylebox_override("hover", hover)
	
	# Style main buttons
	var main_style = StyleBoxFlat.new()
	main_style.bg_color = C_CYAN
	main_style.set_corner_radius_all(8)
	main_style.content_margin_left = 16
	main_style.content_margin_right = 16
	upgrade_selected_btn.add_theme_stylebox_override("normal", main_style)
	upgrade_selected_btn.add_theme_color_override("font_color", Color(0.1, 0.12, 0.16))
	
	var main_hover = main_style.duplicate()
	main_hover.bg_color = Color(0.3, 0.85, 1.0)
	upgrade_selected_btn.add_theme_stylebox_override("hover", main_hover)
	
	var close_style = main_style.duplicate()
	close_style.bg_color = Color(0.2, 0.25, 0.3)
	close_style.set_corner_radius_all(8)
	close_style.set_border_width_all(1)
	close_style.border_color = C_BORDER
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.add_theme_color_override("font_color", C_TEXT)
	
	var close_hover = close_style.duplicate()
	close_hover.bg_color = Color(0.3, 0.35, 0.4)
	close_btn.add_theme_stylebox_override("hover", close_hover)

func update_data(stats: Dictionary, car_data: Dictionary) -> void:
	# stats = {"engine": 85, "transmission": 70, "suspension": 60, "tires": 80, "nitro": 75, "aero": 65}
	for cat in CATEGORIES:
		var val = stats.get(cat, 50)
		var bar = get_node(cat + "_bar")
		var val_label = get_node(cat + "_value")
		
		if bar:
			bar.value = val
			# Color the progress bar based on category
			var fill_style = StyleBoxFlat.new()
			fill_style.bg_color = CATEGORIES[cat]["color"]
			fill_style.set_corner_radius_all(5)
			bar.add_theme_stylebox_override("fill", fill_style)
			
			var track_style = StyleBoxFlat.new()
			track_style.bg_color = Color(1, 1, 1, 0.05)
			track_style.set_corner_radius_all(5)
			bar.add_theme_stylebox_override("background", track_style)
		
		if val_label:
			val_label.text = "%d" % val
	
	# Update bar colors
	_update_bar_colors()

func _update_bar_colors() -> void:
	for cat in CATEGORIES:
		var bar = get_node(cat + "_bar")
		if bar:
			var fill_style = StyleBoxFlat.new()
			fill_style.bg_color = CATEGORIES[cat]["color"]
			fill_style.set_corner_radius_all(5)
			bar.add_theme_stylebox_override("fill", fill_style)
			
			var track_style = StyleBoxFlat.new()
			track_style.bg_color = Color(1, 1, 1, 0.05)
			track_style.set_corner_radius_all(5)
			bar.add_theme_stylebox_override("background", track_style)

func update_stat(index: int, value: float) -> void:
	var cats = ["engine", "transmission", "suspension", "tires", "nitro", "aero"]
	if index >= 0 and index < cats.size():
		var cat = cats[index]
		var bar = get_node(cat + "_bar")
		var val_label = get_node(cat + "_value")
		value = clampf(value, 0.0, 100.0)
		if bar:
			_ui_animations.animate_progress_bar(bar, value, 0.5)
		if val_label:
			val_label.text = str(int(value))

func update_stats(values: Array[float]) -> void:
	for i in range(min(values.size(), 6)):
		update_stat(i, values[i])

func _on_category_upgrade(category: String) -> void:
	_selected_category = category
	var bar = get_node(category + "_bar")
	var new_val = 0
	if bar:
		new_val = minf(bar.value + 5.0, 100.0)
		_ui_animations.animate_progress_bar(bar, new_val, 0.5)
		var val_label = get_node(category + "_value")
		if val_label:
			val_label.text = str(int(new_val))
	
	upgrade_requested.emit(category, int(new_val))
	
	# Visual feedback
	var btn = get_node(category + "_upgrade_btn")
	_ui_animations.kill_tweens(btn)
	_ui_animations.scale_pop(btn, 0.9, 0.1)

func _on_upgrade_selected() -> void:
	if _selected_category != "":
		var bar = get_node(_selected_category + "_bar")
		if bar:
			var new_val = minf(bar.value + 5.0, 100.0)
			_ui_animations.animate_progress_bar(bar, new_val, 0.5)
			var val_label = get_node(_selected_category + "_value")
			if val_label:
				val_label.text = str(int(new_val))
			upgrade_requested.emit(_selected_category, int(new_val))

func _on_close_pressed() -> void:
	# Could emit a signal to close the panel
	pass

func get_selected_category() -> String:
	return _selected_category
