extends PanelContainer

## CarSlot - 車位卡（2D 車輛展示、Active Glow、皇冠、Speech Bubble、空位剪影）

signal slot_clicked(is_self: bool)

const C_TEXT := Color(0.85, 0.88, 0.92)
const C_MUTED := Color(0.5, 0.55, 0.6)
const C_CYAN := Color(0.3, 0.85, 0.95)
const C_GREEN := Color(0.3, 0.9, 0.4)
const C_GOLD := Color(1.0, 0.84, 0.0)
const C_BORDER := Color(0.3, 0.35, 0.4, 0.3)
const C_EMPTY := Color(0.4, 0.45, 0.5, 0.5)

@onready var _ui_animations := UIAnimations

var player_data: Dictionary = {}
var is_selected: bool = false
var is_host: bool = false

var _car_texture_rect: TextureRect
var _glow_rect: ColorRect
var _car_label: Label
var _player_name_label: Label
var _crown_label: Label
var _status_label: Label
var _speech_bubble: PanelContainer
var _bubble_label: Label
var _bubble_tween: Tween
var _style_box: StyleBoxFlat
var _placeholder_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(240, 280)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Main panel style
	_style_box = StyleBoxFlat.new()
	_style_box.bg_color = Color(0.1, 0.12, 0.16)
	_style_box.set_corner_radius_all(10)
	_style_box.set_content_margin_all(12)
	_style_box.set_border_width_all(1)
	_style_box.border_color = C_BORDER
	add_theme_stylebox_override("panel", _style_box)

	# Build main content vbox first
	var vbox := VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# === Speech Bubble (added to self, positioned at top via anchors) ===
	_build_speech_bubble()

	# === 2D Car display area ===
	var car_area := CenterContainer.new()
	car_area.custom_minimum_size = Vector2(0, 140)
	vbox.add_child(car_area)

	# Glow底盘 (radial glow beneath car)
	_glow_rect = ColorRect.new()
	_glow_rect.custom_minimum_size = Vector2(200, 40)
	_glow_rect.color = Color(0.3, 0.85, 0.95, 0.08)
	_glow_rect.visible = false
	car_area.add_child(_glow_rect)

	# TextureRect for car illustration (replaces emoji)
	_car_texture_rect = TextureRect.new()
	_car_texture_rect.custom_minimum_size = Vector2(240, 120)
	_car_texture_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	_car_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_car_texture_rect.visible = false
	car_area.add_child(_car_texture_rect)

	# Placeholder emoji (shown when no texture set)
	_placeholder_label = Label.new()
	_placeholder_label.text = "🏎️"
	_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder_label.add_theme_font_size_override("font_size", 56)
	car_area.add_child(_placeholder_label)

	# Car name label
	_car_label = Label.new()
	_car_label.text = ""
	_car_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_car_label.add_theme_font_size_override("font_size", 12)
	_car_label.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(_car_label)

	# Player name + crown row (centered)
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 4)
	vbox.add_child(name_row)

	_crown_label = Label.new()
	_crown_label.text = "👑"
	_crown_label.add_theme_font_size_override("font_size", 14)
	_crown_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_crown_label.visible = false
	name_row.add_child(_crown_label)

	_player_name_label = Label.new()
	_player_name_label.text = "空位"
	_player_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_player_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_name_label.add_theme_font_size_override("font_size", 16)
	_player_name_label.add_theme_color_override("font_color", C_TEXT)
	name_row.add_child(_player_name_label)

	# Status label (JOINED / READY)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_status_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	set_empty()

## ── Speech Bubble ─────────────────────────────────────────────

