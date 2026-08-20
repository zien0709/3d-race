extends PanelContainer

const MAX_ROWS := 10

const ACCENT := Color(0.1, 0.82, 1.0)
const GOLD := Color(1.0, 0.84, 0.29)
const TEXT_MAIN := Color(0.95, 0.98, 1.0)
const TEXT_MUTED := Color(0.55, 0.66, 0.74)

var _row_labels: Array[Label] = []
var _rows: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var title := Label.new()
	title.text = "即時名次"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", ACCENT)
	vbox.add_child(title)

	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color(0.18, 0.24, 0.31, 1.0))
	vbox.add_child(separator)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	for i in MAX_ROWS:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 19)
		_rows.add_child(label)
		_row_labels.append(label)
	vbox.add_child(_rows)

	margin.add_child(vbox)
	add_child(margin)


func update_entries(entries: Array) -> void:
	for i in _row_labels.size():
		var label := _row_labels[i]
		if i < entries.size():
			var entry: Dictionary = entries[i]
			label.text = "%d. %s" % [i + 1, entry.get("name", "玩家")]
			label.add_theme_color_override("font_color", GOLD if i == 0 else TEXT_MAIN)
		else:
			label.text = ""
			label.add_theme_color_override("font_color", TEXT_MUTED)


func clear_entries() -> void:
	for label in _row_labels:
		label.text = ""


func play_intro() -> void:
	visible = true
	pivot_offset = size * 0.5
	scale = Vector2(0.8, 0.8)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func hide_panel() -> void:
	visible = false
