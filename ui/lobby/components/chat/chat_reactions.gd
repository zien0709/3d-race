extends PanelContainer

## ChatReactions - 表情反應選擇面板
## 從訊息右鍵觸發，選擇表情加入反應

signal reaction_selected(emoji: String)
signal close_requested()

const ChatData := preload("res://ui/lobby/components/chat/chat_data.gd")

const C_BG := Color(0.12, 0.15, 0.20, 0.98)
const C_BORDER := Color(0.22, 0.74, 0.97, 0.4)
const C_ACCENT_CYAN := Color(0.22, 0.74, 0.97)

var _ui_animations: Node = null
var _target_message_id: String = ""

func _ready() -> void:
	_ui_animations = UIAnimations
	_build_ui()

func _build_ui() -> void:
	custom_minimum_size = Vector2(220, 50)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.border_color = C_BORDER
	sb.set_content_margin_all(6)
	sb.shadow_color = Color(0.22, 0.74, 0.97, 0.2)
	sb.shadow_size = 6
	add_theme_stylebox_override("panel", sb)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)

	for emoji in ChatData.REACTION_EMOJIS:
		var btn := Button.new()
		btn.text = emoji
		btn.flat = true
		btn.custom_minimum_size = Vector2(40, 40)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(func(): reaction_selected.emit(emoji))
		btn.mouse_entered.connect(func():
			if _ui_animations: _ui_animations.scale_to(btn, 1.15, 0.1)
		)
		btn.mouse_exited.connect(func():
			if _ui_animations: _ui_animations.scale_to(btn, 1.0, 0.1)
		)
		grid.add_child(btn)

func set_target_message(message_id: String) -> void:
	_target_message_id = message_id

func get_target_message() -> String:
	return _target_message_id
