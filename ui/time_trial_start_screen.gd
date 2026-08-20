extends Control

signal start_requested(player_name: String)

@onready var login_button: Button = $MainCard/TabHeader/LoginButton
@onready var register_button: Button = $MainCard/TabHeader/RegisterButton
@onready var play_button: Button = $MainCard/TabHeader/PlayButton
@onready var name_input: LineEdit = $MainCard/ContentArea/Margin/ContentStack/PlayPage/PlayCenter/ContentVBox/NameInput
@onready var start_button: Button = $MainCard/ContentArea/Margin/ContentStack/PlayPage/PlayCenter/ContentVBox/Footer/StartButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	name_input.text_submitted.connect(_on_start_pressed)

	setup_button_animations(login_button)
	setup_button_animations(register_button)
	setup_button_animations(play_button)
	setup_button_animations(start_button)


func _on_start_pressed(_text: String = "") -> void:
	start_requested.emit(name_input.text.strip_edges())


func clear_name() -> void:
	name_input.text = ""


func show_for_waiting() -> void:
	visible = true
	modulate.a = 1.0
	name_input.call_deferred("grab_focus")


func hide_for_race() -> void:
	pivot_offset = size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", position.y - 40.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		visible = false
		modulate.a = 1.0
		position.y += 40.0
	)


func show_name_error(message: String) -> void:
	name_input.placeholder_text = message
	name_input.grab_focus()


func setup_button_animations(btn: Button) -> void:
	if not btn:
		return
	btn.pivot_offset = btn.size * 0.5
	if not btn.resized.is_connected(_on_btn_resized.bind(btn)):
		btn.resized.connect(_on_btn_resized.bind(btn))
	btn.mouse_entered.connect(_on_btn_mouse_entered.bind(btn))
	btn.mouse_exited.connect(_on_btn_mouse_exited.bind(btn))
	btn.button_down.connect(_on_btn_button_down.bind(btn))
	btn.button_up.connect(_on_btn_button_up.bind(btn))


func _on_btn_resized(btn: Button) -> void:
	btn.pivot_offset = btn.size * 0.5


func _on_btn_mouse_entered(btn: Button) -> void:
	if btn.disabled:
		return
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_btn_mouse_exited(btn: Button) -> void:
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_btn_button_down(btn: Button) -> void:
	if btn.disabled:
		return
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_btn_button_up(btn: Button) -> void:
	var target_scale := Vector2(1.05, 1.05) if btn.is_hovered() else Vector2.ONE
	var tw := create_tween()
	tw.tween_property(btn, "scale", target_scale, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)