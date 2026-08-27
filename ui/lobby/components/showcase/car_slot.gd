extends PanelContainer

## CarSlot - 車位卡（顯示玩家車輛、就緒狀態；點擊選擇／再點改裝）

signal slot_clicked(is_self: bool)

const C_MUTED := Color(0.6, 0.65, 0.7)
const C_ACCENT := Color(0.22, 0.74, 0.97)
const C_SELF := Color(0.062, 0.724, 0.508)
const C_BORDER := Color(0.545, 0.608, 0.706, 0.18)

@onready var _ui_animations := UIAnimations

var player_data: Dictionary = {}
var is_selected: bool = false

var _car_label: Label
var _player_name_label: Label
var _ready_indicator: Label
var _select_button: Button
var _style_box: StyleBoxFlat
var _car_emoji: Label

func _ready() -> void:
	custom_minimum_size = Vector2(240, 300)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var car_display := PanelContainer.new()
	car_display.custom_minimum_size = Vector2(0, 150)
	_style_panel(car_display, Color(1, 1, 1, 0.03))
	var center := CenterContainer.new()
	car_display.add_child(center)
	var car_box := VBoxContainer.new()
	center.add_child(car_box)
	
	# 空位用灰色虛線車輛剪影，非空位用 emoji
	_car_emoji = Label.new()
	_car_emoji.text = "🏎"
	_car_emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_car_emoji.add_theme_font_size_override("font_size", 56)
	_car_emoji.visible = false
	car_box.add_child(_car_emoji)
	
	_car_label = Label.new()
	_car_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_car_label.add_theme_font_size_override("font_size", 13)
	_car_label.add_theme_color_override("font_color", C_MUTED)
	car_box.add_child(_car_label)
	vbox.add_child(car_display)
	
	_player_name_label = Label.new()
	_player_name_label.text = "空位"
	_player_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_player_name_label)

	_ready_indicator = Label.new()
	_ready_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ready_indicator.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_ready_indicator)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	_select_button = Button.new()
	_select_button.custom_minimum_size = Vector2(0, 32)
	_select_button.disabled = true
	_select_button.pressed.connect(func(): slot_clicked.emit(bool(player_data.get("is_self", false))))
	_select_button.mouse_entered.connect(_on_button_mouse_entered)
	_select_button.mouse_exited.connect(_on_button_mouse_exited)
	_select_button.button_down.connect(_on_button_down)
	_select_button.button_up.connect(_on_button_up)
	vbox.add_child(_select_button)

	set_empty()

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
	if _car_emoji != null:
		_car_emoji.visible = true
	_refresh_style()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(bool(player_data.get("is_self", false)))

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
	if _car_emoji != null:
		_car_emoji.visible = false
	_refresh_style()

func _refresh_style() -> void:
	var bg := Color(1, 1, 1, 0.04) if is_selected else Color(1, 1, 1, 0.02)
	var border := C_ACCENT if is_selected else C_BORDER
	
	if _style_box == null:
		_style_panel(self, bg, border)
	else:
		_style_box.bg_color = bg
		_animate_border_color(border)
	
	if is_selected:
		_ui_animations.kill_tweens(self)
		_ui_animations.scale_pop(self, 1.02, 0.15)
	else:
		_ui_animations.kill_tweens(self)
		_ui_animations.scale_release(self, 0.15)

