extends HBoxContainer

## MatchDots - 近 5 場勝敗圓點

const C_WIN := Color(0.062, 0.724, 0.508)
const C_LOSE := Color(0.95, 0.3, 0.3)

var _dots: Array = []

func _ready() -> void:
	add_theme_constant_override("separation", 5)
	for i in 5:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(10, 10)
		add_child(dot)
		_dots.append(dot)
	update_dots([])

func update_dots(results: Array) -> void:
	for i in _dots.size():
		var win: bool = bool(results[i]) if i < results.size() else false
		var sb := StyleBoxFlat.new()
		sb.bg_color = C_WIN if win else C_LOSE
		sb.set_corner_radius_all(5)
		_dots[i].add_theme_stylebox_override("panel", sb)