func _build_speech_bubble() -> void:
	_speech_bubble = PanelContainer.new()
	_speech_bubble.name = "SpeechBubble"
	_speech_bubble.visible = false
	_speech_bubble.modulate.a = 0.0
	# Position at top-center of card using anchors
	_speech_bubble.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_speech_bubble.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_speech_bubble.offset_top = -8
	_speech_bubble.offset_bottom = 30
	_speech_bubble.offset_left = -60
	_speech_bubble.offset_right = 60

	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.1, 0.13, 0.18)
	bubble_style.set_corner_radius_all(10)
	bubble_style.set_border_width_all(1)
	bubble_style.border_color = Color(0.3, 0.85, 0.95, 0.7)
	bubble_style.content_margin_left = 10
	bubble_style.content_margin_right = 10
	bubble_style.content_margin_top = 5
	bubble_style.content_margin_bottom = 5
	bubble_style.shadow_color = Color(0.3, 0.85, 0.95, 0.15)
	bubble_style.shadow_size = 4
	_speech_bubble.add_theme_stylebox_override("panel", bubble_style)

	_bubble_label = Label.new()
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.add_theme_font_size_override("font_size", 11)
	_bubble_label.add_theme_color_override("font_color", C_TEXT)
	_bubble_label.custom_minimum_size = Vector2(120, 0)
	_speech_bubble.add_child(_bubble_label)

	add_child(_speech_bubble)

