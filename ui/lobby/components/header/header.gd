extends PanelContainer

## Header - 頂部列：玩家卡 + 房間卡 + 動作按鈕
## 自建子節點，場景只需掛一個空的 PanelContainer 加此腳本。

signal room_settings_requested()
signal create_room_requested()
signal leave_room_requested()
signal leave_lobby_requested()
signal browser_requested()

const UserCardScript := preload("res://ui/lobby/components/header/user_card.gd")
const RoomCardScript := preload("res://ui/lobby/components/header/room_card.gd")

const C_MUTED := Color(0.6, 0.65, 0.7)

var user_card: Control
var room_card: Control
var settings_button: Button

func _ready() -> void:
	custom_minimum_size = Vector2(0, 56)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	user_card = Button.new()
	user_card.set_script(UserCardScript)
	row.add_child(user_card)

	room_card = PanelContainer.new()
	room_card.set_script(RoomCardScript)
	room_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(room_card)
	room_card.settings_requested.connect(func(): room_settings_requested.emit())
	room_card.create_room_requested.connect(func(): create_room_requested.emit())

	settings_button = _make_action_button(row, "🔍 搜尋房間", browser_requested)
	_make_action_button(row, "🚪 離開房間", leave_room_requested)
	_make_action_button(row, "✖ 離開大廳", leave_lobby_requested)

func update_user_card(display_name: String, lobby_manager: Object) -> void:
	if user_card != null and user_card.has_method("update_display"):
		user_card.update_display(display_name, lobby_manager)

func update_room_card(room_config: Dictionary, players: Array, lobby_manager: Object) -> void:
	if room_card != null and room_card.has_method("update_display"):
		room_card.update_display(room_config, players, lobby_manager)

func _make_action_button(parent: Node, label_text: String, target_signal: Signal) -> Button:
	var b := Button.new()
	b.text = label_text
	b.custom_minimum_size = Vector2(110, 36)
	b.add_theme_font_size_override("font_size", 13)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): target_signal.emit())
	parent.add_child(b)
	return b
