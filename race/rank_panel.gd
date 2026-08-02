extends PanelContainer

## 名次面板（佔位）
## 純文字列出 1. 2. 3. ...，之後再換成正式 UI。
## RaceManager 每 0.15 秒呼叫 update_entries()。

const MAX_ROWS := 12

var _row_labels: Array[Label] = []
var _rows: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "名次"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	for i in MAX_ROWS:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 20)
		_rows.add_child(label)
		_row_labels.append(label)
	vbox.add_child(_rows)

	add_child(vbox)


func update_entries(entries: Array) -> void:
	for i in _row_labels.size():
		if i < entries.size():
			var entry: Dictionary = entries[i]
			_row_labels[i].text = "%d. %s" % [i + 1, entry.get("name", "玩家")]
		else:
			_row_labels[i].text = ""


func clear_entries() -> void:
	for label in _row_labels:
		label.text = ""
