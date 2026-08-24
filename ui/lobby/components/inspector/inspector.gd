extends PanelContainer

## Inspector - 左側車輛／玩家資訊面板
## 自建子節點，場景只需掛一個空的 PanelContainer 加此腳本。

signal customize_requested()

const StatBarScript := preload("res://ui/lobby/components/inspector/stat_bar.gd")
const MatchDotsScript := preload("res://ui/lobby/components/inspector/match_dots.gd")

const C_MUTED := Color(0.6, 0.65, 0.7)
const C_ACCENT := Color(0.22, 0.74, 0.97)
const C_SELF := Color(0.062, 0.724, 0.508)
const C_BORDER := Color(0.545, 0.608, 0.706, 0.18)

var _car_name_label: Label
var _score_label: Label
var _class_label: Label
var _rank_value: Label
var _best_lap_value: Label
var _match_dots: Control
var _speed_bar: Control
var _handling_bar: Control
var _accel_bar: Control

func _ready() -> void:
	custom_minimum_size = Vector2(260, 0)
	_build_ui()
	update_player({})

func update_player(p: Dictionary) -> void:
	if _car_name_label == null:
		return
	if p.is_empty():
		_car_name_label.text = "尚未選擇玩家"
		_score_label.text = "-"
		_class_label.text = "-"
		_rank_value.text = "-"
		_best_lap_value.text = "-"
		_match_dots.update_dots([])
		return

	_car_name_label.text = str(p.get("car_name", "Default Car"))
	_score_label.text = str(p.get("score", 0))
	_class_label.text = str(p.get("cls", "S"))
	_rank_value.text = str(p.get("rank", "新手"))
	_best_lap_value.text = str(p.get("best_lap", "--:--.---"))
	var matches: Array = p.get("matches", [])
	_match_dots.update_dots(matches)
	var stats: Dictionary = p.get("stats", {})
	_speed_bar.set_value(float(stats.get("speed", 0.5)) * 100.0, C_ACCENT)
	_handling_bar.set_value(float(stats.get("handling", 0.5)) * 100.0, C_SELF)
	_accel_bar.set_value(float(stats.get("accel", 0.5)) * 100.0, Color(0.95, 0.55, 0.13))

## --- UI building ---

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var title := Label.new()
	title.text = "車輛資料"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	_car_name_label = Label.new()
	_car_name_label.text = "Default Car"
	_car_name_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_car_name_label)

	## 分數 / 等級列
	var score_row := HBoxContainer.new()
	score_row.add_theme_constant_override("separation", 12)
	vbox.add_child(score_row)
	score_row.add_child(_stat_box("SCORE", true))
	score_row.add_child(_stat_box("CLASS", false))

	_divider(vbox)

	## 排名 / 最佳單圈
	_info_row(vbox, "排名", true)
	_info_row(vbox, "最佳單圈", false)

	_divider(vbox)

	var dots_lbl := Label.new()
	dots_lbl.text = "近期比賽"
	dots_lbl.add_theme_font_size_override("font_size", 12)
	dots_lbl.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(dots_lbl)
	_match_dots = PanelContainer.new()
	_match_dots.set_script(MatchDotsScript)
	vbox.add_child(_match_dots)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	_divider(vbox)

	_stat_row(vbox, "極速", true)
	_stat_row(vbox, "操控", false)
	_stat_row(vbox, "加速", false)

	var customize_btn := Button.new()
	customize_btn.text = "🔧 前往改裝"
	customize_btn.custom_minimum_size = Vector2(0, 36)
	customize_btn.add_theme_font_size_override("font_size", 14)
	customize_btn.pressed.connect(func(): customize_requested.emit())
	vbox.add_child(customize_btn)

func _stat_box(label_text: String, is_score: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", C_MUTED)
	box.add_child(lbl)
	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 20)
	value_label.add_theme_color_override("font_color", C_ACCENT if is_score else Color(1, 1, 1))
	box.add_child(value_label)
	if is_score:
		_score_label = value_label
	else:
		_class_label = value_label
	return box

func _info_row(parent: VBoxContainer, label_text: String, is_rank: bool) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", C_MUTED)
	row.add_child(lbl)
	var value_label := Label.new()
	value_label.text = "-"
	value_label.add_theme_font_size_override("font_size", 13)
	row.add_child(value_label)
	if is_rank:
		_rank_value = value_label
	else:
		_best_lap_value = value_label

func _stat_row(parent: VBoxContainer, stat_text: String, is_speed: bool) -> void:
	var bar := PanelContainer.new()
	bar.set_script(StatBarScript)
	parent.add_child(bar)
	bar.set_stat_name(stat_text)
	if is_speed:
		_speed_bar = bar
	elif stat_text == "操控":
		_handling_bar = bar
	else:
		_accel_bar = bar

func _divider(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())
