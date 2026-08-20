extends CenterContainer

@onready var label: Label = $CountdownLabel

var _last_countdown_text: String = ""
var _countdown_tween: Tween

func _ready() -> void:
	label.text = ""

func set_text(text: String, color: Color) -> void:
	label.text = text
	label.modulate = color
	if text.is_empty():
		return
	if text == _last_countdown_text:
		return
	_last_countdown_text = text
	if _countdown_tween and _countdown_tween.is_valid():
		_countdown_tween.kill()
	label.pivot_offset = label.get_minimum_size() * 0.5
	_countdown_tween = create_tween()
	_countdown_tween.tween_property(
		label, "scale", Vector2.ONE, 0.35
	).from(Vector2(0.45, 0.45)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func reset() -> void:
	label.text = "3"
	label.scale = Vector2.ONE
	label.modulate = Color.WHITE
	_last_countdown_text = ""

func clear() -> void:
	label.text = ""
	label.scale = Vector2.ONE
	label.modulate = Color.WHITE
	_last_countdown_text = ""
