extends Control

## CustomizeView - 車輛改裝全屏視圖（佔滿大廳，含返回鈕）
## 自建子節點，場景只需掛一個空的 Control 加此腳本。

@onready var _ui_animations := UIAnimations

signal back_requested()

const C_MUTED := Color(0.6, 0.65, 0.7)
const C_ACCENT := Color(0.22, 0.74, 0.97)
const C_SELF := Color(0.062, 0.724, 0.508)
const C_BORDER := Color(0.545, 0.608, 0.706, 0.18)

const TUNING_CATEGORIES := [
	["引擎", 62], ["變速箱", 55], ["懸吊", 48],
	["輪胎", 51], ["氮氣", 70], ["空力套件", 44],
]

var _bars: Array = []

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#0f172a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_ui()

func open() -> void:
	_ui_animations.kill_tweens(self)
	z_index = 10
	_ui_animations.panel_open(self, 0.25)

func close() -> void:
	_ui_animations.kill_tweens(self)
	var tween := _ui_animations.panel_close(self, 0.2)
	await tween.finished
	visible = false
	z_index = 0

## --- UI building ---

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)

	var back_btn := Button.new()
	back_btn.text = "← 返回"
	back_btn.custom_minimum_size = Vector2(90, 34)
	back_btn.add_theme_font_size_override("font_size", 14)
	back_btn.pressed.connect(func(): back_requested.emit())
	header.add_child(back_btn)

	var title := Label.new()
	title.text = "車輛改裝"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)

	## 預覽區（佔位：之後接 3D 車輛預覽）
	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(1, 1, 1, 0.02)
	psb.set_border_width_all(1)
	psb.border_color = C_BORDER
	psb.set_corner_radius_all(12)
	preview_panel.add_theme_stylebox_override("panel", psb)
	var preview_label := Label.new()
	preview_label.text = "車輛預覽（開發中）"
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_label.add_theme_color_override("font_color", C_MUTED)
	preview_panel.add_child(preview_label)
	vbox.add_child(preview_panel)

	## 改裝項目列
	var tuning_title := Label.new()
	tuning_title.text = "改裝等級"
	tuning_title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(tuning_title)

	for cat in TUNING_CATEGORIES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var lbl := Label.new()
		lbl.text = str(cat[0])
		lbl.custom_minimum_size = Vector2(90, 0)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", C_MUTED)
		row.add_child(lbl)
		var bar := ProgressBar.new()
		bar.max_value = 100
		bar.value = int(cat[1])
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := StyleBoxFlat.new()
		fill.bg_color = C_ACCENT
		fill.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("fill", fill)
		var track := StyleBoxFlat.new()
		track.bg_color = Color(1, 1, 1, 0.05)
		track.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("background", track)
		row.add_child(bar)
		var val := Label.new()
		val.text = "%d" % int(cat[1])
		val.custom_minimum_size = Vector2(36, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.add_theme_font_size_override("font_size", 13)
		row.add_child(val)
		vbox.add_child(row)
		_bars.append({"bar": bar, "label": val})

	## 底部動作
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 12)
	var upgrade_btn := Button.new()
	upgrade_btn.text = "⬆ 升級選中零件"
	upgrade_btn.custom_minimum_size = Vector2(150, 36)
	upgrade_btn.add_theme_font_size_override("font_size", 14)
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	actions.add_child(upgrade_btn)
	vbox.add_child(actions)

func _on_upgrade_pressed() -> void:
	if _bars.is_empty():
		return
	var entry: Dictionary = _bars[0]
	var new_value := minf(entry["bar"].value + 5.0, 100.0)
	_ui_animations.animate_progress_bar(entry["bar"], new_value, 0.5)
	entry["label"].text = str(int(new_value))

func update_stat(index: int, value: float) -> void:
	if index < 0 or index >= _bars.size():
		return
	var entry: Dictionary = _bars[index]
	value = clampf(value, 0.0, 100.0)
	_ui_animations.animate_progress_bar(entry["bar"], value, 0.5)
	entry["label"].text = str(int(value))

func update_stats(values: Array[float]) -> void:
	for i in range(min(values.size(), _bars.size())):
		update_stat(i, values[i])