func _on_button_mouse_entered() -> void:
	if _select_button.disabled:
		_ui_animations.kill_tweens(_select_button)
		var tween := create_tween()
		tween.tween_property(_select_button, "scale", Vector2(1.02, 1.02), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_button_mouse_exited() -> void:
	if _select_button.disabled:
		_ui_animations.kill_tweens(_select_button)
		_ui_animations.scale_release(_select_button, 0.12)

func _on_button_down() -> void:
	if _select_button.disabled:
		_ui_animations.kill_tweens(_select_button)
		_ui_animations.scale_press(_select_button, 0.96, 0.08)

func _on_button_up() -> void:
	if _select_button.disabled:
		_ui_animations.kill_tweens(_select_button)
		_ui_animations.scale_pop(_select_button, 1.02, 0.12)

func _animate_border_color(target_color: Color) -> void:
	if _style_box == null:
		return
	var tween := create_tween()
	tween.tween_property(_style_box, "border_color", target_color, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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
	_style_box = sb

func _draw() -> void:
	# Only draw silhouette for empty slots
	if not player_data.is_empty():
		return
	
	var rect = get_rect()
	var center_x = rect.size.x / 2
	var center_y = rect.size.y / 2
	var w = 60.0
	var h = 30.0
	
	var color = Color(0.5, 0.55, 0.6, 0.35)  # 灰色半透明
	var dash = 8.0
	var gap = 4.0
	
	# 車身輪廓
	var body_rect = Rect2(center_x - w/2, center_y - h/2, w, h)
	_draw_dashed_rect(body_rect, color, dash, gap)
	
	# 車頂
	var roof_w = w * 0.5
	var roof_h = h * 0.35
	var roof_rect = Rect2(center_x - roof_w/2, center_y - h/2 - roof_h, roof_w, roof_h)
	_draw_dashed_rect(roof_rect, color, dash, gap)
	
	# 輪子（兩個圓）
	var wheel_r = h * 0.15
	var wheel_y = center_y + h/2 - wheel_r
	var wheel_x_offset = w * 0.3
	_draw_dashed_circle(Vector2(center_x - wheel_x_offset, wheel_y), wheel_r, color, dash, gap)
	_draw_dashed_circle(Vector2(center_x + wheel_x_offset, wheel_y), wheel_r, color, dash, gap)
	
	# 加號（邀請圖示）
	var plus_size = 16
	_draw_dashed_plus(Vector2(center_x, center_y), plus_size, color, dash, gap)

func _draw_dashed_rect(rect: Rect2, color: Color, dash: float, gap: float) -> void:
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	
	# 上邊
	_draw_dashed_line(Vector2(x, y), Vector2(x + w, y), color, dash, gap)
	# 右邊
	_draw_dashed_line(Vector2(x + w, y), Vector2(x + w, y + h), color, dash, gap)
	# 下邊
	_draw_dashed_line(Vector2(x + w, y + h), Vector2(x, y + h), color, dash, gap)
	# 左邊
	_draw_dashed_line(Vector2(x, y + h), Vector2(x, y), color, dash, gap)

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, dash: float, gap: float) -> void:
	var dir: Vector2 = (to - from).normalized()
	var len: float = from.distance_to(to)
	var pos: float = 0.0
	var on: bool = true
	while pos < len:
		var seg_len: float = min(dash if on else gap, len - pos)
		var start: Vector2 = from + dir * pos
		var end: Vector2 = from + dir * (pos + seg_len)
		if on:
			draw_line(start, end, color, 2.0)
		pos += seg_len
		on = not on

func _draw_dashed_circle(center: Vector2, radius: float, color: Color, dash: float, gap: float) -> void:
	var circum: float = 2 * PI * radius
	var steps: int = max(12, int(circum / (dash + gap)))
	var angle_step: float = TAU / steps
	var on: bool = true
	for i in range(steps):
		var a1: float = i * angle_step
		var a2: float = a1 + angle_step
		var seg_angle: float = angle_step
		if on:
			var arc_len: float = radius * seg_angle
			if arc_len > dash:
				# Split into dash/gap
				var sub_steps: int = max(1, int(arc_len / (dash + gap)))
				for j in range(sub_steps):
					var sub_a1: float = a1 + (a2 - a1) * j / sub_steps
					var sub_a2: float = a1 + (a2 - a1) * (j + 0.5) / sub_steps
					draw_line(
						center + Vector2(cos(sub_a1), sin(sub_a1)) * radius,
						center + Vector2(cos(sub_a2), sin(sub_a2)) * radius,
						color, 2.0
					)
			else:
				draw_line(
					center + Vector2(cos(a1), sin(a1)) * radius,
					center + Vector2(cos(a2), sin(a2)) * radius,
					color, 2.0
				)
		on = not on

func _draw_dashed_plus(center: Vector2, size: float, color: Color, dash: float, gap: float) -> void:
	var half: float = size / 2
	_draw_dashed_line(Vector2(center.x, center.y - half), Vector2(center.x, center.y + half), color, dash, gap)
	_draw_dashed_line(Vector2(center.x - half, center.y), Vector2(center.x + half, center.y), color, dash, gap)
