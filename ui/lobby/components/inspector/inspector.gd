extends PanelContainer

## Inspector - 左側車輛／玩家資訊面板
## 自建子節點，場景只需掛一個空的 PanelContainer 加此腳本。

signal customize_requested()

const StatBarScript := preload("res://ui/lobby/components/inspector/stat_bar.gd")
const MatchDotsScript := preload("res://ui/lobby/components/inspector/match_dots.gd")

const C_TEXT := Color(0.85, 0.88, 0.92)
const C_MUTED := Color(0.5, 0.55, 0.6)
const C_ACCENT := Color(0.3, 0.85, 0.95)
const C_SELF := Color(0.3, 0.9, 0.4)
const C_ORANGE := Color(0.95, 0.55, 0.13)
const C_BORDER := Color(0.3, 0.35, 0.4, 0.3)

var _title_label: Label
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
	custom_minimum_size = Vector2(300, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	style.set_border_width_all(1)
	style.border_color = C_BORDER
	add_theme_stylebox_override("panel", style)

	_build_ui()
	update_player({})

func update_player(p: Dictionary) -> void:
	if _car_name_label == null:
		return
	if p.is_empty():
		_title_label.text = "車輛資料"
		_car_name_label.text = "尚未選擇玩家"
		_score_label.text = "-"
		_class_label.text = "-"
		_rank_value.text = "-"
		_best_lap_value.text = "--:--.---"
		_match_dots.update_dots([])
		_speed_bar.set_value(0, C_ACCENT)
		_handling_bar.set_value(0, C_SELF)
		_accel_bar.set_value(0, C_ORANGE)
		return

	var player_name = str(p.get("name", "Player"))
	_title_label.text = "%s 的車輛資料" % player_name
	_car_name_label.text = str(p.get("car_name", "Default Car"))
	_score_label.text = str(p.get("score", 0))
	_class_label.text = str(p.get("cls", "A"))
	_rank_value.text = str(p.get("rank", "--"))
	_best_lap_value.text = str(p.get("best_lap", "--:--.---"))
	var matches: Array = p.get("matches", [])
	_match_dots.update_dots(matches)
	var stats: Dictionary = p.get("stats", {})
	_speed_bar.set_value(float(stats.get("speed", 0.5)) * 100.0, C_ACCENT)
	_handling_bar.set_value(float(stats.get("handling", 0.5)) * 100.0, C_SELF)
	_accel_bar.set_value(float(stats.get("accel", 0.5)) * 100.0, C_ORANGE)

## --- UI building ---

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "車輛資料"
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(_title_label)

	# Car name
	_car_name_label = Label.new()
	_car_name_label.text = "Default Car"
	_car_name_label.add_theme_font_size_override("font_size", 20)
	_car_name_label.add_theme_color_override("font_color", C_TEXT)
	vbox.add_child(_car_name_label)

	# Score / Class row
	var score_row := HBoxContainer.new()
	score_row.add_theme_constant_override("separation", 16)
	vbox.add_child(score_row)
	score_row.add_child(_stat_box("SCORE", true))
	score_row.add_child(_stat_box("CLASS", false))

	_divider(vbox)

	# Rank / Best lap
	_info_row(vbox, "排名", true)
	_info_row(vbox, "最佳單圈", false)

	_divider(vbox)

	# Recent matches
	var dots_lbl := Label.new()
	dots_lbl.text = "近期比賽"
	dots_lbl.add_theme_font_size_override("font_size", 11)
	dots_lbl.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(dots_lbl)
	_match_dots = HBoxContainer.new()
	_match_dots.set_script(MatchDotsScript)
	vbox.add_child(_match_dots)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	_divider(vbox)

	# Stat bars
	_stat_row(vbox, "極速", true)
	_stat_row(vbox, "操控", false)
	_stat_row(vbox, "加速", false)

	# Garage button
	var garage_btn := Button.new()
	garage_btn.text = "🏎️ 進入車庫（換車 / 改裝）"
	garage_btn.custom_minimum_size = Vector2(0, 40)
	garage_btn.add_theme_font_size_override("font_size", 13)
	garage_btn.pressed.connect(func(): customize_requested.emit())

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.5, 0.6)
	btn_style.set_corner_radius_all(8)
	btn_style.set_content_margin_all(8)
	garage_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.25, 0.55, 0.65)
	garage_btn.add_theme_stylebox_override("hover", btn_hover)

	garage_btn.add_theme_color_override("font_color", C_TEXT)
	vbox.add_child(garage_btn)

func _stat_box(label_text: String, is_score: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", C_MUTED)
	box.add_child(lbl)
	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.add_theme_color_override("font_color", C_ACCENT if is_score else C_TEXT)
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
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", C_MUTED)
	row.add_child(lbl)
	var value_label := Label.new()
	value_label.text = "-"
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", C_TEXT)
	row.add_child(value_label)
	if is_rank:
		_rank_value = value_label
	else:
		_best_lap_value = value_label

func _stat_row(parent: VBoxContainer, stat_text: String, is_speed: bool) -> void:
	var bar := HBoxContainer.new()
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
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	parent.add_child(sep)
