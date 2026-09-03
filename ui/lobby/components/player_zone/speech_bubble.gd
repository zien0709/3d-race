extends PanelContainer
class_name SpeechBubble

## SpeechBubble - Floating message bubble for player chat
## Appears above/below car model with tail pointing to source

@onready var _label: Label = $Label
@onready var _tail: Polygon2D = $Tail

var _tween: Tween
var _auto_hide_timer: float = 3.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	
	# Setup style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	style.set_corner_radius_all(12)
	style.set_border_width_all(1)
	style.border_color = Color(0.22, 0.74, 0.97, 0.7)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.22, 0.74, 0.97, 0.15)
	style.shadow_size = 4
	add_theme_stylebox_override("panel", style)
	
	# Setup label
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	_label.custom_minimum_size = Vector2(120, 0)
	_label.max_width = 280

	# Setup tail (triangle pointing down by default)
	_update_tail(Vector2.DOWN)

func _update_tail(direction: Vector2) -> void:
	var points: Array[Vector2] = []
	var tail_size = 16.0
	var tail_height = 12.0
	
	if direction == Vector2.DOWN:
		# Tail pointing down (bubble above model)
		points = [
			Vector2(-tail_size * 0.5, 0),
			Vector2(tail_size * 0.5, 0),
			Vector2(0, tail_height)
		]
		_tail.position = Vector2(0, 0)
	elif direction == Vector2.UP:
		# Tail pointing up (bubble below model)
		points = [
			Vector2(-tail_size * 0.5, 0),
			Vector2(tail_size * 0.5, 0),
			Vector2(0, -tail_height)
		]
		_tail.position = Vector2(0, 0)
	elif direction == Vector2.LEFT:
		# Tail pointing left (bubble right of model)
		points = [
			Vector2(0, -tail_size * 0.5),
			Vector2(0, tail_size * 0.5),
			Vector2(tail_height, 0)
		]
		_tail.position = Vector2(0, 0)
	elif direction == Vector2.RIGHT:
		# Tail pointing right (bubble left of model)
		points = [
			Vector2(0, -tail_size * 0.5),
			Vector2(0, tail_size * 0.5),
			Vector2(-tail_height, 0)
		]
		_tail.position = Vector2(0, 0)
	
	_tail.polygon = points
	
	# Style tail to match bubble
	var tail_style = StyleBoxFlat.new()
	tail_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	_tail.add_theme_stylebox_override("panel", tail_style)

func show_message(text: String, duration: float = 3.0, direction: Vector2 = Vector2.DOWN) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	
	_label.text = text
	_auto_hide_timer = duration
	_update_tail(direction)
	
	visible = true
	modulate.a = 0.0
	
	# Animate in
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(duration)
	_tween.tween_property(self, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): visible = false)

func hide_immediately() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	visible = false
	modulate.a = 0.0
