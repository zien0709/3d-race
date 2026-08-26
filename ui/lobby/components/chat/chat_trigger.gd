extends Button

## ChatTrigger - 開/關浮動聊天視窗的按鈕
## 注意：不能用 toggled（與 BaseButton 衝突），故用 chat_toggled。

signal chat_toggled(opened: bool)

const C_MUTED := Color(0.6, 0.65, 0.7)

@onready var _ui_animations := UIAnimations

var is_open: bool = false
var _is_hovered: bool = false

func _ready() -> void:
	text = "💬 聊天"
	custom_minimum_size = Vector2(90, 32)
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	update_style()

func _on_mouse_entered() -> void:
	_is_hovered = true
	_ui_animations.kill_tweens(self)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.02, 1.02), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	_is_hovered = false
	_ui_animations.kill_tweens(self)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_ui_animations.kill_tweens(self)
			var tween := create_tween()
			tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			_ui_animations.kill_tweens(self)
			var target_scale := Vector2(1.02, 1.02) if _is_hovered else Vector2.ONE
			var tween := create_tween()
			tween.tween_property(self, "scale", target_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_pressed() -> void:
	is_open = not is_open
	chat_toggled.emit(is_open)
	update_style()

func set_chat_open(open_state: bool) -> void:
	is_open = open_state
	update_style()
	if open_state:
		_ui_animations.kill_tweens(self)
		var tween := create_tween().set_parallel(false)
		tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2(1.02, 1.02) if _is_hovered else Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func update_style() -> void:
	if is_open:
		add_theme_color_override("font_color", Color(0.22, 0.74, 0.97))
	else:
		add_theme_color_override("font_color", C_MUTED)