func show_speech_bubble(text: String, duration: float = 3.0) -> void:
	if _speech_bubble == null:
		return
	if _bubble_tween and _bubble_tween.is_valid():
		_bubble_tween.kill()

	_bubble_label.text = text
	_speech_bubble.visible = true
	_speech_bubble.modulate.a = 0.0

	# Tween: fade in
	_bubble_tween = create_tween()
	_bubble_tween.tween_property(_speech_bubble, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# After duration, fade out
	_bubble_tween.tween_interval(duration)
	_bubble_tween.tween_property(_speech_bubble, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_bubble_tween.tween_callback(func(): _speech_bubble.visible = false)

## ── Public API ────────────────────────────────────────────────

func update_player(p: Dictionary, selected: bool, host: bool = false) -> void:
	if _player_name_label == null:
		return
	player_data = p
	is_selected = selected
	is_host = host

	_car_label.text = str(p.get("car_name", ""))
	_player_name_label.text = str(p.get("name", "玩家"))
	_crown_label.visible = host

	var ready_state: bool = bool(p.get("ready", false))
	if ready_state:
		_status_label.text = "JOINED  ●  READY"
		_status_label.add_theme_color_override("font_color", C_GREEN)
	else:
		_status_label.text = "JOINED"
		_status_label.add_theme_color_override("font_color", C_MUTED)

	_placeholder_label.visible = true
	_car_texture_rect.visible = false
	_glow_rect.visible = true
	_refresh_style()

func set_car_texture(tex: Texture2D) -> void:
	if tex != null:
		_car_texture_rect.texture = tex
		_car_texture_rect.visible = true
		_placeholder_label.visible = false
		_glow_rect.visible = true
	else:
		_car_texture_rect.visible = false
		_placeholder_label.visible = true

func set_empty() -> void:
	if _player_name_label == null:
		return
	player_data = {}
	is_selected = false
	is_host = false
	_car_label.text = "+ 邀請玩家 / 開放加入"
	_player_name_label.text = "空位"
	_crown_label.visible = false
	_status_label.text = "等待玩家..."
	_status_label.add_theme_color_override("font_color", C_EMPTY)
	_placeholder_label.visible = false
	_car_texture_rect.visible = false
	_glow_rect.visible = false
	_refresh_style()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(bool(player_data.get("is_self", false)))

func _refresh_style() -> void:
	if is_selected:
		_style_box.border_color = C_CYAN
		_style_box.set_border_width_all(2)
		_style_box.set_shadow_size(6)
		_style_box.shadow_color = Color(0.3, 0.85, 0.95, 0.3)
		_ui_animations.kill_tweens(self)
		_ui_animations.scale_pop(self, 1.02, 0.15)
		if _glow_rect.visible:
			_glow_rect.color = Color(0.3, 0.85, 0.95, 0.15)
	elif player_data.is_empty():
		_style_box.border_color = Color(0.3, 0.35, 0.4, 0.2)
		_style_box.set_border_width_all(1)
		_style_box.set_shadow_size(0)
		_ui_animations.kill_tweens(self)
		_ui_animations.scale_release(self, 0.15)
	else:
		_style_box.border_color = C_BORDER
		_style_box.set_border_width_all(1)
		_style_box.set_shadow_size(0)
		_ui_animations.kill_tweens(self)
		_ui_animations.scale_release(self, 0.15)
		if _glow_rect.visible:
			_glow_rect.color = Color(0.3, 0.85, 0.95, 0.08)

## ── Empty slot dashed silhouette ──────────────────────────────

func _draw() -> void:
	if not player_data.is_empty():
		return

	var rect = get_rect()
	var cx = rect.size.x / 2
	var cy = rect.size.y / 2 - 10
	var w = 60.0
	var h = 30.0
	var color = Color(0.5, 0.55, 0.6, 0.3)
	var dash = 8.0
	var gap = 4.0

	_draw_dashed_rect(Rect2(cx - w/2, cy - h/2, w, h), color, dash, gap)
	var roof_w = w * 0.5
	var roof_h = h * 0.35
	_draw_dashed_rect(Rect2(cx - roof_w/2, cy - h/2 - roof_h, roof_w, roof_h), color, dash, gap)
	var wheel_r = h * 0.15
	var wheel_y = cy + h/2 - wheel_r
	var wheel_x_off = w * 0.3
	_draw_dashed_circle(Vector2(cx - wheel_x_off, wheel_y), wheel_r, color, dash, gap)
	_draw_dashed_circle(Vector2(cx + wheel_x_off, wheel_y), wheel_r, color, dash, gap)
	_draw_dashed_plus(Vector2(cx, cy), 16, color, dash, gap)

func _draw_dashed_rect(rect: Rect2, color: Color, dash: float, gap: float) -> void:
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	_draw_dashed_line(Vector2(x, y), Vector2(x + w, y), color, dash, gap)
	_draw_dashed_line(Vector2(x + w, y), Vector2(x + w, y + h), color, dash, gap)
	_draw_dashed_line(Vector2(x + w, y + h), Vector2(x, y + h), color, dash, gap)
	_draw_dashed_line(Vector2(x, y + h), Vector2(x, y), color, dash, gap)

func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, dash: float, gap: float) -> void:
	var dir: Vector2 = (to - from).normalized()
	var length: float = from.distance_to(to)
	var pos: float = 0.0
	var on: bool = true
	while pos < length:
		var seg_len: float = min(dash if on else gap, length - pos)
		var s: Vector2 = from + dir * pos
		var e: Vector2 = from + dir * (pos + seg_len)
		if on:
			draw_line(s, e, color, 2.0)
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
		if on:
			var arc_len: float = radius * angle_step
			if arc_len > dash:
				var sub_steps: int = max(1, int(arc_len / (dash + gap)))
				for j in range(sub_steps):
					var sub_a1: float = a1 + (a2 - a1) * j / sub_steps
					var sub_a2: float = a1 + (a2 - a1) * (j + 0.5) / sub_steps
					draw_line(
						center + Vector2(cos(sub_a1), sin(sub_a1)) * radius,
						center + Vector2(cos(sub_a2), sin(sub_a2)) * radius,
						color, 2.0)
			else:
				draw_line(
					center + Vector2(cos(a1), sin(a1)) * radius,
					center + Vector2(cos(a2), sin(a2)) * radius,
					color, 2.0)
		on = not on

func _draw_dashed_plus(center: Vector2, size: float, color: Color, dash: float, gap: float) -> void:
	var half: float = size / 2
	_draw_dashed_line(Vector2(center.x, center.y - half), Vector2(center.x, center.y + half), color, dash, gap)
	_draw_dashed_line(Vector2(center.x - half, center.y), Vector2(center.x + half, center.y), color, dash, gap)
