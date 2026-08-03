extends Control

@export var max_display_speed_kph: float = 160.0
@export var speed_smoothing: float = 8.0

@onready var player: VehicleBody3D = $"../../Player"
@onready var race_manager: Node = $"../../RaceManager"

var displayed_speed_kph: float = 0.0
var peak_speed_kph: float = 0.0
var forward_speed_mps: float = 0.0
var gear_text: String = "1"
var displayed_rpm: int = 900

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
	gear_text = _get_gear_text()

	displayed_rpm = int(float(player.get("engine_rpm")))
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
	draw_rect(Rect2(0.0, 0.0, size.x, 4.0), ACCENT, true)

	var center := Vector2(100.0, 105.0)
	var radius := 76.0
	var start_angle := deg_to_rad(135.0)
	var end_angle := deg_to_rad(405.0)
	var speed_ratio := clampf(displayed_speed_kph / max_display_speed_kph, 0.0, 1.0)
	var needle_angle := lerpf(start_angle, end_angle, speed_ratio)

	draw_circle(center, radius + 7.0, GAUGE_DARK)
	draw_arc(center, radius, start_angle, end_angle, 72, GAUGE_TRACK, 7.0, true)
	draw_arc(center, radius, start_angle, needle_angle, 48, ACCENT, 7.0, true)

	for tick_index in range(9):
		var tick_ratio := float(tick_index) / 8.0
		var tick_angle := lerpf(start_angle, end_angle, tick_ratio)
		var direction := Vector2(cos(tick_angle), sin(tick_angle))
		var outer_point := center + direction * 69.0
		var inner_point := center + direction * 59.0
		draw_line(inner_point, outer_point, TEXT_MAIN, 2.0, true)

		var label := str(int(max_display_speed_kph * tick_ratio))
		var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12)
		var label_position := center + direction * 48.0
		label_position.x -= label_size.x * 0.5
		label_position.y += label_size.y * 0.35
		draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, TEXT_MUTED)

	var needle_direction := Vector2(cos(needle_angle), sin(needle_angle))
	draw_line(center, center + needle_direction * 54.0, WARNING, 4.0, true)
	draw_circle(center, 7.0, TEXT_MAIN)
	draw_circle(center, 3.5, WARNING)

	var speed_text := "%03d" % int(round(displayed_speed_kph))
	draw_string(font, Vector2(151.0, 75.0), speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 34, TEXT_MAIN)
	draw_string(font, Vector2(157.0, 96.0), "km/h", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, TEXT_MUTED)

	draw_string(font, Vector2(151.0, 25.0), "AUTO 5-SPEED", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, ACCENT)
	draw_circle(Vector2(185.0, 128.0), 24.0, GAUGE_DARK)
	var gear_size := font.get_string_size(gear_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30)
	draw_string(
		font,
		Vector2(185.0 - gear_size.x * 0.5, 128.0 + gear_size.y * 0.35),
		gear_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		30,
		ACCENT if gear_text != "R" else WARNING
	)

	draw_string(font, Vector2(224.0, 116.0), "RPM", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, TEXT_MUTED)
	draw_string(font, Vector2(224.0, 136.0), str(displayed_rpm), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, TEXT_MAIN)
	draw_string(font, Vector2(268.0, 116.0), "TOP", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, TEXT_MUTED)
	draw_string(font, Vector2(268.0, 136.0), "%03d" % int(round(peak_speed_kph)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, TEXT_MAIN)
	var rpm_ratio := clampf(float(displayed_rpm - 900) / 6900.0, 0.0, 1.0)
	var bar_origin := Vector2(154.0, 162.0)
	var bar_size := Vector2(124.0, 8.0)
	draw_rect(Rect2(bar_origin, bar_size), GAUGE_TRACK, true)
	draw_rect(Rect2(bar_origin.x + bar_size.x * 0.78, bar_origin.y, bar_size.x * 0.22, bar_size.y), Color(0.6, 0.14, 0.1, 1.0), true)
	draw_rect(Rect2(bar_origin, Vector2(bar_size.x * rpm_ratio, bar_size.y)), ACCENT if rpm_ratio < 0.78 else WARNING, true)
