extends PanelContainer

## RoomCard - 房間資訊卡（header 中間，點擊建立房間 / 齒輪修改設定）

signal settings_requested()
signal create_room_requested()

const C_ACCENT := Color(0.22, 0.74, 0.97)
const C_MUTED := Color(0.6, 0.65, 0.7)
@onready var _ui_animations := UIAnimations

var _room_name_label: Label
var _player_count_label: Label
var _settings_btn: Button

func _ready() -> void:
	custom_minimum_size = Vector2(280, 46)
	mouse_filter = Control.MOUSE_FILTER_PASS

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 12
	hbox.offset_right = -8
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(hbox)

	var icon := Label.new()
	icon.text = "🏠"
	icon.add_theme_font_size_override("font_size", 18)
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(icon)

	_room_name_label = Label.new()
	_room_name_label.text = "未在房間中"
	_room_name_label.add_theme_font_size_override("font_size", 15)
	_room_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_room_name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(_room_name_label)

	_player_count_label = Label.new()
	_player_count_label.text = ""
	_player_count_label.add_theme_font_size_override("font_size", 13)
	_player_count_label.add_theme_color_override("font_color", C_MUTED)
	_player_count_label.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(_player_count_label)

	var btn := Button.new()
	btn.text = "⚙"
	btn.flat = true
	btn.custom_minimum_size = Vector2(32, 32)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(settings_requested.emit)
	btn.mouse_entered.connect(func(): _ui_animations.kill_tweens(btn); _ui_animations.scale_to(btn, 1.05, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT))
	btn.mouse_exited.connect(func(): _ui_animations.kill_tweens(btn); _ui_animations.scale_to(btn, 1.0, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT))
	btn.button_down.connect(func(): _ui_animations.kill_tweens(btn); _ui_animations.scale_to(btn, 0.95, 0.07, Tween.TRANS_SINE, Tween.EASE_OUT))
	btn.button_up.connect(func(): _ui_animations.kill_tweens(btn); _ui_animations.scale_to(btn, 1.05, 0.12, Tween.TRANS_SINE, Tween.EASE_OUT))
	_settings_btn = btn
	hbox.add_child(btn)

func update_display(room_config: Dictionary, players: Array, lobby_manager: Object) -> void:
	var in_lobby: bool = lobby_manager != null and not lobby_manager.current_lobby.is_empty()

	if in_lobby:
		_room_name_label.text = str(lobby_manager.lobby_attr("room_name", "", null))
		_room_name_label.tooltip_text = "點擊齒輪修改房間設定"
		var max_m: int = lobby_manager.max_members if lobby_manager.max_members > 0 else int(room_config.get("max_players", 4))
		_player_count_label.text = "%d/%d" % [players.size(), max_m]
	else:
		_room_name_label.text = str(room_config.get("name", ""))
		_room_name_label.tooltip_text = "點擊卡片建立房間"
		var max_p: int = int(room_config.get("max_players", 0))
		if max_p <= 0:
			max_p = 4
		_player_count_label.text = "%d/%d" % [players.size(), max_p]

	if in_lobby:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		create_room_requested.emit()
