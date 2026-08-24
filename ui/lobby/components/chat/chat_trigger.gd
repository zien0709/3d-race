extends Button

## ChatTrigger - 開/關浮動聊天視窗的按鈕
## 注意：不能用 toggled（與 BaseButton 衝突），故用 chat_toggled。

signal chat_toggled(opened: bool)

const C_MUTED := Color(0.6, 0.65, 0.7)

var is_open: bool = false

func _ready() -> void:
	text = "💬 聊天"
	custom_minimum_size = Vector2(90, 32)
	pressed.connect(_on_pressed)
	update_style()

func _on_pressed() -> void:
	is_open = not is_open
	chat_toggled.emit(is_open)
	update_style()

func set_chat_open(open_state: bool) -> void:
	is_open = open_state
	update_style()

func update_style() -> void:
	if is_open:
		add_theme_color_override("font_color", Color(0.22, 0.74, 0.97))
	else:
		add_theme_color_override("font_color", C_MUTED)
