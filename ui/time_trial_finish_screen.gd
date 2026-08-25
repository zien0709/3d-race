extends CenterContainer

signal next_player_requested
signal home_requested

@onready var final_time_label: Label = $FinishPanel/VBoxContainer/FinalTimeLabel
@onready var new_record_label: Label = $FinishPanel/VBoxContainer/NewRecordLabel
@onready var next_player_button: Button = %NextPlayerButton
@onready var home_button: Button = %HomeButton

var _final_time_tween: Tween
var _record_pulse_tween: Tween

func _ready() -> void:
	next_player_button.pressed.connect(func(): next_player_requested.emit())
	home_button.pressed.connect(func(): home_requested.emit())
	setup_button_animations(next_player_button)
	setup_button_animations(home_button)

func show_results(final_time: float, is_new_record: bool) -> void:
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.7, 0.7)
	pivot_offset = size * 0.5

	var pop_tw := create_tween().set_parallel(true)
	pop_tw.tween_property(self, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pop_tw.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Count-up timer animation
	if _final_time_tween and _final_time_tween.is_valid():
		_final_time_tween.kill()
	_final_time_tween = create_tween()
	_final_time_tween.tween_method(func(val: float): final_time_label.text = "成績：%.2f 秒" % val, 0.0, final_time, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if is_new_record:
		new_record_label.visible = true
		new_record_label.pivot_offset = new_record_label.get_minimum_size() * 0.5
		if _record_pulse_tween and _record_pulse_tween.is_valid():
			_record_pulse_tween.kill()
		_record_pulse_tween = create_tween().set_loops()
		_record_pulse_tween.tween_property(new_record_label, "scale", Vector2(1.15, 1.15), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_record_pulse_tween.tween_property(new_record_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		new_record_label.visible = false

func hide_results() -> void:
	visible = false
	new_record_label.visible = false
	if _final_time_tween and _final_time_tween.is_valid():
		_final_time_tween.kill()
	if _record_pulse_tween and _record_pulse_tween.is_valid():
		_record_pulse_tween.kill()

# 多人模式：顯示最終排名
func show_results_multiplayer(ordered: Array) -> void:
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.7, 0.7)
	pivot_offset = size * 0.5

	var pop_tw := create_tween().set_parallel(true)
	pop_tw.tween_property(self, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pop_tw.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var my_rank := -1
	for i in ordered.size():
		if ordered[i].get("car_id", -1) == my_id:
			my_rank = i + 1
			break

	if my_rank > 0:
		final_time_label.text = "你第 %d 名 / 共 %d 人" % [my_rank, ordered.size()]
	else:
		final_time_label.text = "比賽結束"

	# 列出完整排名
	var lines: Array[String] = []
	for i in ordered.size():
		var e: Dictionary = ordered[i]
		lines.append("%d. %s" % [i + 1, e.get("name", "玩家")])
	new_record_label.visible = true
	new_record_label.text = "\n".join(lines)


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
