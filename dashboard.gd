extends Control

@export var max_display_speed_kph: float = 160.0
@export var speed_smoothing: float = 8.0

@onready var player: VehicleBody3D = $"../../Player"
@onready var race_manager: Node = $"../../RaceManager"

var displayed_speed_kph: float = 0.0
var peak_speed_kph: float = 0.0
var forward_speed_mps: float = 0.0
var gear_text: String = "1"
var last_gear_text: String = "1"
var displayed_rpm: int = 900
var rpm_pulse_time: float = 0.0
var jitter_energy: float = 0.0

const PANEL_COLOR := Color(0.025, 0.035, 0.05, 0.9)
const PANEL_EDGE := Color(0.18, 0.24, 0.31, 0.95)
const GAUGE_DARK := Color(0.055, 0.075, 0.1, 1.0)
const GAUGE_TRACK := Color(0.18, 0.22, 0.27, 1.0)
const ACCENT := Color(0.1, 0.82, 1.0, 1.0)
const WARNING := Color(1.0, 0.27, 0.12, 1.0)
const TEXT_MAIN := Color(0.95, 0.98, 1.0, 1.0)
const TEXT_MUTED := Color(0.55, 0.66, 0.74, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(delta: float) -> void:
	visible = not bool(race_manager.get("waiting_for_player"))
	if not visible:
		return

	var target_speed_kph := player.linear_velocity.length() * 3.6
	peak_speed_kph = maxf(peak_speed_kph, target_speed_kph)
	var blend_weight := 1.0 - exp(-speed_smoothing * delta)
	displayed_speed_kph = lerpf(displayed_speed_kph, target_speed_kph, blend_weight)
	forward_speed_mps = player.linear_velocity.dot(-player.global_basis.z)
	
	var new_gear := _get_gear_text()
	if new_gear != gear_text:
		last_gear_text = gear_text
		gear_text = new_gear
		jitter_energy = 1.0

	if jitter_energy > 0.001:
		jitter_energy = lerpf(jitter_energy, 0.0, delta * 12.0)

	displayed_rpm = int(float(player.get("engine_rpm")))
	var rpm_ratio := clampf(float(displayed_rpm - 900) / 6900.0, 0.0, 1.0)
	if rpm_ratio > 0.78:
		rpm_pulse_time += delta * 18.0
	else:
		rpm_pulse_time = 0.0

	queue_redraw()


func _get_gear_text() -> String:
	if forward_speed_mps < -0.75:
		return "R"
	return str(int(player.get("current_gear")))


func _draw() -> void:
	var font := get_theme_default_font()
	var panel_rect := Rect2(Vector2.ZERO, size)
	draw_rect(panel_rect, PANEL_COLOR, true)
	draw_rect(panel_rect, PANEL_EDGE, false, 2.0)
	
	# Dynamic RPM Redline Flash Effect on top border
	var rpm_ratio := clampf(float(displayed_rpm - 900) / 6900.0, 0.0, 1.0)
	var top_bar_color := ACCENT
	if rpm_ratio > 0.78:
		var pulse := (sin(rpm_pulse_time) + 1.0) * 0.5
		top_bar_color = WARNING.lerp(Color.WHITE, pulse * 0.5)
	draw_rect(Rect2(0.0, 0.0, size.x, 4.0), top_bar_color, true)

	# Responsive scaling factors based on reference resolution 300 x 190
	var scale_x := size.x / 300.0
	var scale_y := size.y / 190.0
	var scale_min := minf(scale_x, scale_y)

	# Jitter Offset on gear shift or violent speed changes
	var jitter_offset := Vector2(
		randf_range(-2.0, 2.0) * jitter_energy * scale_min,
		randf_range(-2.0, 2.0) * jitter_energy * scale_min
	)

	var center := Vector2(100.0 * scale_x, 105.0 * scale_y) + jitter_offset
	var radius := 76.0 * scale_min
	var start_angle := deg_to_rad(135.0)
	var end_angle := deg_to_rad(405.0)
	var speed_ratio := clampf(displayed_speed_kph / max_display_speed_kph, 0.0, 1.0)
	var needle_angle := lerpf(start_angle, end_angle, speed_ratio)

	draw_circle(center, radius + (7.0 * scale_min), GAUGE_DARK)
	draw_arc(center, radius, start_angle, end_angle, 72, GAUGE_TRACK, 7.0 * scale_min, true)
	
	var active_track_color := ACCENT
	if speed_ratio > 0.85:
		active_track_color = WARNING
	draw_arc(center, radius, start_angle, needle_angle, 48, active_track_color, 7.0 * scale_min, true)

	var tick_font_size := int(round(12.0 * scale_min))
	for tick_index in range(9):
		var tick_ratio := float(tick_index) / 8.0
		var tick_angle := lerpf(start_angle, end_angle, tick_ratio)
		var direction := Vector2(cos(tick_angle), sin(tick_angle))
		var outer_point := center + direction * (69.0 * scale_min)
		var inner_point := center + direction * (59.0 * scale_min)
		draw_line(inner_point, outer_point, TEXT_MAIN, 2.0 * scale_min, true)

		var label := str(int(max_display_speed_kph * tick_ratio))
		var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tick_font_size)
		var label_position := center + direction * (48.0 * scale_min)
		label_position.x -= label_size.x * 0.5
		label_position.y += label_size.y * 0.35
		draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tick_font_size, TEXT_MUTED)

	var needle_direction := Vector2(cos(needle_angle), sin(needle_angle))
	draw_line(center, center + needle_direction * (54.0 * scale_min), WARNING, 4.0 * scale_min, true)
	draw_circle(center, 7.0 * scale_min, TEXT_MAIN)
	draw_circle(center, 3.5 * scale_min, WARNING)

	var speed_text := "%03d" % int(round(displayed_speed_kph))
	var speed_font_size := int(round(34.0 * scale_min))
	var kmh_font_size := int(round(14.0 * scale_min))
	draw_string(font, Vector2(151.0 * scale_x, 75.0 * scale_y), speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, speed_font_size, TEXT_MAIN)
	draw_string(font, Vector2(157.0 * scale_x, 96.0 * scale_y), "km/h", HORIZONTAL_ALIGNMENT_LEFT, -1.0, kmh_font_size, TEXT_MUTED)

	var title_font_size := int(round(11.0 * scale_min))
	draw_string(font, Vector2(151.0 * scale_x, 25.0 * scale_y), "AUTO 5-SPEED", HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_font_size, ACCENT)
	
	var gear_center := Vector2(185.0 * scale_x, 128.0 * scale_y) + jitter_offset
	draw_circle(gear_center, 24.0 * scale_min, GAUGE_DARK)
	var gear_font_size := int(round(30.0 * scale_min))
	var gear_size := font.get_string_size(gear_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, gear_font_size)
	var gear_color := ACCENT if gear_text != "R" else WARNING
	draw_string(
		font,
		gear_center + Vector2(-gear_size.x * 0.5, gear_size.y * 0.35),
		gear_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		gear_font_size,
		gear_color
	)

	var info_font_size := int(round(11.0 * scale_min))
	var val_font_size := int(round(15.0 * scale_min))
	draw_string(font, Vector2(224.0 * scale_x, 116.0 * scale_y), "RPM", HORIZONTAL_ALIGNMENT_LEFT, -1.0, info_font_size, TEXT_MUTED)
	draw_string(font, Vector2(224.0 * scale_x, 136.0 * scale_y), str(displayed_rpm), HORIZONTAL_ALIGNMENT_LEFT, -1.0, val_font_size, TEXT_MAIN)
	draw_string(font, Vector2(268.0 * scale_x, 116.0 * scale_y), "TOP", HORIZONTAL_ALIGNMENT_LEFT, -1.0, info_font_size, TEXT_MUTED)
	draw_string(font, Vector2(268.0 * scale_x, 136.0 * scale_y), "%03d" % int(round(peak_speed_kph)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, val_font_size, TEXT_MAIN)
	
	var bar_origin := Vector2(154.0 * scale_x, 162.0 * scale_y)
	var bar_size := Vector2(124.0 * scale_x, 8.0 * scale_y)
	draw_rect(Rect2(bar_origin, bar_size), GAUGE_TRACK, true)
	draw_rect(Rect2(bar_origin.x + bar_size.x * 0.78, bar_origin.y, bar_size.x * 0.22, bar_size.y), Color(0.6, 0.14, 0.1, 1.0), true)
	
	var bar_color := ACCENT
	if rpm_ratio >= 0.78:
		var pulse := (sin(rpm_pulse_time) + 1.0) * 0.5
		bar_color = WARNING.lerp(Color.WHITE, pulse * 0.5)
	draw_rect(Rect2(bar_origin, Vector2(bar_size.x * rpm_ratio, bar_size.y)), bar_color, true)
