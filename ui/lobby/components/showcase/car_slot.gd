extends PanelContainer

## CarSlot - 車位卡（顯示玩家車輛、就緒狀態；點擊選擇／再點改裝）

signal slot_clicked(is_self: bool)

const C_MUTED := Color(0.6, 0.65, 0.7)
const C_ACCENT := Color(0.22, 0.74, 0.97)
const C_SELF := Color(0.062, 0.724, 0.508)
const C_BORDER := Color(0.545, 0.608, 0.706, 0.18)

var player_data: Dictionary = {}
var is_selected: bool = false

var _car_label: Label
var _player_name_label: Label
var _ready_indicator: Label
var _select_button: Button

func _ready() -> void:
	custom_minimum_size = Vector2(240, 300)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_constant_override("separation", 10)

	var car_display := PanelContainer.new()
	car_display.custom_minimum_size = Vector2(0, 150)
	_style_panel(car_display, Color(1, 1, 1, 0.03))
	var center := CenterContainer.new()
	car_display.add_child(center)
	var car_box := VBoxContainer.new()
	center.add_child(car_box)
	var emoji := Label.new()
	emoji.text = "🏎"
	emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji.add_theme_font_size_override("font_size", 56)
	car_box.add_child(emoji)
	_car_label = Label.new()
	_car_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_car_label.add_theme_font_size_override("font_size", 13)
	_car_label.add_theme_color_override("font_color", C_MUTED)
	car_box.add_child(_car_label)
	add_child(car_display)

	_player_name_label = Label.new()
	_player_name_label.text = "空位"
	_player_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_name_label.add_theme_font_size_override("font_size", 16)
	add_child(_player_name_label)

	_ready_indicator = Label.new()
	_ready_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ready_indicator.add_theme_font_size_override("font_size", 12)
	add_child(_ready_indicator)

	_select_button = Button.new()
	_select_button.custom_minimum_size = Vector2(0, 32)
	_select_button.disabled = true
	_select_button.pressed.connect(func(): slot_clicked.emit(bool(player_data.get("is_self", false))))
	add_child(_select_button)

	set_empty()

func set_empty() -> void:
	if _select_button == null:
		return
	player_data = {}
	is_selected = false
	_car_label.text = ""
	_player_name_label.text = "空位"
	_ready_indicator.text = ""
	_select_button.text = "等待玩家…"
	_select_button.disabled = true
	_refresh_style()

func update_player(p: Dictionary, selected: bool) -> void:
	if _select_button == null:
		return
	player_data = p
	is_selected = selected
	_car_label.text = str(p.get("car_name", ""))
	_player_name_label.text = str(p.get("name", "玩家"))
	var ready_state: bool = bool(p.get("ready", false))
	_ready_indicator.text = "✔ 已準備" if ready_state else "⏳ 未準備"
	_ready_indicator.add_theme_color_override("font_color", C_SELF if ready_state else C_MUTED)
	var is_self: bool = bool(p.get("is_self", false))
	if is_self and selected:
		_select_button.text = "🔧 改裝車輛"
	else:
		_select_button.text = "選擇"
	_select_button.disabled = false
	_refresh_style()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(bool(player_data.get("is_self", false)))

func _refresh_style() -> void:
	var bg := Color(1, 1, 1, 0.04) if is_selected else Color(1, 1, 1, 0.02)
	var border := C_ACCENT if is_selected else C_BORDER
	_style_panel(self, bg, border)

func _style_panel(panel: PanelContainer, bg: Color, border: Color = C_BORDER) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
