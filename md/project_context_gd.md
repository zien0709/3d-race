# [Z 3D Race] Project Context File: .gd

## res://

**EnvironmentManager.gd**
```gdscript
extends Node

## EnvironmentManager.gd
## Central singleton managing all global environmental variables for the race game.
## Authoritative source for:
## - Weather system (rain/snow intensity)
## - Time of day
## - Wind direction and speed
## - Game state synchronization
##
## For future multiplayer: clients will RPC sync just the floating-point values
## (weather_intensity, time_of_day, wind_dir, wind_speed) from the server.
## All other logic (particles, car physics, shaders) updates locally based on these values.

signal environment_ready
signal weather_changed(old_intensity: float, new_intensity: float)
signal wind_changed(direction: Vector3, speed: float)

const MAX_WEATHER_INTENSITY: float = 1.0
const MIN_WEATHER_INTENSITY: float = 0.0

var weather_intensity: float = 0.0:
	set(value):
		var old := weather_intensity
		weather_intensity = clampf(value, MIN_WEATHER_INTENSITY, MAX_WEATHER_INTENSITY)
		if not is_equal_approx(old, weather_intensity):
			_on_weather_changed(old, weather_intensity)

var time_of_day: float = 12.0:
	set(value):
		time_of_day = value
		_update_weather_from_time()
		_update_sky_from_time()

var wind_direction: Vector3 = Vector3(1.0, 0.0, 0.0):
	set(value):
		wind_direction = value.normalized()
		_update_wind_dependent_systems()

var wind_speed: float = 1.0:
	set(value):
		wind_speed = maxf(0.0, value)
		_update_wind_dependent_systems()

## Particle system references (discovered from the current scene)
var rain_particles: GPUParticles3D = null
var snow_particles: GPUParticles3D = null
var car_player: VehicleBody3D = null

## Sky / lighting references
var _world_environment: WorldEnvironment = null
var _sky: Sky = null
var _sky_material: ProceduralSkyMaterial = null
var _sun: DirectionalLight3D = null

## Day/night phase config
const DAY_START: float = 6.5
const DAY_END: float = 19.5
const NIGHT_MIN_SKY_ENERGY: float = 0.12
const NIGHT_MIN_SUN_ENERGY: float = 0.15
const NIGHT_SUN_ANGLE: float = -18.0
const DAY_SUN_ANGLE: float = 60.0

var _ready_emitted: bool = false


func _ready() -> void:
	_discover_systems()
	_update_weather_from_time()
	_update_wind_dependent_systems()
	_update_sky_from_time()
	call_deferred("_emit_ready")


func _emit_ready() -> void:
	if not _ready_emitted:
		_ready_emitted = true
		emit_signal("environment_ready")


func _discover_systems() -> void:
	if get_tree() == null:
		return
	var root := get_tree().current_scene
	if root == null:
		return
	rain_particles = root.get_node_or_null("RainParticles") as GPUParticles3D
	snow_particles = root.get_node_or_null("SnowParticles") as GPUParticles3D
	car_player = root.get_node_or_null("Player") as VehicleBody3D
	_world_environment = root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if _world_environment != null:
		_sky = _world_environment.environment.sky
		if _sky != null:
			_sky_material = _sky.sky_material as ProceduralSkyMaterial
	_sun = root.get_node_or_null("DirectionalLight3D") as DirectionalLight3D


## Drives the procedural sky + sun so time_of_day maps to a believable sun arc.
func _update_sky_from_time() -> void:
	if _sky_material == null:
		return
	var t := time_of_day
	var day_progress := clampf((t - DAY_START) / (DAY_END - DAY_START), 0.0, 1.0)
	var is_night := t < DAY_START or t > DAY_END

	## Sun angle: rise in the east, set in the west, low at night.
	var sun_angle := lerpf(DAY_SUN_ANGLE, NIGHT_SUN_ANGLE, 1.0 - day_progress)
	_sky_material.sun_angle_max = sun_angle

	## Smooth energy curve: dim near dawn/dusk, dark at night.
	var day_factor := 1.0
	if is_night:
		var edge := minf(absf(t - DAY_START), absf(t - DAY_END))
		day_factor = lerpf(NIGHT_MIN_SKY_ENERGY, 1.0, clampf(edge / 2.0, 0.0, 1.0))
	_sky_material.sky_energy_multiplier = day_factor

	if _sun != null:
		_sun.light_energy = lerpf(NIGHT_MIN_SUN_ENERGY, 1.0, day_factor)
		## Rotate sun along the horizon (azimuth) as the day progresses.
		var azimuth := deg_to_rad(-60.0 + 120.0 * day_progress)
		var altitude := deg_to_rad(sun_angle)
		var sun_dir := Vector3(cos(azimuth) * cos(altitude), sin(altitude), sin(azimuth) * cos(altitude))
		_sun.look_at(_sun.global_position + sun_dir, Vector3.UP)


func _update_weather_from_time() -> void:
	## Day (7-19) is clear; night leans toward a light weather chance.
	if time_of_day >= 7.0 and time_of_day <= 19.0:
		weather_intensity = 0.0
	else:
		weather_intensity = minf(0.3 + ((24.0 - time_of_day) / 24.0) * 0.7, MAX_WEATHER_INTENSITY)


func _on_weather_changed(old_intensity: float, new_intensity: float) -> void:
	if rain_particles != null:
		rain_particles.emitting = new_intensity > 0.05
	if snow_particles != null:
		snow_particles.emitting = new_intensity > 0.5 and (time_of_day < 6.0 or time_of_day > 20.0)
	if car_player != null and car_player.has_method("update_weather_effects"):
		car_player.update_weather_effects(new_intensity)
	emit_signal("weather_changed", old_intensity, new_intensity)


func _update_wind_dependent_systems() -> void:
	if rain_particles != null and rain_particles.process_material is ParticleProcessMaterial:
		var m := rain_particles.process_material as ParticleProcessMaterial
		m.gravity = wind_direction * wind_speed
	if snow_particles != null and snow_particles.process_material is ParticleProcessMaterial:
		var m2 := snow_particles.process_material as ParticleProcessMaterial
		m2.gravity = wind_direction * wind_speed
	emit_signal("wind_changed", wind_direction, wind_speed)


func set_weather_intensity(value: float) -> void:
	weather_intensity = clampf(value, MIN_WEATHER_INTENSITY, MAX_WEATHER_INTENSITY)


func set_time_of_day(value: float) -> void:
	time_of_day = value


func set_wind_direction(value: Vector3) -> void:
	wind_direction = value


func set_wind_speed(value: float) -> void:
	wind_speed = value


func get_environment_state() -> Dictionary:
	return {
		"weather_intensity": weather_intensity,
		"time_of_day": time_of_day,
		"wind_direction": wind_direction,
		"wind_speed": wind_speed,
	}


func set_environment_state(state: Dictionary) -> void:
	if state.has("weather_intensity"):
		set_weather_intensity(state["weather_intensity"])
	if state.has("time_of_day"):
		set_time_of_day(state["time_of_day"])
	if state.has("wind_direction"):
		var dir: Variant = state["wind_direction"]
		if dir is Dictionary:
			set_wind_direction(Vector3(dir["x"], dir["y"], dir["z"]))
		elif dir is Vector3:
			set_wind_direction(dir)
	if state.has("wind_speed"):
		set_wind_speed(state["wind_speed"])


## Multiplayer sync helper: receives RPC-driven float updates.
func sync_from_network(data: Dictionary) -> void:
	set_environment_state(data)

```

**check_point_1.gd**
```gdscript
extends Area3D

@export var checkpoint_index: int = 1

@onready var race_manager: Node = $"../../RaceManager"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.name != "Player":
		return

	race_manager.register_checkpoint(checkpoint_index)

```

**dashboard.gd**
```gdscript
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
	if race_manager and race_manager.has_signal("race_active_changed"):
		race_manager.race_active_changed.connect(_on_race_active_changed)
		_on_race_active_changed(not bool(race_manager.get("waiting_for_player")))
	queue_redraw()


func _on_race_active_changed(active: bool) -> void:
	visible = active


func _process(delta: float) -> void:
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

```

**finish.gd**
```gdscript
extends Area3D

@onready var race_manager: Node = $"../RaceManager"

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		print("抵達終點！")
		race_manager.finish_race()

```

### network

**leaderboard_manager.gd**
```gdscript
extends Node

## 公開排行榜管理（EOS Stats + Leaderboards）。
## 使用 stats: "race_time_ms"（毫秒整數，min aggregation）。
## 需要在 Epic Dev Portal 建立對應 Stat 與 Leaderboard Definition：
##   Stat Name: race_time_ms
##   Leaderboard ID: race_time_battle
##   Aggregation: Min

signal leaderboard_updated(records: Array)
signal score_submitted(ok: bool)
signal my_rank_fetched(rank: int, score: int)

const STAT_NAME := "race_time_ms"
const LEADERBOARD_ID := "race_time_battle"

var _records: Array = []
var _my_rank: int = -1
var _my_best_ms: int = 0


func _ready() -> void:
	NetworkManager.login_succeeded.connect(_on_login)


# ==========================================================================
# 提交成績
# ==========================================================================

## 將比賽時間提交到 EOS Stats（毫秒取整，min aggregation）。
func submit_race_time(time_seconds: float) -> void:
	if not NetworkManager.is_logged_in:
		score_submitted.emit(false)
		return
	var ms := int(time_seconds * 1000.0)
	if ms <= 0:
		score_submitted.emit(false)
		return
	var ok := await _ingest_async(STAT_NAME, ms)
	if ok:
		if _my_best_ms <= 0 or ms < _my_best_ms:
			_my_best_ms = ms
		await refresh_my_rank()
	score_submitted.emit(ok)


# ==========================================================================
# 查詢排行榜
# ==========================================================================

## 從 EOS Leaderboards 拉取排行榜資料。
func refresh_leaderboard() -> void:
	if not NetworkManager.is_logged_in:
		leaderboard_updated.emit([])
		return
	var eos := _eos()
	if eos == null:
		leaderboard_updated.emit([])
		return

	var hleader := _hleaderboards()
	if hleader == null:
		leaderboard_updated.emit([])
		return

	var records: Array = await hleader.get_leaderboard_records_async(LEADERBOARD_ID)
	_records = records
	leaderboard_updated.emit(records)


## 查詢自己的排名（透過 QueryLeaderboardUserScores）。
func refresh_my_rank() -> void:
	if not NetworkManager.is_logged_in:
		my_rank_fetched.emit(-1, 0)
		return
	var eos := _eos()
	if eos == null:
		my_rank_fetched.emit(-1, 0)
		return
	var my_uid := NetworkManager.product_user_id
	if my_uid.is_empty():
		my_rank_fetched.emit(-1, 0)
		return
	var query_opts = eos.Leaderboards.QueryLeaderboardUserScoresOptions.new()
	query_opts.user_ids = [my_uid]
	query_opts.stat_info = [{
		"stat_name": STAT_NAME,
		"aggregation": eos.Leaderboards.LeaderboardAggregation.Min,
	}]
	eos.Leaderboards.LeaderboardsInterface.query_leaderboard_user_scores(query_opts)
	var ret: Dictionary = await IEOS.leaderboards_interface_query_leaderboard_user_scores_callback
	if not eos.is_success(ret):
		my_rank_fetched.emit(-1, 0)
		return

	var count_opts = eos.Leaderboards.GetLeaderboardUserScoreCountOptions.new()
	var count: int = eos.Leaderboards.LeaderboardsInterface.get_leaderboard_user_score_count(count_opts)
	if count == 0:
		my_rank_fetched.emit(-1, 0)
		return

	var copy_opts = eos.Leaderboards.CopyLeaderboardUserScoreByIndexOptions.new()
	copy_opts.leaderboard_user_score_index = 0
	copy_opts.stat_name = STAT_NAME
	var copy_ret: Dictionary = eos.Leaderboards.LeaderboardsInterface.copy_leaderboard_user_score_by_index(copy_opts)
	if not eos.is_success(copy_ret):
		my_rank_fetched.emit(-1, 0)
		return
	_my_rank = int(copy_ret.get("rank", -1))
	_my_best_ms = int(copy_ret.get("score", 0))
	my_rank_fetched.emit(_my_rank, _my_best_ms)


func get_my_best_ms() -> int:
	return _my_best_ms


func get_my_rank() -> int:
	return _my_rank


func get_records() -> Array:
	return _records


# ==========================================================================
# 內部
# ==========================================================================

func _ingest_async(stat_name: String, amount: int) -> bool:
	var eos := _eos()
	if eos == null:
		return false
	var hstats := _hstats()
	if hstats == null:
		return false
	var result: EOS.Result = await hstats.ingest_stat_async(stat_name, amount)
	return result == eos.Result.Success


func _hstats() -> Node:
	return get_node_or_null("/root/HStats")


func _hleaderboards() -> Node:
	return get_node_or_null("/root/HLeaderboards")


func _eos() -> GDScript:
	return load("res://addons/epic-online-services-godot/eos.gd")


func _on_login() -> void:
	_my_rank = -1
	_my_best_ms = 0
	refresh_leaderboard()

```

**lobby_manager.gd**
```gdscript
extends Node

## 房間 / 大廳管理（EOS Lobbies）
## 開房(12人)、搜尋、加入、就緒、開始，全部透過 EOS Lobbies 同步。
## ready 狀態存在「自己的 member attribute」；host 端從 lobby members 收集。

signal lobby_created(lobby_info: Dictionary)
signal lobby_joined(lobby_info: Dictionary)
signal member_joined(member_id: String)
signal member_left(member_id: String)
signal ready_state_changed(ready_map: Dictionary)
signal match_started(peer_order: Array)

const MAX_PLAYERS := 12
const BUCKET_ID := "3d_race"
const ATTR_READY := "ready"
const ATTR_PEER_ORDER := "peer_order"
const ATTR_DISPLAY_NAME := "display_name"
const ATTR_ROOM_NAME := "room_name"
const ATTR_HOST_NAME := "host_name"
const ATTR_GAME := "game"

var current_lobby: Dictionary = {}
var is_host: bool = false
## players: [{ "peer_id": int, "product_user_id": String, "name": String, "ready": bool }]
var players: Array = []

var _lobby = null


# ==========================================================================
# 開房 / 搜尋 / 加入 / 離開
# ==========================================================================

## 開房：建立 EOS lobby，並在 host 端開 listen server。
## room_config 可傳 {"name": String, "max_players": int} 讓其他玩家搜到房名與人數。
func create_lobby(room_config: Dictionary = {}) -> void:
	if not _nm().is_logged_in:
		lobby_created.emit({})
		return

	var hlobbies = _hlobbies()
	var eos = _eos_class()
	if hlobbies == null or eos == null:
		lobby_created.emit({})
		return

	var max_players: int = int(room_config.get("max_players", MAX_PLAYERS))
	var room_name: String = str(room_config.get("name", "%s 的房間" % _nm().display_name))

	var opts = eos.Lobby.CreateLobbyOptions.new()
	opts.max_lobby_members = max_players
	opts.bucket_id = BUCKET_ID
	opts.permission_level = eos.Lobby.LobbyPermissionLevel.PublicAdvertised
	opts.enable_join_by_id = true
	opts.allow_invites = true
	opts.enable_rtc_room = false
	opts.local_rtc_options = hlobbies.local_rtc_options

	var lobby: Variant = await hlobbies.create_lobby_async(opts)
	if not lobby:
		lobby_created.emit({})
		return

	is_host = true
	_bind_lobby(lobby)

	lobby.add_attribute(ATTR_GAME, "3d_race")
	lobby.add_attribute(ATTR_HOST_NAME, _nm().display_name)
	lobby.add_attribute(ATTR_ROOM_NAME, room_name)
	lobby.add_attribute(ATTR_DISPLAY_NAME, _nm().display_name)
	await lobby.update_async()

	_sync_members()
	current_lobby = _lobby_info()
	lobby_created.emit(current_lobby)

	# 本機先開 host peer（listen server）
	_nm().host_game()


## 搜尋公開房。回傳 Array[HLobby]，空陣列表示沒有。
func search_lobbies() -> Array:
	if not _nm().is_logged_in:
		return []
	var hlobbies = _hlobbies()
	if hlobbies == null:
		return []
	var results = await hlobbies.search_by_bucket_id_async(BUCKET_ID)
	return results if results else []


## 加入一間搜尋到的房（HLobby）。
func join_lobby(lobby) -> void:
	if not lobby or not _nm().is_logged_in:
		lobby_joined.emit({})
		return

	var hlobbies = _hlobbies()
	if hlobbies == null:
		lobby_joined.emit({})
		return
	var joined: Variant = await hlobbies.join_async(lobby)
	if not joined:
		lobby_joined.emit({})
		return

	is_host = false
	_bind_lobby(joined)

	# 把自己的暱稱寫進 member attribute，host 端 _sync_members 才看得到名字
	joined.add_current_member_attribute(ATTR_DISPLAY_NAME, _nm().display_name,
			EOS.Lobby.LobbyAttributeVisibility.Public)
	await joined.update_async()

	_sync_members()
	current_lobby = _lobby_info()
	lobby_joined.emit(current_lobby)

	# client 用 host 的 product user id 建立連線
	var host_user_id = joined.owner_product_user_id
	_nm().join_game(host_user_id)


## 離開目前房間（host 結束時會連 lobby 一起銷毀）。
func leave_lobby() -> void:
	if not _lobby:
		return
	var lobby = _lobby
	_lobby = null
	is_host = false
	players = []
	current_lobby = {}
	_nm().disconnect_from_game()
	await lobby.leave_async()


# ==========================================================================
# 成員 / 就緒 / 開始
# ==========================================================================

## 遊戲層在多人連線建立後補充成員（product_user_id -> peer_id 對應用）。
func add_player(peer_id: int, display_name: String) -> void:
	for player in players:
		if player["peer_id"] == peer_id:
			return
	players.append({"peer_id": peer_id, "product_user_id": "", "name": display_name, "ready": false})
	ready_state_changed.emit(get_ready_map())


## 把 lobby member 同步成 players，並把 product_user_id 對應到 peer_id。
## 會 emit member_joined / member_left 給 UI 更新。
func _sync_members() -> void:
	if not _lobby:
		return
	var new_players: Array = []
	for member in _lobby.members:
		var ready := false
		var ready_attr: Dictionary = member.get_attribute(ATTR_READY)
		if not ready_attr.is_empty():
			ready = bool(ready_attr.value)
		# EOSG HLobbyMember.display_name 不會自動填，需從 member attribute 讀取
		var name: String = ""
		var name_attr: Dictionary = member.get_attribute(ATTR_DISPLAY_NAME)
		if not name_attr.is_empty():
			name = str(name_attr.value)
		if name.is_empty():
			name = member.display_name
		if name.is_empty():
			name = "玩家"
		new_players.append({
			"peer_id": _resolve_peer_id(member.product_user_id),
			"product_user_id": member.product_user_id,
			"name": name,
			"ready": ready,
		})
	# diff 舊 players，emit member_joined / member_left
	var old_ids: Array = []
	for p in players:
		old_ids.append(p["product_user_id"])
	var new_ids: Array = []
	for p in new_players:
		new_ids.append(p["product_user_id"])
	for id in new_ids:
		if id not in old_ids:
			member_joined.emit(id)
	for id in old_ids:
		if id not in new_ids:
			member_left.emit(id)
	players = new_players
	ready_state_changed.emit(get_ready_map())


## 把 product_user_id 對應成 peer id；本機是 1，其餘靠 EOSGMultiplayerPeer。
func _resolve_peer_id(product_user_id: String) -> int:
	if product_user_id == _nm().product_user_id:
		return _nm().LOCAL_PEER_ID
	return _nm().get_peer_id_for_user(product_user_id)


## 本機玩家設為就緒 / 未就緒（寫入自己的 member attribute）。
func set_ready(is_ready: bool) -> void:
	if not _lobby:
		return
	var eos = _eos_class()
	if eos == null:
		return
	_lobby.add_current_member_attribute(ATTR_READY, is_ready, eos.Lobby.LobbyAttributeVisibility.Private)
	await _lobby.update_async()


func get_ready_map() -> Dictionary:
	var map := {}
	for player in players:
		map[player["peer_id"]] = player["ready"]
	return map


## host 呼叫：確認所有人都就緒後開始比賽。
func start_match() -> void:
	if not is_host or not _lobby:
		return
	var peer_order := _build_peer_order()
	if not _all_ready(peer_order):
		return
	# 把開場順序寫進 lobby attribute，client 端透過 lobby_updated 收到
	_lobby.add_attribute(ATTR_PEER_ORDER, JSON.stringify(peer_order))
	await _lobby.update_async()
	match_started.emit(peer_order)


func _build_peer_order() -> Array:
	var order: Array = []
	for player in players:
		order.append(player["peer_id"])
	order.sort()
	return order


func _all_ready(order: Array) -> bool:
	for player in players:
		if player["peer_id"] in order:
			if not player["ready"]:
				return false
	return true


# ==========================================================================
# 內部
# ==========================================================================

func _nm() -> Variant:
	return get_node_or_null("/root/NetworkManager")


func _eos_class() -> Variant:
	return load("res://addons/epic-online-services-godot/eos.gd")


func _hlobbies() -> Variant:
	return get_node_or_null("/root/HLobbies")

func _bind_lobby(lobby) -> void:
	_lobby = lobby
	_lobby.lobby_updated.connect(_on_lobby_updated)
	_lobby.kicked_from_lobby.connect(_on_kicked)
	_lobby.lobby_owner_changed.connect(_on_owner_changed)


func _on_lobby_updated() -> void:
	_sync_members()
	if not is_host and _lobby:
		var order_attr: Dictionary = _lobby.get_attribute(ATTR_PEER_ORDER)
		if not order_attr.is_empty() and order_attr.value is String:
			var order = JSON.parse_string(order_attr.value)
			if order is Array and not order.is_empty():
				match_started.emit(order)


func _on_kicked() -> void:
	is_host = false
	players = []
	current_lobby = {}
	_lobby = null
	_nm().disconnect_from_game()


func _on_owner_changed() -> void:
	is_host = _lobby.is_owner()


func _lobby_info() -> Dictionary:
	return {
		"lobby_id": _lobby.lobby_id if _lobby else "",
		"is_host": is_host,
		"player_count": players.size(),
		"max_players": _lobby.max_members if _lobby else MAX_PLAYERS,
	}

```

**network_manager.gd**
```gdscript
extends Node

## 網路管理：單人 / 開房(host) / 加入(client)。
## 線上模式透過 Epic Online Services (EOSG 插件)：
##  - 登入：Epic Dev Auth Tool（開發）/ Epic Account Portal / Discord OAuth2
##  - 傳輸：EOSGMultiplayerPeer（EOS P2P），host 是 listen server（peer 1）

enum Mode {
	SINGLEPLAYER,  ## 單機計時賽
	HOST,          ## 開房（listen server，peer id = 1）
	CLIENT,        ## 加入別人的房
}

signal mode_changed(mode: int)
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal eos_initialized(success: bool, message: String)
signal login_succeeded
signal login_failed(message: String)
signal logged_out
signal discord_oauth_started
signal discord_oauth_completed(code: String, error: String)

const LOCAL_PEER_ID := 1
const MAX_PLAYERS := 12  ## 連線數上限（配合 12 格出發位置）
const EOS_CONFIG_PATH := "res://eos_config.cfg"
const EOS_SOCKET_ID := "race_3d"
const DISCORD_REDIRECT_PORT := 14514

var mode: int = Mode.SINGLEPLAYER
var is_eos_ready := false
var is_logged_in := false
var display_name := ""
var product_user_id := ""

var _peer = null
var _oauth_server: TCPServer = null
var _discord_http: HTTPRequest = null
var _discord_auth_code := ""
var _discord_state := ""
var _suppress_login_error := false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	discord_oauth_completed.connect(_on_discord_oauth_completed)


func set_mode(new_mode: int) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	mode_changed.emit(mode)


func is_online() -> bool:
	return mode != Mode.SINGLEPLAYER


func is_host() -> bool:
	return mode == Mode.HOST


func _hauth() -> Node:
	return get_node_or_null("/root/HAuth")


func _hplatform() -> Node:
	return get_node_or_null("/root/HPlatform")


func _hlog() -> Node:
	return get_node_or_null("/root/HLog")


func _hstats() -> Node:
	return get_node_or_null("/root/HStats")


func _hleaderboards() -> Node:
	return get_node_or_null("/root/HLeaderboards")


# ==========================================================================
# EOS 初始化與登入
# ==========================================================================

## 讀取 eos_config.cfg 並初始化 EOS SDK + Platform。
func init_eos() -> void:
	if is_eos_ready:
		eos_initialized.emit(true, "")
		return
	var hp := _hplatform()
	var hauth := _hauth()
	if hp == null or hauth == null or not hp.has_method("setup_eos_async"):
		eos_initialized.emit(false, "EOS 執行期未就緒（檢查 EOSG 插件 / GDExtension）")
		return

	var config := ConfigFile.new()
	if config.load(EOS_CONFIG_PATH) != OK:
		eos_initialized.emit(false, "無法讀取 %s" % EOS_CONFIG_PATH)
		return

	var creds := HCredentials.new()
	creds.product_name = config.get_value("eos", "product_name", "3D Race")
	creds.product_version = config.get_value("eos", "product_version", "0.1")
	creds.product_id = config.get_value("eos", "product_id", "")
	creds.sandbox_id = config.get_value("eos", "sandbox_id", "")
	creds.deployment_id = config.get_value("eos", "deployment_id", "")
	creds.client_id = config.get_value("eos", "client_id", "")
	creds.client_secret = config.get_value("eos", "client_secret", "")
	creds.encryption_key = config.get_value("eos", "encryption_key", "")

	if creds.product_id.is_empty() or creds.sandbox_id.is_empty() \
			or creds.deployment_id.is_empty() or creds.client_id.is_empty():
		eos_initialized.emit(false,
				"EOS 憑證不完整：請在 %s 填入 product_id / sandbox_id / deployment_id / client_id / client_secret" % EOS_CONFIG_PATH)
		return

	var hlog := _hlog()
	if hlog != null:
		hlog.set("log_level", int(0) if not "LogLevel" in hlog else int(HLog.LogLevel.INFO))
	hp.log_msg.connect(_on_eos_log, CONNECT_DEFERRED)
	hauth.logged_in.connect(_on_logged_in)
	hauth.logged_out.connect(_on_logged_out)
	hauth.login_error.connect(_on_login_error)

	var setup_success: bool = await hp.setup_eos_async(creds)
	if not setup_success:
		eos_initialized.emit(false, "EOS 初始化失敗，詳見 Output / HPlatform log")
		return

	is_eos_ready = true
	eos_initialized.emit(true, "")


## 統一登入入口：provider 為 "epic" / "discord" / "anonymous" / "devtool"。
## 未指定時依設定檔 [login] method（預設 account_portal）。
func login(provider := "") -> void:
	if not is_eos_ready:
		login_failed.emit("EOS 尚未初始化，請先呼叫 init_eos()")
		return
	var method := provider.strip_edges()
	if method.is_empty():
		var config := ConfigFile.new()
		if config.load(EOS_CONFIG_PATH) == OK:
			method = config.get_value("login", "method", "account_portal")
		else:
			method = "account_portal"
	match method:
		"epic", "account_portal":
			login_account_portal()
		"discord":
			login_discord()
		"anonymous":
			login_anonymous()
		"devtool":
			login_devtool()
		_:
			login_failed.emit("未知登入方式：%s" % method)


## Epic Dev Auth Tool 登入（開發用，需先開 DevAuthTool）
func login_devtool(server_url := "", credential_name := "") -> void:
	if not is_eos_ready:
		login_failed.emit("EOS 尚未初始化")
		return
	var hauth := _hauth()
	if hauth == null or not hauth.has_method("login_devtool_async"):
		login_failed.emit("EOS 執行期未就緒")
		return
	var config := ConfigFile.new()
	if config.load(EOS_CONFIG_PATH) == OK:
		if server_url.is_empty():
			server_url = config.get_value("login", "devtool_server_url", "localhost:4545")
		if credential_name.is_empty():
			credential_name = config.get_value("login", "devtool_credential_name", "")
	var ok: bool = await hauth.login_devtool_async(server_url, credential_name)
	if not ok:
		login_failed.emit("Dev Auth Tool 登入失敗（請確認已啟動 DevAuthTool 且帳號名稱正確）")


## Epic Account Portal 登入（跳出瀏覽器登入頁）
func login_account_portal() -> void:
	if not is_eos_ready:
		login_failed.emit("EOS 尚未初始化")
		return
	var hauth := _hauth()
	if hauth == null or not hauth.has_method("login_account_portal_async"):
		login_failed.emit("EOS 執行期未就緒")
		return
	var ok: bool = await hauth.login_account_portal_async()
	if not ok:
		login_failed.emit("Epic Account Portal 登入失敗")


## Connect 匿名登入（device id，不需 EAS / Account Portal）。
## 適合開發與本機多人測試。
func login_anonymous(display_name := "") -> void:
	if not is_eos_ready:
		login_failed.emit("EOS 尚未初始化")
		return
	var hauth := _hauth()
	if hauth == null or not hauth.has_method("login_anonymous_async"):
		login_failed.emit("EOS 執行期未就緒")
		return
	if display_name.is_empty():
		display_name = "Player_%d" % randi_range(1000, 9999)
	var ok: bool = await hauth.login_anonymous_async(display_name)
	if not ok:
		login_failed.emit("匿名登入失敗")


## 嘗試以先前 Account Portal 登入儲存的 refresh token 自動登入。
## 若無儲存的 token 或登入失敗，回傳 false（不觸發 login_failed）。
func try_persistent_login() -> bool:
	if not is_eos_ready:
		return false
	var hauth := _hauth()
	if hauth == null or not hauth.has_method("login_persistent_auth_async"):
		return false
	_suppress_login_error = true
	var ok: bool = await hauth.login_persistent_auth_async()
	_suppress_login_error = false
	return ok


# ==========================================================================
# Discord OAuth2 登入
# ==========================================================================

## 啟動 Discord OAuth2 登入流程：
##   1. 開啟瀏覽器顯示 Discord 授權頁
##   2. 用 TCPServer 在 localhost 等待回呼
##   3. 用 access_token 呼叫 EOS Connect 登入
func login_discord() -> void:
	if not is_eos_ready:
		login_failed.emit("EOS 尚未初始化")
		return
	var config := ConfigFile.new()
	if config.load(EOS_CONFIG_PATH) != OK:
		login_failed.emit("無法讀取 %s" % EOS_CONFIG_PATH)
		return
	var client_id: String = config.get_value("discord", "client_id", "")
	if client_id.is_empty():
		login_failed.emit("Discord client_id 未設定（請在 eos_config.cfg [discord] 填入）")
		return

	_discord_state = _random_state()
	var redirect_uri := "http://localhost:%d/callback" % DISCORD_REDIRECT_PORT
	var scope := "identify"
	var url := "https://discord.com/api/oauth2/authorize?client_id=%s&redirect_uri=%s&response_type=code&scope=%s&state=%s" % [
		client_id, redirect_uri.uri_encode(), scope, _discord_state
	]
	_start_oauth_server()
	OS.shell_open(url)
	discord_oauth_started.emit()


## 用 Discord access_token 透過 EOS Connect 登入（Auth → Connect 流程）。
func login_discord_with_token(access_token: String) -> void:
	if not is_eos_ready:
		login_failed.emit("EOS 尚未初始化")
		return
	var hauth := _hauth()
	if hauth == null:
		login_failed.emit("EOS 執行期未就緒")
		return

	var eos := _eos_class()
	if eos == null:
		login_failed.emit("EOS 型別未載入")
		return

	var opts = eos.Auth.LoginOptions.new()
	opts.credentials = eos.Auth.Credentials.new()
	opts.credentials.type = eos.Auth.LoginCredentialType.ExternalAuth
	opts.credentials.external_type = eos.ExternalCredentialType.DiscordAccessToken
	opts.credentials.token = access_token
	opts.scope_flags = eos.Auth.ScopeFlags.NoFlags
	opts.login_flags = eos.Auth.LoginFlags.None

	var ok: bool = await hauth.login_async(opts)
	if not ok:
		login_failed.emit("Discord 登入失敗（請確認 Discord 帳號已關聯到 Epic 帳戶）")


func _start_oauth_server() -> void:
	_stop_oauth_server()
	_oauth_server = TCPServer.new()
	var err := _oauth_server.listen(DISCORD_REDIRECT_PORT)
	if err != OK:
		discord_oauth_completed.emit("", "無法啟動回呼伺服器（port %d）" % DISCORD_REDIRECT_PORT)
		return


func _stop_oauth_server() -> void:
	if _oauth_server:
		_oauth_server.stop()
		_oauth_server = null


## 用授權碼換取 Discord access_token（透過 Discord API）。
func _exchange_code_for_token(code: String) -> void:
	var config := ConfigFile.new()
	if config.load(EOS_CONFIG_PATH) != OK:
		discord_oauth_completed.emit("", "無法讀取設定檔")
		return
	var client_id: String = config.get_value("discord", "client_id", "")
	var client_secret: String = config.get_value("discord", "client_secret", "")
	var redirect_uri := "http://localhost:%d/callback" % DISCORD_REDIRECT_PORT

	_discord_http = HTTPRequest.new()
	add_child(_discord_http)
	_discord_http.request_completed.connect(_on_discord_token_response)

	var body := "client_id=%s&client_secret=%s&grant_type=authorization_code&code=%s&redirect_uri=%s" % [
		client_id.uri_encode(), client_secret.uri_encode(), code.uri_encode(), redirect_uri.uri_encode()
	]
	_discord_http.request(
		"https://discord.com/api/oauth2/token",
		["Content-Type: application/x-www-form-urlencoded"],
		HTTPClient.METHOD_POST,
		body
	)


func _on_discord_token_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _discord_http:
		_discord_http.queue_free()
		_discord_http = null
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var msg := "Discord token 交換失敗（HTTP %d）" % response_code
		discord_oauth_completed.emit("", msg)
		return
	var json_text := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null or not (parsed is Dictionary):
		discord_oauth_completed.emit("", "Discord token 交換失敗：回應格式異常")
		return
	var json_dict: Dictionary = parsed as Dictionary
	if not json_dict.has("access_token"):
		discord_oauth_completed.emit("", "Discord token 交換失敗：回應格式異常")
		return
	var access_token: String = json_dict["access_token"] as String
	await login_discord_with_token(access_token)


func _random_state() -> String:
	var s := ""
	for i in range(32):
		s += "0123456789abcdef"[randi() % 16]
	return s


func _eos_class() -> GDScript:
	return load("res://addons/epic-online-services-godot/eos.gd") as GDScript


func logout() -> void:
	if not is_logged_in:
		return
	disconnect_from_game()
	var hauth := _hauth()
	if hauth != null:
		if hauth.has_method("logout_async"):
			await hauth.logout_async()
		# 清除儲存的 persistent auth refresh token，避免下次啟動自動登入殘留
		if hauth.has_method("delete_persistent_auth_async"):
			await hauth.delete_persistent_auth_async()


# ==========================================================================
# 建立 / 加入網路連線（EOSGMultiplayerPeer）
# ==========================================================================

## 開房：建立 listen server。回傳 OK 或錯誤碼。
func host_game() -> int:
	if not is_logged_in:
		return ERR_UNAUTHORIZED
	if not ClassDB.class_exists("EOSGMultiplayerPeer"):
		return ERR_UNAVAILABLE
	var peer = ClassDB.instantiate("EOSGMultiplayerPeer")
	var err: int = peer.create_server(EOS_SOCKET_ID)
	if err != OK:
		return err
	peer.set_auto_accept_connection_requests(true)
	_attach_peer(peer)
	set_mode(Mode.HOST)
	return OK


## 加入 host 的房：host_user_id 是 host 的 EOS product user id（從 lobby 取得）。
func join_game(host_user_id: String) -> int:
	if not is_logged_in or host_user_id.is_empty():
		return ERR_UNAUTHORIZED
	if not ClassDB.class_exists("EOSGMultiplayerPeer"):
		return ERR_UNAVAILABLE
	var peer = ClassDB.instantiate("EOSGMultiplayerPeer")
	var err: int = peer.create_client(EOS_SOCKET_ID, host_user_id)
	if err != OK:
		return err
	_attach_peer(peer)
	set_mode(Mode.CLIENT)
	return OK


## 斷開網路連線，回到單人模式。
func disconnect_from_game() -> void:
	if _peer:
		multiplayer.multiplayer_peer = null
		_peer = null
	if is_online():
		set_mode(Mode.SINGLEPLAYER)


func get_peer_user_id(peer_id: int) -> String:
	if _peer:
		return _peer.get_peer_user_id(peer_id)
	return ""


func get_peer_id_for_user(user_id: String) -> int:
	if _peer:
		return _peer.get_peer_id(user_id)
	return 0


# ==========================================================================
# 內部：peer 事件
# ==========================================================================

func _attach_peer(peer) -> void:
	_peer = peer
	multiplayer.multiplayer_peer = peer


func _on_peer_connected(peer_id: int) -> void:
	peer_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)


func _on_connected_to_server() -> void:
	pass


func _on_connection_failed() -> void:
	if mode == Mode.CLIENT:
		set_mode(Mode.SINGLEPLAYER)


func _on_server_disconnected() -> void:
	if mode == Mode.CLIENT:
		set_mode(Mode.SINGLEPLAYER)


func _on_logged_in() -> void:
	is_logged_in = true
	var hauth := _hauth()
	if hauth != null:
		var disp: Variant = hauth.get("display_name")
		display_name = str(disp) if disp != null else ""
		var uid: Variant = hauth.get("product_user_id")
		product_user_id = str(uid) if uid != null else ""
	else:
		display_name = ""
		product_user_id = ""
	if product_user_id.is_empty():
		is_logged_in = false
		login_failed.emit("登入成功但未取得 Product User ID（請確認 EOS Connect 已建立帳號）")
		return
	login_succeeded.emit()


func _on_logged_out() -> void:
	is_logged_in = false
	display_name = ""
	product_user_id = ""
	logged_out.emit()


## 記錄 HAuth 登入失敗的實際 EOS 錯誤碼（提供除錯資訊；UI 訊息由各登入方法負責）。
func _on_login_error(result_code) -> void:
	if _suppress_login_error:
		return
	var code_name := "Unknown"
	var eos := _eos_class()
	if eos != null and eos.has_method("result_str"):
		code_name = eos.result_str(result_code)
	push_warning("EOS 登入錯誤：%s" % code_name)


func _on_eos_log(msg) -> void:
	## 之後可接 UI / 檔案 log
	pass


# ==========================================================================
# Discord OAuth2 回呼處理（在 _process 輪詢）
# ==========================================================================

var _oauth_conn: StreamPeerTCP = null
var _oauth_conn_time := 0.0


func _process(delta: float) -> void:
	# 輪詢 OAuth 回呼連線
	if _oauth_server and _oauth_server.is_connection_available():
		_oauth_conn = _oauth_server.take_connection()
		_oauth_conn_time = 0.0
	if _oauth_conn:
		_oauth_conn_time += delta
		if _oauth_conn.get_available_bytes() > 0:
			_handle_oauth_response(_oauth_conn)
		elif _oauth_conn_time > 10.0:
			_oauth_conn.disconnect_from_host()
			_oauth_conn = null
			discord_oauth_completed.emit("", "回呼逾時")


func _handle_oauth_response(conn: StreamPeerTCP) -> void:
	var raw: Array = conn.get_data(conn.get_available_bytes())
	var data: String = ""
	if raw.size() > 1 and raw[1] is PackedByteArray:
		data = raw[1].get_string_from_utf8()
	_stop_oauth_server()
	_oauth_conn = null

	var code := ""
	var state := ""
	var error := ""
	for line in data.split("\n"):
		if line.begins_with("GET "):
			var path_end := line.find(" HTTP/")
			if path_end > 4:
				var path := line.substr(4, path_end - 4)
				var qs_start := path.find("?")
				if qs_start >= 0:
					var qs := path.substr(qs_start + 1)
					for pair in qs.split("&"):
						var kv := pair.split("=")
						if kv.size() == 2:
							match kv[0]:
								"code":
									code = kv[1].uri_decode()
								"state":
									state = kv[1].uri_decode()
								"error":
									error = kv[1].uri_decode()
			break

	var body := "<html><body><h2>已關閉，請回到遊戲。</h2></body></html>"
	var resp := "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\n\r\n%s" % [body.length(), body]
	conn.put_data(resp.to_utf8_buffer())
	conn.disconnect_from_host()

	if error.is_empty() and code.is_empty():
		discord_oauth_completed.emit("", "授權失敗：未收到授權碼")
		return
	if state != _discord_state:
		discord_oauth_completed.emit("", "授權失敗：state 不匹配（可能為 CSRF 攻擊）")
		return
	_discord_auth_code = code
	discord_oauth_completed.emit(code, "")


func _on_discord_oauth_completed(code: String, error: String) -> void:
	if not error.is_empty():
		login_failed.emit(error)
		return
	if code.is_empty():
		login_failed.emit("Discord 授權失敗")
		return
	await _exchange_code_for_token(code)

```

**player_storage.gd**
```gdscript
extends Node

## 玩家資料雲端儲存（EOS PlayerDataStorage）。
## 用低階 EOS.PlayerDataStorage API 讀寫單一 profile.json，
## 存放公開暱稱等輕量玩家資料。
## 注意：所有操作都是非同步的，請用 await 取得結果。

signal profile_saved(ok: bool)

const PROFILE_FILENAME := "profile.json"
const CHUNK_LENGTH_BYTES := 4096

var _read_buffer := PackedByteArray()


func is_available() -> bool:
	return NetworkManager.is_eos_ready and not NetworkManager.product_user_id.is_empty()


## 檢查雲端是否已有 profile。回傳 true 代表已存在。
func has_profile() -> bool:
	var eos := _eos()
	if eos == null or not is_available():
		return false
	var opts = eos.PlayerDataStorage.QueryFileOptions.new()
	opts.local_user_id = NetworkManager.product_user_id
	opts.filename = PROFILE_FILENAME
	eos.PlayerDataStorage.PlayerDataStorageInterface.query_file(opts)
	var ret: Dictionary = await IEOS.playerdatastorage_interface_query_file_callback
	return bool(eos.is_success(ret))


## 從雲端讀取 profile。回傳 Dictionary，失敗時為空字典。
func load_profile() -> Dictionary:
	var eos := _eos()
	if eos == null or not is_available():
		return {}
	var opts = eos.PlayerDataStorage.ReadFileOptions.new()
	opts.local_user_id = NetworkManager.product_user_id
	opts.filename = PROFILE_FILENAME
	opts.read_chunk_length_bytes = CHUNK_LENGTH_BYTES
	_read_buffer = PackedByteArray()
	IEOS.playerdatastorage_interface_read_file_data_callback.connect(_on_read_file_data)
	eos.PlayerDataStorage.PlayerDataStorageInterface.read_file(opts)
	var ret: Dictionary = await IEOS.playerdatastorage_interface_read_file_callback
	IEOS.playerdatastorage_interface_read_file_data_callback.disconnect(_on_read_file_data)
	if not bool(eos.is_success(ret)):
		return {}
	var json_text := _read_buffer.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(json_text)
	return parsed as Dictionary if parsed is Dictionary else {}


## 上傳 profile 到雲端。回傳是否成功。
func save_profile(profile: Dictionary) -> bool:
	var eos := _eos()
	if eos == null or not is_available():
		return false
	var json_text := JSON.stringify(profile)
	var opts = eos.PlayerDataStorage.WriteFileOptions.new()
	opts.local_user_id = NetworkManager.product_user_id
	opts.filename = PROFILE_FILENAME
	opts.data = json_text.to_utf8_buffer()
	opts.chunk_length_bytes = CHUNK_LENGTH_BYTES
	eos.PlayerDataStorage.PlayerDataStorageInterface.write_file(opts)
	var ret: Dictionary = await IEOS.playerdatastorage_interface_write_file_callback
	var ok: bool = bool(eos.is_success(ret))
	profile_saved.emit(ok)
	return ok


func _on_read_file_data(data: Dictionary) -> void:
	var chunk: PackedByteArray = data.get("data_chunk", PackedByteArray())
	_read_buffer.append_array(chunk)


func _eos() -> GDScript:
	return load("res://addons/epic-online-services-godot/eos.gd")
```

## res://

**player.gd**
```gdscript
extends VehicleBody3D

@export var engine_power: float = 2600.0
@export var reverse_engine_power: float = 900.0
@export var brake_power: float = 45.0
@export var rolling_brake: float = 1.5
@export var parking_brake: float = 12.0
@export var max_speed: float = 33.0
@export var reverse_speed: float = 9.0
@export var max_steer_angle_degrees: float = 24.0
@export var steering_speed: float = 2.4
@export var high_speed_steer_ratio: float = 0.28
@export var downforce: float = 38.0
@export var upright_strength: float = 16000.0
@export var upright_damping: float = 3400.0
@export var fall_respawn_height: float = -5.0
@export var shift_duration: float = 0.18
@export var road_tire_grip: float = 2.3
@export var grass_tire_grip: float = 1.25
@export var grass_engine_multiplier: float = 0.62
@export var grass_drag_acceleration: float = 1.4
@export var grass_coast_brake: float = 5.0
@export var is_local_player: bool = true

@onready var race_manager: Node = _find_race_manager()

var spawn_transform: Transform3D
var current_gear: int = 1
var engine_rpm: float = 900.0
var shift_timer: float = 0.0
var grass_contact_ratio: float = 0.0
var road_surface_lookup_ready: bool = false
var road_triangles: Array[PackedVector2Array] = []
var road_triangle_grid: Dictionary = {}

## Weather grip multiplier applied by EnvironmentManager (1.0 = dry).
var weather_grip_multiplier: float = 1.0
const WET_GRIP_MIN: float = 0.82
const WET_GRIP_MAX: float = 0.85

const MAX_FORWARD_GEAR := 5
const ROAD_GRID_CELL_SIZE := 4.0
const UPSHIFT_SPEEDS := [0.0, 8.5, 15.0, 22.0, 28.0, 999.0]
const DOWNSHIFT_SPEEDS := [0.0, 0.0, 6.5, 13.0, 20.0, 26.0]
const GEAR_FORCE_MULTIPLIERS := [0.0, 1.20, 1.08, 0.98, 0.89, 0.80]
const GEAR_RPM_SPEED_RANGES := [
	Vector2(0.0, 1.0),
	Vector2(0.0, 10.0),
	Vector2(5.0, 17.5),
	Vector2(12.0, 25.0),
	Vector2(19.0, 31.0),
	Vector2(25.0, 34.0),
]

const WHEEL_SETTINGS := {
	"FL": {
		"position": Vector3(-1.0247, 0.58, -1.30),
		"steering": true,
		"traction": false,
	},
	"FR": {
		"position": Vector3(1.0247, 0.58, -1.30),
		"steering": true,
		"traction": false,
	},
	"RL": {
		"position": Vector3(-1.0247, 0.58, 1.5829),
		"steering": false,
		"traction": true,
	},
	"RR": {
		"position": Vector3(1.0247, 0.58, 1.5829),
		"steering": false,
		"traction": true,
	},
}

const CONCEPT_WHEEL_MAP := {
	"FL": ["tire_001_R17_001", "rim_235_001"],
	"FR": ["tire_001_R17_003", "rim_235_003"],
	"RL": ["tire_001_R17_002", "rim_235_002"],
	"RR": ["tire_001_R17_004", "rim_235_004"],
}

const WHEEL_RADIUS := 0.38


func _ready() -> void:
	_configure_model_wheels()
	_build_road_surface_lookup()
	spawn_transform = global_transform
	_apply_local_player_state()


func _find_race_manager() -> Node:
	var nearby := get_node_or_null("../RaceManager")
	if nearby != null:
		return nearby
	var far := get_node_or_null("../../RaceManager")
	if far != null:
		return far
	return get_tree().get_first_node_in_group("race_manager")


func _apply_local_player_state() -> void:
	if not is_local_player:
		var camera := get_node_or_null("Camera3D") as Camera3D
		if camera != null:
			camera.current = false


func _physics_process(delta: float) -> void:
	if not is_local_player:
		return
	if global_position.y < fall_respawn_height and not race_manager.waiting_for_player:
		respawn_car()
		race_manager.restart_race()
		return

	if Input.is_physical_key_pressed(KEY_R) and not race_manager.waiting_for_player:
		respawn_car()
		race_manager.restart_race()
		return

	_update_surface_response()

	if (
		race_manager.waiting_for_player
		or not race_manager.race_started
		or race_manager.race_finished
	):
		engine_force = 0.0
		brake = parking_brake
		steering = move_toward(steering, 0.0, steering_speed * delta)
		return

	var throttle := 0.0
	var steering_input := 0.0

	if Input.is_physical_key_pressed(KEY_W):
		throttle += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		throttle -= 1.0
	if Input.is_physical_key_pressed(KEY_A):
		steering_input += 1.0
	if Input.is_physical_key_pressed(KEY_D):
		steering_input -= 1.0

	_update_automatic_gearbox(throttle, delta)
	_update_engine_and_brake(throttle)
	_update_steering(steering_input, delta)
	_apply_grass_drag()
	_apply_downforce()
	_apply_upright_stability()


func _update_surface_response() -> void:
	var grass_wheel_count := 0

	for wheel_name in WHEEL_SETTINGS:
		var wheel := get_node_or_null("Wheel%s" % wheel_name) as VehicleWheel3D
		if wheel == null:
			continue

		var wheel_on_grass := (
			wheel.is_in_contact()
			and not _is_point_on_road(wheel.global_position)
		)

		var base_grip := grass_tire_grip if wheel_on_grass else road_tire_grip
		wheel.wheel_friction_slip = base_grip * weather_grip_multiplier
		if wheel_on_grass:
			grass_wheel_count += 1

		grass_contact_ratio = float(grass_wheel_count) / float(WHEEL_SETTINGS.size())


## Called by EnvironmentManager when weather intensity changes.
## Reduces tire grip on wet/snowy surfaces (dry = 1.0).
func update_weather_effects(intensity: float) -> void:
	weather_grip_multiplier = lerpf(1.0, WET_GRIP_MIN, clampf(intensity, 0.0, 1.0))
	for wheel_name in WHEEL_SETTINGS:
		var wheel := get_node_or_null("Wheel%s" % wheel_name) as VehicleWheel3D
		if wheel != null:
			wheel.wheel_friction_slip = lerpf(road_tire_grip, grass_tire_grip, grass_contact_ratio) * weather_grip_multiplier


func _build_road_surface_lookup() -> void:
	var road_mesh: MeshInstance3D = null
	var nearby := get_node_or_null("../RaceMap/Roadbed_Shoulder") as MeshInstance3D
	if nearby != null:
		road_mesh = nearby
	else:
		var road_map := get_tree().get_first_node_in_group("race_map")
		if road_map != null:
			road_mesh = road_map.find_child("Roadbed_Shoulder", true, false) as MeshInstance3D
	if road_mesh == null or road_mesh.mesh == null:
		push_warning("Roadbed_Shoulder mesh is missing; grass response is disabled")
		return

	var faces := road_mesh.mesh.get_faces()
	for face_index in range(0, faces.size(), 3):
		var world_a: Vector3 = road_mesh.global_transform * faces[face_index]
		var world_b: Vector3 = road_mesh.global_transform * faces[face_index + 1]
		var world_c: Vector3 = road_mesh.global_transform * faces[face_index + 2]
		var a := Vector2(world_a.x, world_a.z)
		var b := Vector2(world_b.x, world_b.z)
		var c := Vector2(world_c.x, world_c.z)
		if absf((b - a).cross(c - a)) < 0.0001:
			continue

		var triangle_index := road_triangles.size()
		road_triangles.append(PackedVector2Array([a, b, c]))
		var minimum := Vector2(
			minf(a.x, minf(b.x, c.x)),
			minf(a.y, minf(b.y, c.y))
		)
		var maximum := Vector2(
			maxf(a.x, maxf(b.x, c.x)),
			maxf(a.y, maxf(b.y, c.y))
		)
		var minimum_cell := Vector2i(
			floori(minimum.x / ROAD_GRID_CELL_SIZE),
			floori(minimum.y / ROAD_GRID_CELL_SIZE)
		)
		var maximum_cell := Vector2i(
			floori(maximum.x / ROAD_GRID_CELL_SIZE),
			floori(maximum.y / ROAD_GRID_CELL_SIZE)
		)

		for cell_x in range(minimum_cell.x, maximum_cell.x + 1):
			for cell_y in range(minimum_cell.y, maximum_cell.y + 1):
				var cell := Vector2i(cell_x, cell_y)
				var triangle_indices: Array = road_triangle_grid.get(cell, [])
				triangle_indices.append(triangle_index)
				road_triangle_grid[cell] = triangle_indices

	road_surface_lookup_ready = not road_triangles.is_empty()


func _is_point_on_road(world_position: Vector3) -> bool:
	if not road_surface_lookup_ready:
		return true
	var point := Vector2(world_position.x, world_position.z)
	var cell := Vector2i(
		floori(point.x / ROAD_GRID_CELL_SIZE),
		floori(point.y / ROAD_GRID_CELL_SIZE)
	)
	var triangle_indices: Array = road_triangle_grid.get(cell, [])
	for triangle_index in triangle_indices:
		var triangle: PackedVector2Array = road_triangles[int(triangle_index)]
		if _point_in_triangle(point, triangle[0], triangle[1], triangle[2]):
			return true
	return false


func _point_in_triangle(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := (point.x - b.x) * (a.y - b.y) - (a.x - b.x) * (point.y - b.y)
	var d2 := (point.x - c.x) * (b.y - c.y) - (b.x - c.x) * (point.y - c.y)
	var d3 := (point.x - a.x) * (c.y - a.y) - (c.x - a.x) * (point.y - a.y)
	var has_negative := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var has_positive := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (has_negative and has_positive)


func _apply_grass_drag() -> void:
	if grass_contact_ratio <= 0.0:
		return
	var planar_velocity := linear_velocity.slide(Vector3.UP)
	if planar_velocity.length_squared() < 0.25:
		return
	var drag_force := (
		-planar_velocity.normalized()
		* grass_drag_acceleration
		* mass
		* grass_contact_ratio
	)
	apply_central_force(drag_force)


func _update_automatic_gearbox(throttle: float, delta: float) -> void:
	var forward_speed := linear_velocity.dot(-global_basis.z)
	shift_timer = maxf(shift_timer - delta, 0.0)

	if forward_speed < -0.75:
		current_gear = 1
		var reverse_ratio := clampf(absf(forward_speed) / reverse_speed, 0.0, 1.0)
		var reverse_rpm := lerpf(1200.0, 5200.0, reverse_ratio)
		engine_rpm = move_toward(engine_rpm, reverse_rpm, 12000.0 * delta)
		return

	var speed := maxf(forward_speed, 0.0)
	if shift_timer <= 0.0:
		if current_gear < MAX_FORWARD_GEAR and speed >= UPSHIFT_SPEEDS[current_gear]:
			current_gear += 1
			shift_timer = shift_duration
		elif current_gear > 1 and speed < DOWNSHIFT_SPEEDS[current_gear]:
			current_gear -= 1
			shift_timer = shift_duration

	var rpm_speed_range: Vector2 = GEAR_RPM_SPEED_RANGES[current_gear]
	var rpm_ratio := clampf(
		inverse_lerp(rpm_speed_range.x, rpm_speed_range.y, speed),
		0.0,
		1.0
	)
	var target_rpm := lerpf(1200.0, 6800.0, rpm_ratio)
	if speed < 0.75:
		target_rpm = lerpf(900.0, 1750.0, maxf(throttle, 0.0))
	if shift_timer > 0.0:
		target_rpm = maxf(target_rpm * 0.78, 1100.0)
	engine_rpm = move_toward(engine_rpm, target_rpm, 12000.0 * delta)


func _update_engine_and_brake(throttle: float) -> void:
	var forward_speed := linear_velocity.dot(-global_basis.z)
	brake = 0.0

	if throttle > 0.0:
		var shift_power := 0.30 if shift_timer > 0.0 else 1.0
		var gear_power: float = GEAR_FORCE_MULTIPLIERS[current_gear]
		var surface_power := lerpf(1.0, grass_engine_multiplier, grass_contact_ratio)
		engine_force = -engine_power * gear_power * shift_power * surface_power if forward_speed < max_speed else 0.0
		return

	if throttle < 0.0:
		if forward_speed > 1.0:
			engine_force = 0.0
			brake = brake_power
		elif forward_speed > -reverse_speed:
			var reverse_surface_power := lerpf(1.0, grass_engine_multiplier, grass_contact_ratio)
			engine_force = reverse_engine_power * reverse_surface_power
		else:
			engine_force = 0.0
		return

	engine_force = 0.0
	brake = lerpf(rolling_brake, grass_coast_brake, grass_contact_ratio)


func _update_steering(steering_input: float, delta: float) -> void:
	var speed_ratio := clampf(linear_velocity.length() / max_speed, 0.0, 1.0)
	var steering_ratio := lerpf(1.0, high_speed_steer_ratio, speed_ratio)
	var steering_limit := deg_to_rad(max_steer_angle_degrees) * steering_ratio
	var target_steering := steering_input * steering_limit
	steering = move_toward(steering, target_steering, steering_speed * delta)


func _apply_downforce() -> void:
	if linear_velocity.length_squared() < 1.0:
		return
	apply_central_force(-global_basis.y * downforce * linear_velocity.length())


func _apply_upright_stability() -> void:
	var body_up := global_basis.y.normalized()
	var correction_axis := body_up.cross(Vector3.UP)
	apply_torque(correction_axis * upright_strength)

	# Preserve yaw rotation while damping only roll and pitch movement.
	var yaw_velocity := Vector3.UP * angular_velocity.dot(Vector3.UP)
	var tilt_velocity := angular_velocity - yaw_velocity
	apply_torque(-tilt_velocity * upright_damping)


func _configure_model_wheels() -> void:
	var car_model := get_node_or_null("ConceptCar")
	if car_model == null:
		car_model = get_node_or_null("AE86_2")
	if car_model == null:
		push_error("Vehicle model node is missing; four-wheel physics could not be configured")
		return

	_disable_fake_shadow(car_model)

	for wheel_name in WHEEL_SETTINGS:
		var visual_wheels := _find_visual_wheels(car_model, wheel_name)
		var wheel := get_node_or_null("Wheel%s" % wheel_name) as VehicleWheel3D
		if visual_wheels.is_empty():
			push_error("Missing %s visual wheel in model %s" % [wheel_name, car_model.name])
			continue
		if wheel == null:
			push_error("Missing physics wheel node: Wheel%s" % wheel_name)
			continue

		for visual_wheel in visual_wheels:
			_attach_visual_wheel(visual_wheel, wheel)

		var settings: Dictionary = WHEEL_SETTINGS[wheel_name]
		wheel.position = settings["position"]
		wheel.rotation = Vector3.ZERO
		wheel.scale = Vector3.ONE
		wheel.use_as_steering = bool(settings["steering"])
		wheel.use_as_traction = bool(settings["traction"])
		wheel.wheel_radius = WHEEL_RADIUS
		wheel.wheel_rest_length = 0.18
		wheel.suspension_travel = 0.15
		wheel.suspension_stiffness = 150.0
		wheel.suspension_max_force = 9000.0
		wheel.damping_compression = 2.0
		wheel.damping_relaxation = 2.4
		wheel.wheel_friction_slip = road_tire_grip
		wheel.wheel_roll_influence = 0.02


func _find_visual_wheels(car_model: Node3D, wheel_name: String) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var direct := car_model.find_child(wheel_name, true, false) as Node3D
	if direct != null:
		result.append(direct)
		return result
	for group_name in CONCEPT_WHEEL_MAP.get(wheel_name, []):
		var group := car_model.find_child(group_name, true, false) as Node3D
		if group != null:
			result.append(group)
	return result


func _attach_visual_wheel(visual_wheel: Node3D, wheel: VehicleWheel3D) -> void:
	if visual_wheel is VehicleWheel3D:
		for visual_child in visual_wheel.get_children():
			if visual_child is MeshInstance3D:
				visual_child.reparent(wheel, false)
		visual_wheel.queue_free()
		return

	# ConceptCar-style wheel groups are authored in centimeters with their own
	# scale; the model node's 0.01 scale is lost on reparent, so bake it in.
	visual_wheel.reparent(wheel, false)
	visual_wheel.position = Vector3.ZERO
	visual_wheel.scale = visual_wheel.scale * 0.01


func _disable_fake_shadow(car_model: Node3D) -> void:
	for child in car_model.find_children("*shadow*", "", true, false):
		if child is Node3D:
			child.visible = false


func respawn_car() -> void:
	engine_force = 0.0
	brake = parking_brake
	steering = 0.0
	current_gear = 1
	engine_rpm = 900.0
	shift_timer = 0.0
	grass_contact_ratio = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = spawn_transform
	sleeping = false

	# PhysicsServer3D explicit state reset to guarantee immediate teleport without residual momentum
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, spawn_transform)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)

	reset_physics_interpolation()

```

### race

**player_spawner.gd**
```gdscript
extends MultiplayerSpawner

## 遠端玩家車輛 spawner（佔位）
## EOS 連線啟用後，host 收到新 peer 連線時會透過 spawn_function 生出遠端車。
## 現在單機模式不會觸發（沒有 peer）。

const PLAYER_SCENE := preload("res://player.tscn")


func _ready() -> void:
	spawn_function = _spawn_remote_player


func _spawn_remote_player(data: Variant) -> Node:
	var peer_id: int = int(data.get("peer_id", 1))
	var player := PLAYER_SCENE.instantiate()
	player.name = "Player_%d" % peer_id
	player.set("is_local_player", false)
	var slot: Dictionary = StartGrid.get_slot(maxi(peer_id - 1, 0))
	player.position = slot["position"]
	player.rotation = Vector3(0.0, float(slot["yaw"]), 0.0)
	player.set_multiplayer_authority(peer_id)
	return player

```

**race_ranking.gd**
```gdscript
class_name RaceRanking
extends RefCounted

## 賽事名次（佔位）
## 進度 = 已通過的檢查點數 + 到下一個檢查點的完成比例(0~1)。
## 之後多人模式：每台車由各自 client 回報位置，host 用這份邏輯統一排序。
## 現在單機：RaceManager 每 0.15 秒餵一次本地玩家位置。

signal changed(entries: Array)

var checkpoint_positions: Array[Vector3] = []
var finish_position := Vector3.ZERO
var start_position := Vector3.ZERO
var segment_lengths: Array[float] = []

## car_id -> { "name": String, "next_index": int, "progress": float }
var cars: Dictionary = {}


func setup(positions: Array[Vector3], finish: Vector3, start: Vector3) -> void:
	checkpoint_positions = positions
	finish_position = finish
	start_position = start
	segment_lengths = []
	for i in positions.size():
		var from: Vector3 = positions[i - 1] if i > 0 else start
		segment_lengths.append(maxf(from.distance_to(positions[i]), 0.001))


func register_car(car_id: int, display_name: String) -> void:
	cars[car_id] = {
		"name": display_name,
		"next_index": 0,
		"progress": 0.0,
	}


func update_car(car_id: int, world_position: Vector3) -> void:
	if not cars.has(car_id):
		return
	var car: Dictionary = cars[car_id]
	var total: int = checkpoint_positions.size()
	var next_index: int = car["next_index"]

	if next_index >= total:
		# 已通過全部檢查點，正跑向終點
		if total == 0:
			car["progress"] = 1.0
			return
		var segment_len := maxf(
			checkpoint_positions[total - 1].distance_to(finish_position),
			0.001
		)
		var fraction := 1.0 - clampf(
			world_position.distance_to(finish_position) / segment_len,
			0.0,
			1.0
		)
		car["progress"] = float(total) + fraction
		return

	var target: Vector3 = checkpoint_positions[next_index]
	var remaining_segment_len: float = segment_lengths[next_index]
	var progress_fraction := 1.0 - clampf(
		world_position.distance_to(target) / remaining_segment_len,
		0.0,
		1.0
	)
	car["progress"] = float(next_index) + progress_fraction


func advance_car(car_id: int) -> void:
	if not cars.has(car_id):
		return
	var car: Dictionary = cars[car_id]
	if car["next_index"] < checkpoint_positions.size():
		car["next_index"] += 1


func mark_finished(car_id: int) -> void:
	if not cars.has(car_id):
		return
	cars[car_id]["next_index"] = checkpoint_positions.size()
	cars[car_id]["progress"] = float(checkpoint_positions.size()) + 1.0


func get_ordered() -> Array:
	var entries: Array = []
	for car_id in cars:
		var car: Dictionary = cars[car_id]
		entries.append({
			"car_id": car_id,
			"name": car.get("name", "玩家"),
			"progress": car.get("progress", 0.0),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["progress"] > b["progress"]
	)
	return entries


func emit_changed() -> void:
	changed.emit(get_ordered())

```

**rank_panel.gd**
```gdscript
extends PanelContainer

const MAX_ROWS := 10

const ACCENT := Color(0.1, 0.82, 1.0)
const GOLD := Color(1.0, 0.84, 0.29)
const TEXT_MAIN := Color(0.95, 0.98, 1.0)
const TEXT_MUTED := Color(0.55, 0.66, 0.74)

var _row_labels: Array[Label] = []
var _rows: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var title := Label.new()
	title.text = "即時名次"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", ACCENT)
	vbox.add_child(title)

	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color(0.18, 0.24, 0.31, 1.0))
	vbox.add_child(separator)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	for i in MAX_ROWS:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 19)
		_rows.add_child(label)
		_row_labels.append(label)
	vbox.add_child(_rows)

	margin.add_child(vbox)
	add_child(margin)


func update_entries(entries: Array) -> void:
	for i in _row_labels.size():
		var label := _row_labels[i]
		if i < entries.size():
			var entry: Dictionary = entries[i]
			label.text = "%d. %s" % [i + 1, entry.get("name", "玩家")]
			label.add_theme_color_override("font_color", GOLD if i == 0 else TEXT_MAIN)
		else:
			label.text = ""
			label.add_theme_color_override("font_color", TEXT_MUTED)


func clear_entries() -> void:
	for label in _row_labels:
		label.text = ""


func play_intro() -> void:
	visible = true
	pivot_offset = size * 0.5
	scale = Vector2(0.8, 0.8)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func hide_panel() -> void:
	visible = false

```

**start_grid.gd**
```gdscript
class_name StartGrid
extends RefCounted

## 出發格位（預留位置）
## 12 台車：3 排 x 4 台，座標之後再依賽道微調。
## 單機模式只用 slot 0（也就是原本的出生點）。

const GRID_SLOT_COUNT := 12
const GRID_COLS := 4
const GRID_ROWS := 3

const GRID_CENTER := Vector3(-115.077791, 1.35, 10.5)
const COL_SPACING := 4.0
const ROW_SPACING := 7.0
const GRID_YAW := 0.0


static func get_single_player_slot() -> Dictionary:
	return {
		"index": 0,
		"position": GRID_CENTER,
		"yaw": GRID_YAW,
		"label": "P1",
	}


static func get_slot(slot_index: int, is_single_player: bool = false) -> Dictionary:
	if is_single_player and slot_index == 0:
		return get_single_player_slot()

	slot_index = clampi(slot_index, 0, GRID_SLOT_COUNT - 1)
	@warning_ignore("integer_division")
	var row := slot_index / GRID_COLS
	var col := slot_index % GRID_COLS
	var lateral := (col - (GRID_COLS - 1) * 0.5) * COL_SPACING
	return {
		"index": slot_index,
		"position": Vector3(
			GRID_CENTER.x + lateral,
			GRID_CENTER.y,
			GRID_CENTER.z + row * ROW_SPACING
		),
		"yaw": GRID_YAW,
		"label": "P1" if is_single_player else "P%d" % (slot_index + 1),
	}


static func grid_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for i in GRID_SLOT_COUNT:
		slots.append(get_slot(i))
	return slots


## 依連線順序分配格位：peer_ids[0] -> P1 ... peer_ids[11] -> P12
static func assign_slots(peer_ids: Array) -> Dictionary:
	var assignment := {}
	for i in mini(peer_ids.size(), GRID_SLOT_COUNT):
		assignment[peer_ids[i]] = get_slot(i)
	return assignment

```

## res://

**race_course_setup.gd**
```gdscript
extends Node3D

const TOTAL_CHECKPOINTS: int = 7
const PLAYER_SPAWN_POSITION := Vector3(-115.077791, 1.35, 10.5)
const FINISH_POSITION := Vector3(-115.077791, 1.5, 6.507477)
const FINISH_YAW: float = 3.105172
const GATE_SIZE := Vector3(14.0, 3.0, 4.0)

const CHECKPOINT_SCRIPT := preload("res://check_point_1.gd")
const FINISH_SCRIPT := preload("res://finish.gd")

const CHECKPOINTS := [
	{"position": Vector3(-79.422614, 1.5, -86.009814), "yaw": 1.452350},
	{"position": Vector3(92.437632, 1.5, -72.305016), "yaw": 2.753624},
	{"position": Vector3(-2.679414, 1.5, 49.549295), "yaw": 0.273751},
	{"position": Vector3(94.540360, 1.5, 81.506703), "yaw": 4.264791},
	{"position": Vector3(-37.868606, 1.5, 49.272107), "yaw": 1.712538},
	{"position": Vector3(-58.480451, 1.5, 38.233451), "yaw": -1.013083},
	{"position": Vector3(-97.884251, 1.5, 59.579426), "yaw": 0.011061},
]


func _ready() -> void:
	_remove_test_course()
	_configure_player()
	_create_finish_gate()
	_create_checkpoint_gates()
	_configure_race_manager()
	_setup_ranking()
	_register_groups()


func _register_groups() -> void:
	get_node("RaceMap").add_to_group("race_map")
	get_node("RaceManager").add_to_group("race_manager")


func _remove_test_course() -> void:
	for node_name in [&"Track", &"Finish", &"CheckPoints"]:
		var old_node := get_node_or_null(NodePath(String(node_name)))
		if old_node != null:
			old_node.free()


func _configure_player() -> void:
	var player := get_node("Player") as VehicleBody3D
	var spawn_slot: Dictionary = StartGrid.get_single_player_slot()
	player.position = spawn_slot["position"]
	player.rotation = Vector3(0.0, float(spawn_slot["yaw"]), 0.0)
	player.linear_velocity = Vector3.ZERO
	player.angular_velocity = Vector3.ZERO
	player.spawn_transform = player.global_transform


func _create_finish_gate() -> void:
	var finish := Area3D.new()
	finish.name = "Finish"
	finish.set_script(FINISH_SCRIPT)
	finish.position = FINISH_POSITION
	finish.rotation.y = FINISH_YAW
	finish.collision_layer = 0
	finish.collision_mask = 1
	finish.add_child(_create_gate_shape())
	add_child(finish)


func _create_checkpoint_gates() -> void:
	var checkpoint_root := Node3D.new()
	checkpoint_root.name = "CheckPoints"
	add_child(checkpoint_root)

	for checkpoint_offset in range(CHECKPOINTS.size()):
		var checkpoint_index := checkpoint_offset + 1
		var checkpoint_data: Dictionary = CHECKPOINTS[checkpoint_offset]
		var checkpoint := Area3D.new()
		checkpoint.name = "CheckPoint%d" % checkpoint_index
		checkpoint.set_script(CHECKPOINT_SCRIPT)
		checkpoint.set("checkpoint_index", checkpoint_index)
		checkpoint.position = checkpoint_data["position"]
		checkpoint.rotation.y = float(checkpoint_data["yaw"])
		checkpoint.collision_layer = 0
		checkpoint.collision_mask = 1
		checkpoint.add_child(_create_gate_shape())
		checkpoint_root.add_child(checkpoint)


func _create_gate_shape() -> CollisionShape3D:
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var box_shape := BoxShape3D.new()
	box_shape.size = GATE_SIZE
	collision_shape.shape = box_shape
	return collision_shape


func _configure_race_manager() -> void:
	var race_manager := get_node("RaceManager")
	race_manager.set("total_checkpoints", TOTAL_CHECKPOINTS)
	var time_trial_hud := get_node("UI/HUD")
	time_trial_hud.reset(TOTAL_CHECKPOINTS)


func _setup_ranking() -> void:
	var race_manager := get_node("RaceManager")
	var checkpoint_positions: Array[Vector3] = []
	for checkpoint_data: Dictionary in CHECKPOINTS:
		checkpoint_positions.append(checkpoint_data["position"])
	race_manager.setup_ranking(
		checkpoint_positions,
		FINISH_POSITION,
		StartGrid.get_single_player_slot()["position"]
	)

```

**race_manager.gd**
```gdscript
extends Node

const SAVE_PATH: String = "user://race_scores.cfg"

signal race_active_changed(active: bool)

@onready var player: VehicleBody3D = $"../Player"
@onready var time_trial_hud = $"../UI/HUD"
@onready var countdown = $"../UI/CountdownCenter"
@onready var start_screen = $"../UI/StartCenter"
@onready var finish_screen = $"../UI/FinishCenter"
@onready var leaderboard_ui = $"../UI/LeaderboardPanel"
@onready var rank_panel: PanelContainer = $"../UI/RankPanel"
@export var total_checkpoints: int = 2

const RANKING_UPDATE_INTERVAL: float = 0.15

var ranking := RaceRanking.new()
var ranking_update_accum: float = 0.0

var player_name: String = ""
var waiting_for_player: bool = true
var best_time: float = -1.0
var race_started: bool = false
var countdown_time: float = 3.0
var go_display_time: float = 0.0

var next_checkpoint: int = 1
var race_time: float = 0.0
var race_finished: bool = false

var _race_active := false

func restart_race() -> void:
	if player:
		player.respawn_car()

	race_time = 0.0
	race_finished = false
	race_started = false

	next_checkpoint = 1

	countdown_time = 3.0
	go_display_time = 0.0

	time_trial_hud.reset(total_checkpoints)
	countdown.reset()

	finish_screen.hide_results()

func _process(delta: float) -> void:
	var race_active := not waiting_for_player
	if race_active != _race_active:
		_race_active = race_active
		race_active_changed.emit(race_active)
	time_trial_hud.set_waiting(waiting_for_player)
	leaderboard_ui.set_waiting(waiting_for_player)
	if waiting_for_player:
		return

	update_start_countdown(delta)

	if not race_started or race_finished:
		return

	race_time += delta
	time_trial_hud.set_time(race_time)

	ranking_update_accum += delta
	if ranking_update_accum >= RANKING_UPDATE_INTERVAL:
		ranking_update_accum = 0.0
		ranking.update_car(1, player.global_position)
		ranking.emit_changed()

func _ready() -> void:
	load_best_time()
	refresh_best_time_label()

	start_screen.start_requested.connect(_on_start_requested)
	start_screen.show_for_waiting()

	finish_screen.next_player_requested.connect(prepare_next_player)
	finish_screen.home_requested.connect(_on_home_requested)

	countdown.clear()

	rank_panel.hide_panel()
	finish_screen.hide_results()

func setup_ranking(
	checkpoint_positions: Array,
	finish_position: Vector3,
	start_position: Vector3
) -> void:
	ranking.setup(checkpoint_positions, finish_position, start_position)
	ranking.register_car(1, "玩家")
	ranking.changed.connect(rank_panel.update_entries)

func _on_start_requested(entered_name: String) -> void:
	if entered_name.is_empty():
		start_screen.show_name_error("名字不能空白")
		return
	start_race(entered_name)


func start_race(player_name: String) -> void:
	self.player_name = player_name
	waiting_for_player = false

	start_screen.hide_for_race()

	restart_race()

	# HUD Pop In
	time_trial_hud.play_intro()

	ranking.cars[1]["name"] = player_name
	ranking.emit_changed()
	rank_panel.play_intro()

func finish_race() -> void:
	if race_finished:
		return

	if next_checkpoint <= total_checkpoints:
		print("還沒有通過所有檢查點！")
		return

	race_finished = true

	ranking.mark_finished(1)
	ranking.emit_changed()

	leaderboard_ui.register_score(player_name, race_time)

	# 提交到 EOS 公開排行榜（毫秒）
	leaderboard_ui.submit_public(race_time)

	time_trial_hud.set_time(race_time)

	var is_new_record := best_time < 0.0 or race_time < best_time

	if is_new_record:
		best_time = race_time

		save_best_time()
		refresh_best_time_label()

	finish_screen.show_results(race_time, is_new_record)

func register_checkpoint(checkpoint_index: int) -> void:
	if race_finished:
		return

	if checkpoint_index != next_checkpoint:
		print("檢查點順序錯誤")
		return

	next_checkpoint += 1
	time_trial_hud.set_checkpoint(checkpoint_index, total_checkpoints)

	ranking.advance_car(1)
	ranking.emit_changed()

	print(
		"通過檢查點：",
		checkpoint_index,
		"/",
		total_checkpoints
	)

func update_start_countdown(delta: float) -> void:
	if not race_started:
		countdown_time -= delta

		if countdown_time > 0.0:
			countdown.set_text(str(ceili(countdown_time)), Color.WHITE)
		else:
			race_started = true
			countdown.set_text("GO!", Color(0.15, 1.0, 0.4))
			go_display_time = 1.0

		return

	if go_display_time > 0.0:
		go_display_time -= delta

		if go_display_time <= 0.0:
			countdown.set_text("", Color.WHITE)

func load_best_time() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)

	if error != OK:
		return

	best_time = float(
		config.get_value("scores", "best_time", -1.0)
	)

func save_best_time() -> void:
	var config := ConfigFile.new()

	# 避免儲存最佳成績時清掉排行榜
	config.load(SAVE_PATH)

	config.set_value(
		"scores",
		"best_time",
		best_time
	)

	var error := config.save(SAVE_PATH)

	if error != OK:
		push_error("無法儲存最佳成績")

func refresh_best_time_label() -> void:
	time_trial_hud.set_best_time(best_time)

func prepare_next_player() -> void:
	player.respawn_car()

	player_name = ""
	start_screen.clear_name()

	waiting_for_player = true
	race_started = false
	race_finished = false

	race_time = 0.0
	next_checkpoint = 1

	countdown_time = 3.0
	go_display_time = 0.0

	time_trial_hud.reset(total_checkpoints)
	countdown.clear()

	finish_screen.hide_results()
	leaderboard_ui.set_waiting(true)
	start_screen.show_for_waiting()

	if ranking.cars.has(1):
		ranking.cars[1]["next_index"] = 0
		ranking.cars[1]["progress"] = 0.0
		rank_panel.clear_entries()
	rank_panel.hide_panel()

func _on_home_requested() -> void:
	get_tree().change_scene_to_file("res://ui/lobby.tscn")

```

### scripts

**grass_manager.gd**
```gdscript
extends MultiMeshInstance3D

## GrassManager.gd
## Manages large-scale grass rendering using MultiMeshInstance3D.
## Features:
## - Procedural grass placement on the terrain
## - Wind animation via the grass shader
## - Vehicle interaction (bending away from the car)

@export var placement_area: Vector2 = Vector2(80, 80)
@export var max_instances: int = 20000
@export var grass_mesh: Mesh = null
@export var grass_material: ShaderMaterial = null
@export var grass_height: float = 0.5
@export var interaction_radius: float = 4.0
@export var interaction_strength: float = 1.0

var instances_placed: int = 0
var _vehicle: Node3D = null
var _time: float = 0.0


func _ready() -> void:
	_find_vehicle()
	_setup_multimesh()
	if multimesh != null and multimesh.mesh != null:
		_place_grass()


func _find_vehicle() -> void:
	if get_tree() == null:
		return
	var root := get_tree().current_scene
	if root == null:
		return
	_vehicle = root.get_node_or_null("Player") as Node3D


func _setup_multimesh() -> void:
	if grass_mesh == null:
		push_error("GrassManager: grass_mesh not assigned")
		return
	if grass_material == null:
		push_error("GrassManager: grass_material not assigned")
		return

	var mm := MultiMesh.new()
	mm.mesh = grass_mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	multimesh = mm
	## MultiMesh has no material_override; apply the shader to the blade mesh
	## via its surface 0 material slot.
	if grass_mesh.get_surface_count() > 0:
		grass_mesh.surface_set_material(0, grass_material)


func _place_grass() -> void:
	if multimesh == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var transforms: Array[Transform3D] = []
	transforms.resize(max_instances)
	var count := 0
	var half_w := placement_area.x * 0.5
	var half_h := placement_area.y * 0.5

	while count < max_instances:
		var local_x := rng.randf_range(-half_w, half_w)
		var local_z := rng.randf_range(-half_h, half_h)
		## Ray-cast in world space from above the emitter.
		var origin := to_global(Vector3(local_x, 100.0, local_z))
		var ground_y := _get_ground_height(origin)
		if ground_y == -100.0:
			continue
		## Place in local space so the emitter's transform applies normally.
		var local_pos := to_local(Vector3(origin.x, ground_y, origin.z))
		var rot := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		var scale := rng.randf_range(0.7, 1.3)
		var blade_center_y := local_pos.y + grass_height * 0.5
		transforms[count] = Transform3D(rot, Vector3(local_pos.x, blade_center_y, local_pos.z)).scaled_local(Vector3(scale, scale, scale))
		count += 1

	instances_placed = count
	multimesh.instance_count = count
	for i in count:
		multimesh.set_instance_transform(i, transforms[i])
	print("GrassManager: placed %d instances" % count)


func _get_ground_height(origin: Vector3) -> float:
	if get_world_3d() == null:
		return -100.0
	var space := get_world_3d().direct_space_state
	if space == null:
		return -100.0
	var params := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 200.0)
	params.collision_mask = 1
	var result := space.intersect_ray(params)
	if result.is_empty():
		return -100.0
	return result["position"].y


func _process(delta: float) -> void:
	if multimesh == null or grass_material == null:
		return
	_time += delta
	grass_material.set_shader_parameter("anim_time", _time)
	grass_material.set_shader_parameter("grass_height", grass_height)
	grass_material.set_shader_parameter("interaction_radius", interaction_radius)
	grass_material.set_shader_parameter("interaction_strength", interaction_strength)

	var env: Node = get_node_or_null("/root/EnvironmentManager")
	if env != null:
		grass_material.set_shader_parameter("wind_direction", env.get("wind_direction"))
		grass_material.set_shader_parameter("wind_speed", env.get("wind_speed"))

	if _vehicle == null:
		_find_vehicle()
	if _vehicle != null:
		grass_material.set_shader_parameter("vehicle_position", _vehicle.global_position)


func set_grass_parameters(density: float, height: float, _width: float) -> void:
	grass_height = height
	if multimesh != null and multimesh.mesh != null:
		var target := int(density * placement_area.x * placement_area.y)
		max_instances = clampi(target, 100, 60000)
		_place_grass()


func update_wind(wind_dir: Vector3, wind_spd: float) -> void:
	if grass_material != null:
		grass_material.set_shader_parameter("wind_direction", wind_dir)
		grass_material.set_shader_parameter("wind_speed", wind_spd)

```

**water_animator.gd**
```gdscript
extends Node

## WaterAnimator.gd
## Assigns the Gerstner water shader materials to all water surfaces at startup
## (the map is a GLB import, so its water nodes cannot be edited in main.tscn),
## then drives the shared `anim_time` parameter every frame.

@export var ocean_material: ShaderMaterial = null
@export var pond_material: ShaderMaterial = null

var _time: float = 0.0
var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	_apply_materials_to_water_nodes()


func _process(delta: float) -> void:
	_time += delta
	for mat in _materials:
		if mat != null:
			mat.set_shader_parameter("anim_time", _time)


func _apply_materials_to_water_nodes() -> void:
	var root := get_tree().current_scene if get_tree() != null else null
	if root == null:
		return
	var race_map := root.get_node_or_null("RaceMap")
	if race_map == null:
		push_warning("WaterAnimator: RaceMap not found; water materials not applied")
		return

	## Direct water surfaces by node name.
	var ocean := race_map.get_node_or_null("Ocean_Base") as MeshInstance3D
	var pond_large := race_map.get_node_or_null("Garden_Pond_Large") as MeshInstance3D
	var pond_small := race_map.get_node_or_null("Garden_Pond_Small") as MeshInstance3D
	var pond_deep := race_map.get_node_or_null("Pond_Water_Detail_Deep") as MeshInstance3D
	var fountain := race_map.get_node_or_null("BLDG_01_Central_Fountain_ROOT/Fountain_Water") as MeshInstance3D

	if ocean_material == null:
		ocean_material = load("res://materials/water_ocean.tres") as ShaderMaterial
	if pond_material == null:
		pond_material = load("res://materials/water_pond.tres") as ShaderMaterial

	_assign(ocean, ocean_material)
	_assign(pond_large, pond_material)
	_assign(pond_small, pond_material)
	_assign(pond_deep, pond_material)
	_assign(fountain, pond_material)


func _assign(mi: MeshInstance3D, mat: ShaderMaterial) -> void:
	if mi == null or mat == null:
		return
	mi.material_override = mat
	if not _materials.has(mat):
		_materials.append(mat)

```

**water_surface.gd**
```gdscript
extends Node

## WaterSurface.gd
## Drives the Gerstner wave shader on a water MeshInstance3D.
## Uses EnvironmentManager for global wind/time where available.

@export var water_mesh: MeshInstance3D = null
@export var auto_animate: bool = true

var _time: float = 0.0


func _ready() -> void:
	if water_mesh == null:
		water_mesh = get_node_or_null("MeshInstance3D") as MeshInstance3D
	_update_initial_params()


func _process(delta: float) -> void:
	if not auto_animate or water_mesh == null:
		return
	_time += delta
	_set_shader_param("anim_time", _time)


func _update_initial_params() -> void:
	if water_mesh == null:
		return
	var env: Node = get_node_or_null("/root/EnvironmentManager")
	if env != null:
		var dir: Vector3 = env.get("wind_direction")
		_set_shader_param("wave_direction", Vector2(dir.x, dir.z))


func _set_shader_param(param: String, value: Variant) -> void:
	if water_mesh == null:
		return
	var mat := water_mesh.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(param, value)


func set_wave_params(wave_speed: float, wave_height: float, wave_length: float) -> void:
	_set_shader_param("wave_speed", wave_speed)
	_set_shader_param("wave_height", wave_height)
	_set_shader_param("wave_length", wave_length)


func set_water_color(color: Color) -> void:
	_set_shader_param("water_color", color)


func set_depth_fade(start: float, end: float) -> void:
	_set_shader_param("depth_fade_start", start)
	_set_shader_param("depth_fade_end", end)


func update_environment_params(wind_direction: Vector3, _wind_speed: float) -> void:
	_set_shader_param("wave_direction", Vector2(wind_direction.x, wind_direction.z))

```

**weather_follow.gd**
```gdscript
extends GPUParticles3D

## WeatherFollow.gd
## Keeps weather emitters above the player camera so precipitation always
## surrounds the car, even as it races across the map.

@export var target_node_path: NodePath = "../Player/Camera3D"
@export var vertical_offset: float = 18.0


func _process(_delta: float) -> void:
	var target := get_node_or_null(target_node_path) as Node3D
	if target == null:
		return
	var pos := target.global_position
	pos.y += vertical_offset
	global_position = pos

```

### ui

**lobby_ui.gd**
```gdscript
extends Control

## 主頁大廳 UI — 移植自 lobby_v4.html 的互動邏輯。
## 純單人時：左側改車/車庫、聊天、房間設定皆為本機互動；
## 已透過 EOS 開房/入房時：玩家名單、就緒狀態、開始比賽接到 LobbyManager。

const REF := Vector2(1280, 720)

const C_BG := Color("#0f131c")
const C_PANEL := Color("#151c2b")
const C_PANEL_A := Color(0.059, 0.086, 0.133, 0.75)
const C_ACCENT := Color("#38bdf8")
const C_SELF := Color("#10b981")
const C_AMBER := Color("#f59e0b")
const C_MUTED := Color("#8b9bb4")
const C_WHITE := Color("#ffffff")
const C_BORDER := Color(0.545, 0.608, 0.706, 0.18)
const C_WIN := Color("#4ade80")
const C_LOSS := Color("#475569")

var selected_id := ""
var chat_open := false
var chat_tab := "room"
var room_overlay_open := false
var customize_view := false
var is_ready := false
# Lobby 狀態
var browser_open := false
var browser_busy := false
var browser_results: Array = []

var room_config := {
	"name": "abc's room",
	"map": "東京灣夜景",
	"mode": "經典競速",
	"privacy": "public",
	"max_players": 3,
	"car_restriction": "全開放",
	"damage_mode": "輕度",
	"auto_start": "倒數10秒",
	"spectator": true,
	"invite_code": "XKQR-7721",
}

var players: Array = []
var chat_messages: Array = []
var slot_buttons: Array = []

var user_card_btn: Button
var user_card_name: Label
var user_card_puid: Label
var room_btn: Button
var room_name_label: Label
var room_count_label: Label
var chat_trigger_btn: Button
var ready_btn: Button
var ready_sub: Label
var search_btn: Button
var leave_lobby_btn: Button

var insp_selected: Label
var insp_car: Label
var insp_score: Label
var insp_class: Label
var customize_btn: Button
var insp_rank: Label
var insp_lap: Label
var insp_dots: Array = []
var insp_bars: Array = []

var chat_root: Control
var chat_msgs_root: Control
var chat_input: LineEdit
var tab_btns: Dictionary = {}

var overlay_root: Control
var overlay_panel: Panel
var overlay_input: LineEdit
var overlay_invite: Label
var chips: Array = []
var spectator_btn: Button
var create_room_btn: Button
var leave_room_btn: Button

# Browser
var browser_root: Control
var browser_list: Control
var browser_status: Label

var customize_root: Control

var toast_panel: Panel
var toast_label: Label
var toast_tween: Tween


func _net() -> Variant:
	return get_node_or_null("/root/NetworkManager")


func _lobby() -> Variant:
	return get_node_or_null("/root/LobbyManager")


# ==========================================================================
# 生命週期
# ==========================================================================

func _ready() -> void:
	_build_header()
	_build_inspector()
	_build_chat_trigger()
	_build_showcase()
	_build_start_button()
	_build_chat_window()
	_build_overlay()
	_build_customize()
	_build_hint()
	_build_toast()
	_connect_network()
	_sync_players()
	_refresh()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, REF), C_BG, true)
	# 透視背景線（沿用 HTML 的消失點做法）
	var vx := REF.x * 0.65
	var vy := REF.y * 0.4
	var grid := Color(0.545, 0.608, 0.706, 0.04)
	for i in range(-400, 1700, 70):
		draw_line(Vector2(i, REF.y), Vector2(vx + (i - vx) * 0.15, vy), grid, 1.0)
	if not customize_view and not room_overlay_open:
		for i in players.size():
			_draw_slot(_slot_cx(i), 420.0, players[i])
	if customize_view:
		_draw_customize_decor()


func _draw_slot(cx: float, cy: float, p: Dictionary) -> void:
	var sel: bool = selected_id == str(p["id"])
	var accent: Color = C_SELF if p["is_self"] else C_ACCENT
	var n := 64
	var pts := PackedVector2Array()
	for a in range(n):
		var ang := TAU * float(a) / float(n)
		pts.append(Vector2(cx + 140.0 * cos(ang), cy + 45.0 * sin(ang)))
	var fill: Color = Color(0.082, 0.125, 0.196, 0.6) if not p["is_self"] else Color(0.062, 0.724, 0.508, 0.12)
	draw_polygon(pts, PackedColorArray([fill]))
	draw_polyline(pts, accent, 2.0 if not sel else 3.5)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.059, 0.086, 0.133, 0.88)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1 if not sel else 2)
	sb.border_color = accent
	draw_style_box(sb, Rect2(cx - 90, cy - 95, 180, 85))

	var font := get_theme_default_font()
	var car_text := "Car"
	var car_size := font.get_string_size(car_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	draw_string(font, Vector2(cx - car_size.x * 0.5, cy - 44), car_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, C_WHITE)

	draw_line(Vector2(cx - 100, cy + 68), Vector2(cx + 100, cy + 68), accent, 2.0)

	var name_text: String = "You" if p["is_self"] else str(p["name"])
	var ns := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	draw_string(font, Vector2(cx - ns.x * 0.5, cy + 102), name_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, accent)


func _draw_customize_decor() -> void:
	var n := 64
	var pts := PackedVector2Array()
	for a in range(n):
		var ang := TAU * float(a) / float(n)
		pts.append(Vector2(640.0 + 260.0 * cos(ang), 440.0 + 80.0 * sin(ang)))
	draw_polygon(pts, PackedColorArray([Color(0.062, 0.724, 0.508, 0.08)]))
	draw_polyline(pts, C_SELF, 2.0)


# ==========================================================================
# 建構 UI
# ==========================================================================

func _build_header() -> void:
	# 左上玩家卡（可點擊 → 登入 / 顯示登入狀態）
	user_card_btn = _btn(self, "", Rect2(30, 20, 230, 65), 1, C_WHITE,
			Color(0.082, 0.11, 0.169, 0.65), C_BORDER, 10, 1)
	user_card_btn.pressed.connect(_on_user_card_pressed)
	user_card_name = _label(user_card_btn, _display_name(), Vector2(20, 10), 18, C_WHITE)
	user_card_puid = _label(user_card_btn, _puid_text(), Vector2(20, 36), 12, C_MUTED)

	# 中央房間卡（點擊開房間設定）
	var c2w := 360.0
	var c2x := REF.x / 2.0 - c2w / 2.0
	room_btn = _btn(self, "", Rect2(c2x, 20, c2w, 65), 1, C_WHITE,
			Color(0.082, 0.11, 0.169, 0.65), C_ACCENT, 10, 1.3)
	room_btn.pressed.connect(_on_room_pressed)
	_label(room_btn, "ROOM", Vector2(24, 4), 10, C_MUTED)
	room_name_label = _label(room_btn, room_config["name"], Vector2(24, 24), 17, C_WHITE)
	room_count_label = _label(room_btn, " · 2/3", Vector2(24, 25), 15, C_ACCENT)
	var gear := _btn(room_btn, "⚙", Rect2(c2w - 40, 18, 26, 26), 13, C_ACCENT,
			Color(0.06, 0.2, 0.31, 0.5), Color(0.55, 0.75, 1, 0.3), 6, 1)
	gear.pressed.connect(_on_room_pressed)

	# 右側：搜尋房間 / 離開房間
	search_btn = _btn(self, "🔍 搜尋", Rect2(880, 28, 100, 34), 14, C_ACCENT,
			Color(0.22, 0.74, 0.97, 0.15), C_ACCENT, 8, 1)
	search_btn.pressed.connect(_on_search_pressed)
	leave_lobby_btn = _btn(self, "✕ 離開", Rect2(990, 28, 100, 34), 14, C_MUTED,
			Color(1, 1, 1, 0.04), C_BORDER, 8, 1)
	leave_lobby_btn.pressed.connect(_on_leave_lobby_pressed)
	leave_lobby_btn.visible = false


func _build_inspector() -> void:
	var p := _panel(self, Rect2(30, 100, 320, 480), C_PANEL_A, C_BORDER, 12, 1)
	insp_selected = _label(p, "SELECTED CAR", Vector2(24, 22), 11, C_MUTED)
	insp_car = _label(p, "…", Vector2(24, 46), 22, C_WHITE)

	_panel(p, Rect2(24, 78, 60, 24), Color(0.22, 0.74, 0.97, 0.2), Color.TRANSPARENT, 5, 0)
	insp_score = _label(p, "1520", Vector2(24, 78), 13, C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER, 60)
	_panel(p, Rect2(90, 78, 30, 24), Color(0.96, 0.62, 0.04, 0.25), Color.TRANSPARENT, 5, 0)
	insp_class = _label(p, "S", Vector2(90, 78), 13, C_AMBER, HORIZONTAL_ALIGNMENT_CENTER, 30)
	customize_btn = _btn(p, "🛠 改車 / 車庫 →", Rect2(130, 78, 150, 24), 12, C_SELF,
			Color(0.062, 0.724, 0.508, 0.25), C_SELF, 5, 1)
	customize_btn.pressed.connect(_on_customize_pressed)

	_panel(p, Rect2(24, 114, 272, 1), Color(0.545, 0.608, 0.706, 0.18), Color.TRANSPARENT, 0, 0)
	_label(p, "段位", Vector2(24, 136), 13, C_MUTED)
	insp_rank = _label(p, "…", Vector2(105, 136), 14, C_WHITE)
	_label(p, "最佳單圈", Vector2(24, 162), 13, C_MUTED)
	insp_lap = _label(p, "…", Vector2(105, 162), 14, C_ACCENT)
	_label(p, "近5場", Vector2(24, 188), 13, C_MUTED)
	for i in range(5):
		insp_dots.append(_dot(p, Vector2(105 + i * 18, 184), 5, C_LOSS))

	_panel(p, Rect2(24, 208, 272, 1), Color(0.545, 0.608, 0.706, 0.18), Color.TRANSPARENT, 0, 0)
	_label(p, "車輛性能概要", Vector2(24, 230), 11, C_MUTED)
	var rows := ["極速", "操控", "加速"]
	for i in rows.size():
		var y := 252.0 + i * 22.0
		_label(p, rows[i], Vector2(24, y - 4), 12, C_MUTED)
		insp_bars.append(_bar(p, Vector2(70, y), 200, 8, 0.0, C_ACCENT))

	_panel(p, Rect2(24, 322, 272, 1), Color(0.545, 0.608, 0.706, 0.18), Color.TRANSPARENT, 0, 0)
	_label(p, "⋮ 詳細戰績（總場次 / 排名 / 歷史成績）", Vector2(24, 344), 11, C_MUTED)


func _build_chat_trigger() -> void:
	chat_trigger_btn = _btn(self, "💬 點擊輸入訊息…", Rect2(30, 596, 320, 56), 13, C_MUTED,
			Color(0.059, 0.086, 0.133, 0.75), C_BORDER, 10, 1, 18.0)
	chat_trigger_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	chat_trigger_btn.pressed.connect(_on_chat_trigger_pressed)


func _build_showcase() -> void:
	var layer := Control.new()
	layer.name = "SlotLayer"
	layer.position = Vector2.ZERO
	layer.size = REF
	add_child(layer)
	_rebuild_slot_buttons(layer)


func _rebuild_slot_buttons(layer: Control) -> void:
	for b in slot_buttons:
		if is_instance_valid(b):
			b.queue_free()
	slot_buttons.clear()
	for i in players.size():
		var b := _btn(layer, "", _slot_rect(i), 1, Color.TRANSPARENT,
				Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
		b.pressed.connect(_on_slot_pressed.bind(i))
		slot_buttons.append(b)


func _slot_cx(i: int) -> float:
	var positions := [660.0, 1000.0, 400.0, 820.0]
	return positions[i % positions.size()]


func _slot_rect(i: int) -> Rect2:
	return Rect2(_slot_cx(i) - 100, 315, 200, 280)


func _build_start_button() -> void:
	ready_btn = _btn(self, "▶  開始計時賽", Rect2(1030, 620, 220, 60), 20, C_WHITE,
			Color(0.062, 0.724, 0.508, 0.95), C_SELF, 12, 2)
	ready_btn.pressed.connect(_on_start_pressed)
	ready_sub = _label(ready_btn, "單人模式 · 進入賽道", Vector2(0, 36), 11,
			Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 220)


func _build_chat_window() -> void:
	chat_root = Control.new()
	chat_root.name = "FloatingChat"
	chat_root.position = Vector2(30, 146)
	chat_root.size = Vector2(380, 440)
	chat_root.visible = false
	add_child(chat_root)

	_panel(chat_root, Rect2(0, 0, 380, 440), Color(0.04, 0.06, 0.1, 0.98), C_ACCENT, 14, 1.5)
	_label(chat_root, "聊天", Vector2(20, 10), 15, C_WHITE)
	var close := _btn(chat_root, "✕", Rect2(380 - 38, 14, 26, 26), 16, C_MUTED,
			Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
	close.pressed.connect(_on_chat_close_pressed)

	var tabs := [["room", "房間"], ["team", "隊伍"], ["global", "全域"]]
	var tw := (380.0 - 40.0) / 3.0
	for i in tabs.size():
		var b := _btn(chat_root, tabs[i][1], Rect2(20 + i * tw, 46, tw - 6, 28), 12,
				C_MUTED, Color(1, 1, 1, 0.04), Color(0.545, 0.608, 0.706, 0.18), 6, 1)
		b.pressed.connect(_on_tab_pressed.bind(tabs[i][0]))
		tab_btns[tabs[i][0]] = b

	chat_msgs_root = Control.new()
	chat_msgs_root.position = Vector2(20, 92)
	chat_msgs_root.size = Vector2(340, 250)
	chat_root.add_child(chat_msgs_root)

	chat_input = LineEdit.new()
	chat_input.position = Vector2(16, 440 - 52)
	chat_input.size = Vector2(348, 36)
	chat_input.placeholder_text = "輸入訊息…"
	chat_input.text_submitted.connect(_on_chat_sent)
	chat_root.add_child(chat_input)


func _build_overlay() -> void:
	overlay_root = Control.new()
	overlay_root.name = "RoomOverlay"
	overlay_root.position = Vector2.ZERO
	overlay_root.size = REF
	overlay_root.visible = false
	add_child(overlay_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.031, 0.059, 0.85)
	dim.position = Vector2.ZERO
	dim.size = REF
	overlay_root.add_child(dim)

	overlay_panel = _panel(overlay_root, Rect2(320, 30, 640, 660), Color("#131b29"), C_ACCENT, 12, 1.5)
	_label(overlay_panel, "房間設定", Vector2(0, 26), 20, C_WHITE, HORIZONTAL_ALIGNMENT_CENTER, 640)

	# 房間名稱
	_label(overlay_panel, "房間名稱", Vector2(36, 74), 13, C_MUTED)
	overlay_input = LineEdit.new()
	overlay_input.position = Vector2(150, 66)
	overlay_input.size = Vector2(300, 30)
	overlay_input.placeholder_text = "輸入房間名稱…"
	overlay_panel.add_child(overlay_input)

	# 比賽設定
	_ov_divider(overlay_panel, 116, "比賽設定")
	_ov_chip_row(overlay_panel, "地圖", "map", 158, ["東京灣夜景", "阿爾卑斯山道", "城市街道"], 120)
	_ov_chip_row(overlay_panel, "模式", "mode", 200, ["經典競速", "淘汰賽", "計時挑戰"], 110)
	_ov_chip_row(overlay_panel, "最大人數", "maxp", 242, ["2人", "3人", "4人"], 60)
	_ov_chip_row(overlay_panel, "隱私設定", "privacy", 284, ["公開", "私人", "好友"], 80)

	# 進階規則
	_ov_divider(overlay_panel, 328, "進階規則")
	_ov_chip_row(overlay_panel, "車輛限制", "carr", 370, ["全開放", "僅S級", "僅A級"], 80)
	_ov_chip_row(overlay_panel, "傷害模式", "dmg", 412, ["關閉", "輕度", "完整"], 80)
	_ov_chip_row(overlay_panel, "自動開始", "auto", 454, ["立即開始", "倒數10秒"], 120)

	# 觀戰席
	_label(overlay_panel, "觀戰席", Vector2(36, 502), 13, C_MUTED)
	spectator_btn = _btn(overlay_panel, "● 開啟", Rect2(150, 494, 64, 28), 12, C_SELF,
			Color(0.062, 0.724, 0.508, 0.25), C_SELF, 13, 1)
	spectator_btn.pressed.connect(_on_spectator_pressed)

	# 邀請
	_ov_divider(overlay_panel, 540, "邀請")
	_label(overlay_panel, "邀請碼", Vector2(36, 586), 13, C_MUTED)
	var code_box := _panel(overlay_panel, Rect2(150, 578, 160, 28), Color(0, 0, 0, 0.3), C_BORDER, 6, 1)
	overlay_invite = _label(code_box, room_config["invite_code"], Vector2(14, 0), 13, C_ACCENT,
			HORIZONTAL_ALIGNMENT_LEFT, 160)
	var copy := _btn(overlay_panel, "📋 複製", Rect2(320, 578, 80, 28), 12, C_WHITE,
			Color(1, 1, 1, 0.04), C_BORDER, 6, 1)
	copy.pressed.connect(_on_copy_invite_pressed)

	# 取消 / 儲存
	var cancel := _btn(overlay_panel, "取消", Rect2(640 - 190, 616, 70, 34), 14, C_MUTED,
			Color(1, 1, 1, 0.04), C_BORDER, 6, 1)
	cancel.pressed.connect(_on_cancel_overlay)
	var save := _btn(overlay_panel, "儲存", Rect2(640 - 105, 616, 70, 34), 14, Color("#0f172a"),
			C_ACCENT, Color.TRANSPARENT, 6, 1)
	save.pressed.connect(_on_save_overlay)

	# 開房 / 離開房間（依 lobby 狀態顯示）
	create_room_btn = _btn(overlay_panel, "開房", Rect2(640 - 280, 616, 70, 34), 14, Color("#0f172a"),
			C_ACCENT, Color.TRANSPARENT, 6, 1)
	create_room_btn.pressed.connect(_on_create_room_pressed)
	leave_room_btn = _btn(overlay_panel, "離開", Rect2(640 - 190, 616, 70, 34), 14, C_MUTED,
			Color(1, 1, 1, 0.04), C_BORDER, 6, 1)
	leave_room_btn.pressed.connect(_on_leave_room_pressed)


func _build_browser() -> void:
	browser_root = Control.new()
	browser_root.name = "LobbyBrowser"
	browser_root.position = Vector2.ZERO
	browser_root.size = REF
	browser_root.visible = false
	add_child(browser_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.031, 0.059, 0.85)
	dim.position = Vector2.ZERO
	dim.size = REF
	browser_root.add_child(dim)

	var panel := _panel(browser_root, Rect2(320, 40, 640, 640), Color("#131b29"), C_ACCENT, 12, 1.5)
	_label(panel, "搜尋房間", Vector2(0, 26), 20, C_WHITE, HORIZONTAL_ALIGNMENT_CENTER, 640)
	var close := _btn(panel, "✕", Rect2(640 - 40, 14, 26, 26), 16, C_MUTED,
			Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
	close.pressed.connect(func(): _open_browser(false))

	var refresh := _btn(panel, "⟳ 重新搜尋", Rect2(36, 60, 120, 30), 12, C_ACCENT,
			Color(0.22, 0.74, 0.97, 0.15), C_ACCENT, 6, 1)
	refresh.pressed.connect(_on_search_pressed)

	browser_list = Control.new()
	browser_list.position = Vector2(36, 104)
	browser_list.size = Vector2(568, 520)
	panel.add_child(browser_list)

	browser_status = _label(panel, "點擊「重新搜尋」尋找公開房間", Vector2(36, 400), 14, C_MUTED,
			HORIZONTAL_ALIGNMENT_CENTER, 568)


func _ov_divider(parent: Node, y: float, label: String) -> void:
	_panel(parent, Rect2(36, y, 568, 1), Color(0.545, 0.608, 0.706, 0.18), Color.TRANSPARENT, 0, 0)
	_label(parent, label, Vector2(36, y + 18), 11, C_ACCENT)


func _ov_chip_row(parent: Node, label: String, row: String, y: float, values: Array, chip_w: float) -> void:
	_label(parent, label, Vector2(36, y + 8), 13, C_MUTED)
	for i in values.size():
		var pos := Vector2(150 + i * (chip_w + 8), y)
		var b := _btn(parent, values[i], Rect2(pos, Vector2(chip_w, 28)), 12, C_MUTED,
				Color(1, 1, 1, 0.03), C_BORDER, 6, 1)
		b.pressed.connect(_on_chip_pressed.bind(row, values[i]))
		chips.append({"btn": b, "row": row, "value": values[i]})


func _build_customize() -> void:
	customize_root = Control.new()
	customize_root.name = "CustomizeView"
	customize_root.position = Vector2.ZERO
	customize_root.size = REF
	customize_root.visible = false
	add_child(customize_root)

	var bg := ColorRect.new()
	bg.color = Color("#0a0d14")
	bg.position = Vector2.ZERO
	bg.size = REF
	customize_root.add_child(bg)

	var back := _btn(customize_root, "← 返回大廳", Rect2(30, 25, 120, 36), 14, C_ACCENT,
			Color(0.22, 0.74, 0.97, 0.15), C_ACCENT, 18, 1)
	back.pressed.connect(_on_back_lobby_pressed)
	_label(customize_root, "🛠 車輛改裝與個人化", Vector2(170, 30), 22, C_WHITE)

	var card := _panel(customize_root, Rect2(460, 280, 360, 160), Color(0.024, 0.172, 0.125, 0.9),
			C_SELF, 16, 2)
	_label(card, "YOUR CAR 3D", Vector2(0, 40), 32, C_WHITE, HORIZONTAL_ALIGNMENT_CENTER, 360)
	_label(card, "改裝預覽（3D 車庫占位）", Vector2(0, 96), 14, C_MUTED, HORIZONTAL_ALIGNMENT_CENTER, 360)


func _build_hint() -> void:
	_label(self, "點車位切換左側面板顯示對象 · 再點一次「自己的車」進入改車 · 點輸入框展開聊天",
			Vector2(340, 700), 12, Color(0.39, 0.45, 0.52, 1), HORIZONTAL_ALIGNMENT_CENTER, 600)


func _build_toast() -> void:
	toast_panel = _panel(self, Rect2(0, 20, 0, 40), Color(0.06, 0.09, 0.16, 0.96), C_ACCENT, 20, 1.5)
	toast_panel.visible = false
	toast_label = _label(toast_panel, "", Vector2(0, 0), 14, C_WHITE, HORIZONTAL_ALIGNMENT_CENTER, 0)


# ==========================================================================
# 網路
# ==========================================================================

func _connect_network() -> void:
	var nm = _net()
	var lm = _lobby()
	if nm and "mode_changed" in nm:
		nm.mode_changed.connect(func(_m): _on_network_update())
	if nm and "login_succeeded" in nm:
		nm.login_succeeded.connect(_on_network_update)
	if nm and "logged_out" in nm:
		nm.logged_out.connect(_on_network_update)
	if lm and "member_joined" in lm:
		lm.member_joined.connect(func(_id): _on_network_update())
	if lm and "member_left" in lm:
		lm.member_left.connect(func(_id): _on_network_update())
	if lm and "ready_state_changed" in lm:
		lm.ready_state_changed.connect(func(_m): _on_network_update())
	if lm and "match_started" in lm:
		lm.match_started.connect(_on_match_started)
	if lm and "lobby_created" in lm:
		lm.lobby_created.connect(func(info): _on_lobby_result("created", info))
	if lm and "lobby_joined" in lm:
		lm.lobby_joined.connect(func(info): _on_lobby_result("joined", info))


func _on_network_update() -> void:
	_sync_players()
	_refresh()


func _on_match_started(_order: Array) -> void:
	get_tree().change_scene_to_file("res://main.tscn")


func _sync_players() -> void:
	var lm = _lobby()
	var nm = _net()
	if not _in_lobby():
		players = _default_players()
	else:
		players = []
		for i in lm.players.size():
			var lp: Dictionary = lm.players[i]
			var d := _mock_for(i)
			players.append({
				"id": "p%d" % i,
				"name": lp.get("name", "玩家%d" % (i + 1)),
				"car_name": d["car_name"], "score": d["score"], "cls": d["cls"],
				"rank": d["rank"], "best_lap": d["best_lap"],
				"matches": d["matches"], "stats": d["stats"],
				"is_self": (nm and "LOCAL_PEER_ID" in nm) and lp.get("peer_id", 0) == nm.LOCAL_PEER_ID,
			})
	if selected_id == "" or not _player_exists(selected_id):
		selected_id = _self_id()
	if selected_id == "" and not players.is_empty():
		selected_id = players[0]["id"]
	if _in_lobby():
		if nm and "LOCAL_PEER_ID" in nm and lm.has_method("get_ready_map"):
			is_ready = lm.get_ready_map().get(nm.LOCAL_PEER_ID, false)
	_rebuild_slot_buttons(_slot_layer())


func _in_lobby() -> bool:
	var lm = _lobby()
	return lm != null and not lm.current_lobby.is_empty()


func _slot_layer() -> Control:
	for c in get_children():
		if c.name == "SlotLayer":
			return c
	return null


func _default_players() -> Array:
	var me: Dictionary = _mock_for(0).duplicate(true)
	me["id"] = "you"
	me["name"] = _display_name()
	me["is_self"] = true
	var other: Dictionary = _mock_for(1).duplicate(true)
	other["id"] = "abc"
	other["name"] = "abc"
	other["is_self"] = false
	return [me, other]


func _mock_for(i: int) -> Dictionary:
	var specs := [
		{"car_name": "Ferrari F8 Tributo", "score": 1520, "cls": "S", "rank": "🥇 黃金 III",
			"best_lap": "1:09.4", "matches": [true, true, false, true, false],
			"stats": {"speed": 0.88, "handling": 0.72, "accel": 0.85}},
		{"car_name": "Porsche GT3 RS", "score": 1485, "cls": "S", "rank": "🥈 白銀 I",
			"best_lap": "1:11.2", "matches": [false, true, true, false, true],
			"stats": {"speed": 0.82, "handling": 0.85, "accel": 0.70}},
		{"car_name": "Nissan GT-R", "score": 1390, "cls": "A", "rank": "🥉 黃金 IV",
			"best_lap": "1:14.8", "matches": [true, true, true, false, false],
			"stats": {"speed": 0.80, "handling": 0.78, "accel": 0.88}},
	]
	return specs[i % specs.size()]


func _display_name() -> String:
	var nm = _net()
	if nm and "is_logged_in" in nm and nm.is_logged_in and "display_name" in nm and nm.display_name != "":
		return nm.display_name
	return "UserName"


func _puid_text() -> String:
	var nm = _net()
	if nm and "is_logged_in" in nm and nm.is_logged_in and "product_user_id" in nm and nm.product_user_id != "":
		return "PUID: %s" % nm.product_user_id.substr(0, 8)
	return "PUID: 未登入"


# ==========================================================================
# 互動
# ==========================================================================

func _on_user_card_pressed() -> void:
	var nm = _net()
	if nm == null:
		toast("網路模組尚未載入")
		return
	if "is_logged_in" in nm and nm.is_logged_in:
		toast("已登入：%s" % nm.display_name)
		return
	toast("正在初始化 EOS…")
	if nm.has_method("init_eos") and nm.has_method("login"):
		if not ("is_eos_ready" in nm and nm.is_eos_ready):
			nm.init_eos()
			var cb := func(ok: bool, _msg: String) -> void:
				if ok:
					nm.login()
			nm.eos_initialized.connect(cb, CONNECT_ONE_SHOT)
		else:
			nm.login()
	else:
		toast("網路模組未就緒（EOS 待設定）")


func _on_room_pressed() -> void:
	room_overlay_open = true
	overlay_input.text = room_config["name"]
	_refresh()


func _on_slot_pressed(i: int) -> void:
	if i >= players.size():
		return
	var p: Dictionary = players[i]
	if selected_id == p["id"] and p["is_self"]:
		customize_view = true
	else:
		selected_id = p["id"]
	_refresh()


func _on_customize_pressed() -> void:
	customize_view = true
	_refresh()


func _on_back_lobby_pressed() -> void:
	customize_view = false
	_refresh()


func _on_chat_trigger_pressed() -> void:
	chat_open = not chat_open
	_refresh()


func _on_chat_close_pressed() -> void:
	chat_open = false
	_refresh()


func _on_tab_pressed(id: String) -> void:
	chat_tab = id
	_refresh_chat()


func _on_chat_sent(new_text: String) -> void:
	var t := new_text.strip_edges()
	if t == "":
		return
	chat_messages.append(["You", t])
	chat_input.clear()
	_refresh_chat()


func _on_start_pressed() -> void:
	var nm = _net()
	var lm = _lobby()
	var online: bool = nm != null and nm.has_method("is_online") and nm.is_online()
	if not online:
		get_tree().change_scene_to_file("res://main.tscn")
		return
	is_ready = not is_ready
	if lm != null and lm.has_method("set_ready"):
		lm.set_ready(is_ready)
		if lm.is_host and _all_lobby_ready():
			lm.start_match()
	_refresh()


func _on_spectator_pressed() -> void:
	room_config["spectator"] = not room_config["spectator"]
	_refresh_overlay()


func _on_chip_pressed(row: String, value: String) -> void:
	match row:
		"map":
			room_config["map"] = value
		"mode":
			room_config["mode"] = value
		"maxp":
			room_config["max_players"] = int(value.replace("人", ""))
		"privacy":
			room_config["privacy"] = {"公開": "public", "私人": "private", "好友": "friends"}[value]
		"carr":
			room_config["car_restriction"] = value
		"dmg":
			room_config["damage_mode"] = value
		"auto":
			room_config["auto_start"] = value
	_refresh_overlay()
	_refresh()


func _on_copy_invite_pressed() -> void:
	DisplayServer.clipboard_set(room_config["invite_code"])
	toast("已複製邀請連結")


func _on_save_overlay() -> void:
	var new_name := overlay_input.text.strip_edges()
	if new_name != "":
		room_config["name"] = new_name
	room_overlay_open = false
	toast("設定已儲存")
	_refresh()


func _on_cancel_overlay() -> void:
	room_overlay_open = false
	_refresh()


# ==========================================================================
# Lobby 操作：開房 / 搜房 / 加入 / 離開
# ==========================================================================

func _on_search_pressed() -> void:
	_open_browser(true)
	if not browser_busy:
		call_deferred("_do_search")

func _do_search() -> void:
	var nm = _net()
	if nm == null or not nm.is_logged_in:
		toast("請先登入（點左上玩家卡）")
		_open_browser(false)
		return
	var lm = _lobby()
	if lm == null:
		toast("房間模組未就緒")
		_open_browser(false)
		return
	browser_busy = true
	browser_status.text = "搜尋中…"
	_render_browser_list()
	var results: Array = await lm.search_lobbies()
	browser_busy = false
	browser_results = results
	_render_browser_list()

func _render_browser_list() -> void:
	for c in browser_list.get_children():
		c.queue_free()
	if browser_results.is_empty():
		if browser_busy:
			browser_status.text = "搜尋中…"
		else:
			browser_status.text = "找不到公開房間（確認 host 已開房且設為公開）"
		return
	browser_status.text = "找到 %d 間房間" % browser_results.size()
	var y := 0.0
	for i in browser_results.size():
		var lb = browser_results[i]
		var host := _lobby_attr(lb, "host_name", "Host")
		var room := _lobby_attr(lb, "room_name", host + " 的房間")
		var max_p: int = int(lb.max_members)
		var avail: int = int(lb.available_slots)
		var count: int = max_p - avail
		var row := _panel(browser_list, Rect2(0, y, 568, 64), Color(1, 1, 1, 0.03), C_BORDER, 8, 1)
		_label(row, room, Vector2(16, 10), 16, C_WHITE)
		_label(row, "%s  ·  %d/%d" % [host, count, max_p], Vector2(16, 36), 12, C_MUTED)
		var join := _btn(row, "加入", Rect2(568 - 90, 16, 70, 30), 13, Color("#0f172a"), C_ACCENT, Color.TRANSPARENT, 6, 1)
		join.pressed.connect(_on_join_pressed.bind(lb))
		if count >= max_p:
			join.disabled = true
			join.text = "已滿"
		y += 72.0

func _lobby_attr(lb, key: String, fallback: String = "") -> String:
	if lb == null:
		return fallback
	var attr = lb.get_attribute(key)
	if attr is Dictionary and not attr.is_empty() and attr.has("value"):
		return str(attr["value"])
	return fallback

func _on_join_pressed(lb) -> void:
	var lm = _lobby()
	if lm == null:
		toast("房間模組未就緒")
		return
	browser_busy = true
	toast("正在加入房間…")
	lm.join_lobby(lb)
	# 結果透過 lobby_joined signal 處理

func _on_create_room_pressed() -> void:
	var nm = _net()
	if nm == null:
		toast("網路模組尚未載入")
		return
	if not nm.is_logged_in:
		toast("請先登入（點左上玩家卡）")
		return
	var lm = _lobby()
	if lm == null:
		toast("房間模組未就緒")
		return
	if not lm.current_lobby.is_empty():
		toast("已在房間中")
		return
	room_overlay_open = false
	toast("正在建立房間…")
	lm.create_lobby(room_config)

func _on_leave_room_pressed() -> void:
	room_overlay_open = false
	var lm = _lobby()
	if lm != null and not lm.current_lobby.is_empty():
		await lm.leave_lobby()
	toast("已離開房間")
	_sync_players()
	_refresh()

func _on_leave_lobby_pressed() -> void:
	var lm = _lobby()
	if lm != null and not lm.current_lobby.is_empty():
		await lm.leave_lobby()
	toast("已離開房間")
	_sync_players()
	_refresh()

func _on_lobby_result(kind: String, info: Dictionary) -> void:
	browser_busy = false
	if info.is_empty():
		toast("失敗：%s 失敗" % ("開房" if kind == "created" else "加入"))
		return
	_open_browser(false)
	room_overlay_open = false
	# invite code 用 lobby_id 前段
	room_config["invite_code"] = str(info.get("lobby_id", "")).substr(0, 12).to_upper()
	if info.get("is_host", false):
		toast("已開房，等待其他玩家加入")
	else:
		toast("已加入房間")
	_sync_players()
	_refresh()

func _open_browser(open: bool) -> void:
	browser_open = open
	browser_root.visible = open
	if open:
		call_deferred("_do_search")
	_refresh()


func _all_lobby_ready() -> bool:
	var lm = _lobby()
	if lm == null:
		return false
	var lp: Array = lm.players if "players" in lm else []
	for p in lp:
		if p is Dictionary and not p.get("ready", false):
			return false
	return true


# ==========================================================================
# 刷新
# ==========================================================================

func _refresh() -> void:
	# header
	user_card_name.text = _display_name()
	user_card_puid.text = _puid_text()

	# room
	room_name_label.text = room_config["name"]
	var font := room_name_label.get_theme_font("font")
	var nw := font.get_string_size(room_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	room_count_label.text = "  ·  %d/%d" % [players.size(), room_config["max_players"]]
	room_count_label.position = Vector2(24 + nw, 25)

	# inspector
	var p := _selected_player()
	if not p.is_empty():
		insp_selected.text = "SELECTED CAR" if p["is_self"] else "SELECTED CAR  ·  檢視 %s" % p["name"]
		insp_car.text = p["car_name"]
		insp_score.text = str(p["score"])
		insp_class.text = p["cls"]
		customize_btn.visible = p["is_self"]
		insp_rank.text = p["rank"]
		insp_lap.text = p["best_lap"]
		for i in insp_dots.size():
			var win: bool = p["matches"][i]
			_set_dot_color(insp_dots[i], C_WIN if win else C_LOSS)
		var bar_color: Color = C_SELF if p["is_self"] else C_ACCENT
		var names := ["speed", "handling", "accel"]
		for i in insp_bars.size():
			insp_bars[i].value = float(p["stats"][names[i]]) * 100.0
			_set_bar_color(insp_bars[i], bar_color)

	# chat trigger + window
	_style_button(chat_trigger_btn,
			Color(0.059, 0.086, 0.133, 0.75),
			C_ACCENT if chat_open else C_BORDER, 10, 1.5 if chat_open else 1.0, 18.0)
	chat_root.visible = chat_open
	_refresh_chat()

	# overlay / customize / ready
	overlay_root.visible = room_overlay_open
	customize_root.visible = customize_view
	_refresh_overlay()
	_refresh_ready_button()

	queue_redraw()


func _refresh_chat() -> void:
	for c in chat_msgs_root.get_children():
		c.queue_free()
	var y := 0.0
	for m in chat_messages:
		_label(chat_msgs_root, m[0] + ":", Vector2(0, y), 13, _chat_color(m[0]))
		_label(chat_msgs_root, m[1], Vector2(0, y + 16), 13, C_MUTED)
		y += 42.0
	for id in tab_btns:
		var b: Button = tab_btns[id]
		var active: bool = chat_tab == str(id)
		_style_button(b, Color(0.22, 0.74, 0.97, 0.25) if active else Color(1, 1, 1, 0.04),
				C_ACCENT if active else Color(0.545, 0.608, 0.706, 0.18), 6, 1)
		b.add_theme_color_override("font_color", C_ACCENT if active else C_MUTED)
		b.add_theme_color_override("font_hover_color", C_ACCENT)


func _refresh_overlay() -> void:
	for c in chips:
		var active: bool = _is_active(c["row"], c["value"])
		_style_button(c["btn"], Color(0.22, 0.74, 0.97, 0.2) if active else Color(1, 1, 1, 0.03),
				C_ACCENT if active else C_BORDER, 6, 1)
		c["btn"].add_theme_color_override("font_color", C_ACCENT if active else C_MUTED)
		c["btn"].add_theme_color_override("font_hover_color", C_ACCENT if active else C_WHITE)
	var on: bool = room_config["spectator"]
	_style_button(spectator_btn, Color(0.062, 0.724, 0.508, 0.25) if on else Color(1, 1, 1, 0.05),
			C_SELF if on else C_BORDER, 13, 1)
	spectator_btn.text = "● 開啟" if on else "○ 關閉"
	spectator_btn.add_theme_color_override("font_color", C_SELF if on else C_MUTED)
	overlay_invite.text = room_config["invite_code"]
	# 依房間狀態顯示 / 隱藏按鈕
	var in_lobby: bool = _in_lobby()
	leave_room_btn.visible = in_lobby
	create_room_btn.visible = not in_lobby
	# 離開 btn 顯示狀態
	leave_lobby_btn.visible = in_lobby
	if in_lobby:
		var lm = _lobby()
		if lm and lm.is_host:
			leave_room_btn.text = "離開房間"
		else:
			leave_room_btn.text = "離開"
	create_room_btn.text = _display_name() + " 的房間"
	# 房間名稱與人數
	var lm = _lobby()
	if in_lobby and lm and lm.current_lobby is Dictionary:
		room_name_label.text = _lobby_attr(lm.get_attribute("room_name") if "get_attribute" in lm else null, "", room_config["name"])
		room_count_label.text = "  ·  %d/%d" % [lm.players.size(), lm.max_members]


func _is_active(row: String, value: String) -> bool:
	match row:
		"map":
			return room_config["map"] == value
		"mode":
			return room_config["mode"] == value
		"maxp":
			return room_config["max_players"] == int(value.replace("人", ""))
		"privacy":
			return room_config["privacy"] == {"公開": "public", "私人": "private", "好友": "friends"}[value]
		"carr":
			return room_config["car_restriction"] == value
		"dmg":
			return room_config["damage_mode"] == value
		"auto":
			return room_config["auto_start"] == value
	return false


func _refresh_ready_button() -> void:
	var nm = _net()
	var lm = _lobby()
	var online: bool = nm != null and nm.has_method("is_online") and nm.is_online()
	if not online:
		_style_button(ready_btn, Color(0.062, 0.724, 0.508, 0.95), C_SELF, 12, 2)
		ready_btn.text = "▶  開始計時賽"
		ready_sub.text = "單人模式 · 進入賽道"
		return
	if lm != null and lm.is_host and _all_lobby_ready():
		_style_button(ready_btn, Color(0.95, 0.55, 0.13, 1.0), Color(1, 0.7, 0.2, 1), 12, 2)
		ready_btn.text = "🏁  開始比賽"
		ready_sub.text = "所有人已就緒"
		return
	if is_ready:
		_style_button(ready_btn, Color(0.1, 0.5, 0.4, 0.95), C_SELF, 12, 2)
		ready_btn.text = "✔  已準備 (READY)"
		ready_sub.text = "點擊取消準備"
	else:
		_style_button(ready_btn, Color(0.062, 0.724, 0.508, 0.95), C_SELF, 12, 2)
		ready_btn.text = "READY"
		ready_sub.text = "等待房主發車…"


func _chat_color(who: String) -> Color:
	if who == "System":
		return C_ACCENT
	if who == "You":
		return C_SELF
	return C_WHITE


func toast(msg: String) -> void:
	toast_label.text = msg
	var w := toast_label.get_theme_font("font").get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 40.0
	toast_label.size = Vector2(w, 40)
	toast_panel.size = Vector2(w, 40)
	toast_panel.position = Vector2((REF.x - w) / 2.0, 20)
	toast_panel.visible = true
	toast_panel.modulate = Color.WHITE
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(1.4)
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.5)
	toast_tween.tween_callback(func(): toast_panel.visible = false)


func _selected_player() -> Dictionary:
	for p in players:
		if p["id"] == selected_id:
			return p
	if players.is_empty():
		return {}
	return players[0]


func _self_id() -> String:
	for p in players:
		if p["is_self"]:
			return p["id"]
	return ""


func _player_exists(id: String) -> bool:
	for p in players:
		if p["id"] == id:
			return true
	return false


# ==========================================================================
# 元件小工具
# ==========================================================================

func _panel(parent: Node, rect: Rect2, bg: Color, border: Color, radius: float, bw: float) -> Panel:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(int(bw))
	sb.border_color = border
	sb.set_corner_radius_all(int(radius))
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p


func _label(parent: Node, text: String, pos: Vector2, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.horizontal_alignment = align
	if w > 0:
		l.size = Vector2(w, 0)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _btn(parent: Node, text: String, rect: Rect2, font_size: int, color: Color, bg: Color,
		border: Color, radius: float, bw: float, cm_left := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", color)
	b.add_theme_color_override("font_focus_color", color)
	_style_button(b, bg, border, radius, bw, cm_left)
	parent.add_child(b)
	return b


func _style_button(b: Button, bg: Color, border: Color, radius: float, bw: float, cm_left := 0.0) -> void:
	b.add_theme_stylebox_override("normal", _sb(bg, border, radius, bw, cm_left))
	var hbg: Color = bg.lightened(0.15) if bg.a > 0.05 else bg
	b.add_theme_stylebox_override("hover", _sb(hbg, border, radius, bw, cm_left))
	b.add_theme_stylebox_override("pressed", _sb(bg.darkened(0.15), border, radius, bw, cm_left))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _sb(bg_c: Color, border_c: Color, radius: float, bw: float, cm_left: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_c
	sb.set_corner_radius_all(int(radius))
	if bw > 0:
		sb.set_border_width_all(int(bw))
		sb.border_color = border_c
	if cm_left > 0:
		sb.content_margin_left = cm_left
	return sb


func _bar(parent: Node, pos: Vector2, w: float, h: float, value: float, color: Color) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.position = pos
	pb.size = Vector2(w, h)
	pb.min_value = 0.0
	pb.max_value = 100.0
	pb.value = value
	pb.show_percentage = false
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(1, 1, 1, 0.08)
	bg_sb.set_corner_radius_all(4)
	pb.add_theme_stylebox_override("background", bg_sb)
	_set_bar_color(pb, color)
	parent.add_child(pb)
	return pb


func _set_bar_color(bar: ProgressBar, color: Color) -> void:
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = color
	fill_sb.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill_sb)


func _dot(parent: Node, pos: Vector2, r: float, color: Color) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = Vector2(r * 2, r * 2)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	_set_dot_color(p, color)
	return p


func _set_dot_color(p: Panel, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(5)
	p.add_theme_stylebox_override("panel", sb)

```

**menu_tabs.gd**
```gdscript
extends VBoxContainer

## MainCard 分頁控制。
## 三顆分頁按鈕（登入/註冊/體驗）切換下方的內容頁面，並帶有淡入淡出 + 微縮放動畫。

enum Tab { LOGIN, REGISTER, PLAY }

const FADE_DURATION := 0.22

@onready var login_button: Button = $TabHeader/LoginButton
@onready var register_button: Button = $TabHeader/RegisterButton
@onready var play_button: Button = $TabHeader/PlayButton
@onready var login_page: Control = $ContentArea/Margin/ContentStack/LoginPage
@onready var register_page: Control = $ContentArea/Margin/ContentStack/RegisterPage
@onready var play_page: Control = $ContentArea/Margin/ContentStack/PlayPage

var _current_tab: Tab = Tab.PLAY
var _fade_tween: Tween

func _ready() -> void:
	login_button.pressed.connect(_switch_tab.bind(Tab.LOGIN))
	register_button.pressed.connect(_switch_tab.bind(Tab.REGISTER))
	play_button.pressed.connect(_switch_tab.bind(Tab.PLAY))
	_setup_page(login_page)
	_setup_page(register_page)
	_setup_page(play_page)
	_apply_tab(Tab.PLAY, false)


func _switch_tab(tab: Tab) -> void:
	_apply_tab(tab, tab != _current_tab)


func _apply_tab(tab: Tab, animate: bool) -> void:
	var old_page := _page_for(_current_tab)
	var new_page := _page_for(tab)
	_current_tab = tab

	login_button.button_pressed = tab == Tab.LOGIN
	register_button.button_pressed = tab == Tab.REGISTER
	play_button.button_pressed = tab == Tab.PLAY

	if old_page == new_page:
		return

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	new_page.visible = true
	new_page.modulate.a = 0.0
	new_page.scale = Vector2(0.97, 0.97)

	if not animate:
		_finish_switch(old_page, new_page)
		return

	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(new_page, "modulate:a", 1.0, FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(new_page, "scale", Vector2.ONE, FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_tween.tween_property(old_page, "modulate:a", 0.0, FADE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_fade_tween.chain().tween_callback(func():
		_finish_switch(old_page, new_page)
	)


func _finish_switch(old_page: Control, new_page: Control) -> void:
	old_page.visible = false
	old_page.modulate.a = 1.0
	old_page.scale = Vector2.ONE
	new_page.modulate.a = 1.0
	new_page.scale = Vector2.ONE


func _page_for(tab: Tab) -> Control:
	match tab:
		Tab.LOGIN:
			return login_page
		Tab.REGISTER:
			return register_page
		Tab.PLAY:
			return play_page
	return play_page


func _setup_page(page: Control) -> void:
	page.pivot_offset = page.size * 0.5
	page.resized.connect(_on_page_resized.bind(page))
	if page != play_page:
		page.visible = false


func _on_page_resized(page: Control) -> void:
	page.pivot_offset = page.size * 0.5

```

**time_trial_countdown.gd**
```gdscript
extends CenterContainer

@onready var label: Label = $CountdownLabel

var _last_countdown_text: String = ""
var _countdown_tween: Tween

func _ready() -> void:
	label.text = ""

func set_text(text: String, color: Color) -> void:
	label.text = text
	label.modulate = color
	if text.is_empty():
		return
	if text == _last_countdown_text:
		return
	_last_countdown_text = text
	if _countdown_tween and _countdown_tween.is_valid():
		_countdown_tween.kill()
	label.pivot_offset = label.get_minimum_size() * 0.5
	_countdown_tween = create_tween()
	_countdown_tween.tween_property(
		label, "scale", Vector2.ONE, 0.35
	).from(Vector2(0.45, 0.45)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func reset() -> void:
	label.text = "3"
	label.scale = Vector2.ONE
	label.modulate = Color.WHITE
	_last_countdown_text = ""

func clear() -> void:
	label.text = ""
	label.scale = Vector2.ONE
	label.modulate = Color.WHITE
	_last_countdown_text = ""

```

**time_trial_finish_screen.gd**
```gdscript
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

```

**time_trial_hud.gd**
```gdscript
extends PanelContainer

@onready var timer_label: Label = $Margin/VBox/TimerLabel
@onready var checkpoint_label: Label = $Margin/VBox/CheckpointLabel
@onready var checkpoint_bar: ProgressBar = $Margin/VBox/CheckpointBar
@onready var best_time_label: Label = $Margin/VBox/BestTimeLabel

var _bar_tween: Tween
var _chk_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_waiting(waiting: bool) -> void:
	visible = not waiting


func reset(total_checkpoints: int) -> void:
	timer_label.text = "0.00"
	checkpoint_label.text = "檢查點：0 / %d" % total_checkpoints
	checkpoint_bar.max_value = total_checkpoints
	checkpoint_bar.value = 0


func set_time(seconds: float) -> void:
	timer_label.text = "%.2f" % seconds


func set_checkpoint(current: int, total: int) -> void:
	checkpoint_label.text = "檢查點：%d / %d" % [current, total]

	if _bar_tween and _bar_tween.is_valid():
		_bar_tween.kill()
	_bar_tween = create_tween()
	_bar_tween.tween_property(checkpoint_bar, "value", float(current), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	checkpoint_label.pivot_offset = checkpoint_label.get_minimum_size() * 0.5
	if _chk_tween and _chk_tween.is_valid():
		_chk_tween.kill()
	_chk_tween = create_tween()
	_chk_tween.tween_property(checkpoint_label, "scale", Vector2.ONE, 0.3).from(Vector2(1.3, 1.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_best_time(best_time: float) -> void:
	if best_time < 0.0:
		best_time_label.text = "最佳：--"
		return
	best_time_label.text = "最佳：%.2f 秒" % best_time


func play_intro() -> void:
	pivot_offset = size * 0.5
	scale = Vector2(0.8, 0.8)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

```

**time_trial_leaderboard.gd**
```gdscript
extends PanelContainer

signal score_registered(player_name: String, rank: int)

const SAVE_PATH: String = "user://race_scores.cfg"

@onready var leaderboard_grid: GridContainer = %LeaderboardGrid
@onready var leaderboard_title: Label = %LeaderboardTitle
@onready var local_tab: Button = %LocalTab
@onready var public_tab: Button = %PublicTab
@onready var public_leaderboard_grid: GridContainer = %PublicLeaderboardGrid

var leaderboard: Array = []
var _showing_public := false


func _ready() -> void:
	load_leaderboard()
	local_tab.pressed.connect(_on_local_tab_pressed)
	public_tab.pressed.connect(_on_public_tab_pressed)
	LeaderboardManager.leaderboard_updated.connect(_on_public_leaderboard_updated)

	# 初始化排行榜分頁狀態（本地為預設）
	local_tab.disabled = true
	public_tab.disabled = false
	leaderboard_grid.visible = true
	public_leaderboard_grid.visible = false

	refresh_leaderboard_ui()


func set_waiting(waiting: bool) -> void:
	visible = waiting


func register_score(score_name: String, score_time: float) -> int:
	var existing_index: int = -1

	for index in range(leaderboard.size()):
		var score: Dictionary = leaderboard[index]

		if str(score.get("name", "")) == score_name:
			existing_index = index
			break
	
	if existing_index == -1:
		# 第一次使用這個名字
		leaderboard.append({
			"name": score_name,
			"time": score_time
		})

	elif score_time < float(leaderboard[existing_index]["time"]):
		# 同名，但這次成績更快
		leaderboard[existing_index]["time"] = score_time

	else:
		# 同名，而且沒有刷新紀錄
		return -1

	leaderboard.sort_custom(is_score_faster)

	save_leaderboard()
	refresh_leaderboard_ui()

	print("目前排行榜：", leaderboard)

	var rank: int = -1
	for index in range(leaderboard.size()):
		if str(leaderboard[index].get("name", "")) == score_name:
			rank = index + 1
			break
	score_registered.emit(score_name, rank)
	return rank


func submit_public(time_seconds: float) -> void:
	# 提交到 EOS 公開排行榜（毫秒）
	if LeaderboardManager and NetworkManager.is_logged_in:
		LeaderboardManager.submit_race_time(time_seconds)


func is_score_faster(score_a: Dictionary, score_b: Dictionary) -> bool:
	return float(score_a["time"]) < float(score_b["time"])
	

func load_leaderboard() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)

	if error != OK:
		return

	var saved_leaderboard = config.get_value(
		"scores",
		"leaderboard",
		[]
	)

	if saved_leaderboard is Array:
		leaderboard = saved_leaderboard
		
func save_leaderboard() -> void:
	var config := ConfigFile.new()

	# 先讀取原本的檔案，避免清掉 best_time
	config.load(SAVE_PATH)

	config.set_value(
		"scores",
		"leaderboard",
		leaderboard
	)

	var error := config.save(SAVE_PATH)

	if error != OK:
		push_error("無法儲存排行榜")


func _on_local_tab_pressed() -> void:
	_showing_public = false
	leaderboard_title.text = "排行榜"
	leaderboard_grid.visible = true
	public_leaderboard_grid.visible = false
	local_tab.disabled = true
	public_tab.disabled = false
	refresh_leaderboard_ui()


func _on_public_tab_pressed() -> void:
	_showing_public = true
	leaderboard_title.text = "公開排行榜"
	leaderboard_grid.visible = false
	public_leaderboard_grid.visible = true
	local_tab.disabled = false
	public_tab.disabled = true
	LeaderboardManager.refresh_leaderboard()


func _on_public_leaderboard_updated(records: Array) -> void:
	if not _showing_public:
		return
	_refresh_public_leaderboard_ui(records)


func refresh_leaderboard_ui() -> void:
	for child in leaderboard_grid.get_children():
		child.queue_free()

	add_leaderboard_cell("名次", 60.0)
	add_leaderboard_cell("姓名", 180.0)
	add_leaderboard_cell("時間", 70.0)

	if leaderboard.is_empty():
		add_leaderboard_cell("", 60.0)
		add_leaderboard_cell("尚無紀錄", 180.0)
		add_leaderboard_cell("", 70.0)
		return

	var display_count: int = mini(10, leaderboard.size())
		
	for index in range(display_count):
		var score: Dictionary = leaderboard[index]
		var score_name: String = str(score.get("name", "未知"))
		var score_time: float = float(score.get("time", 0.0))

		add_leaderboard_cell(str(index + 1), 60.0)
		add_leaderboard_cell(score_name, 180.0)
		add_leaderboard_cell("%.2f 秒" % score_time, 70.0)


func add_leaderboard_cell(cell_text: String, minimum_width: float) -> void:
	var cell_label := Label.new()

	cell_label.text = cell_text
	cell_label.custom_minimum_size.x = minimum_width
	cell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell_label.add_theme_font_size_override("font_size", 24)

	leaderboard_grid.add_child(cell_label)


func _refresh_public_leaderboard_ui(records: Array) -> void:
	for child in public_leaderboard_grid.get_children():
		child.queue_free()

	_add_leaderboard_header(public_leaderboard_grid)

	if records.is_empty():
		_add_leaderboard_row(public_leaderboard_grid, "", "尚無紀錄", "")
		return

	var count: int = mini(10, records.size())
	for i in range(count):
		var rec: Dictionary = records[i]
		var display_name: String = str(rec.get("display_name", "未知"))
		var score_int: int = int(rec.get("stat_value", 0))
		var time_str: String = "%.2f 秒" % (score_int / 1000.0)
		_add_leaderboard_row(public_leaderboard_grid, str(i + 1), display_name, time_str)


func _add_leaderboard_header(grid: GridContainer) -> void:
	_make_label(grid, "名次", 60.0)
	_make_label(grid, "姓名", 180.0)
	_make_label(grid, "時間", 70.0)


func _add_leaderboard_row(grid: GridContainer, rank: String, pname: String, time: String) -> void:
	_make_label(grid, rank, 60.0)
	_make_label(grid, pname, 180.0)
	_make_label(grid, time, 70.0)


func _make_label(grid: GridContainer, txt: String, min_w: float) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.custom_minimum_size.x = min_w
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	grid.add_child(lbl)
```

**time_trial_start_screen.gd**
```gdscript
extends Control

signal start_requested(player_name: String)

@onready var login_button: Button = $MainCard/TabHeader/LoginButton
@onready var register_button: Button = $MainCard/TabHeader/RegisterButton
@onready var play_button: Button = $MainCard/TabHeader/PlayButton
@onready var name_input: LineEdit = $MainCard/ContentArea/Margin/ContentStack/PlayPage/PlayCenter/ContentVBox/NameInput
@onready var start_button: Button = $MainCard/ContentArea/Margin/ContentStack/PlayPage/PlayCenter/ContentVBox/Footer/StartButton
@onready var epic_login_button: Button = $MainCard/ContentArea/Margin/ContentStack/LoginPage/LoginCenter/LoginContent/EpicLoginButton
@onready var discord_login_button: Button = $MainCard/ContentArea/Margin/ContentStack/LoginPage/LoginCenter/LoginContent/DiscordLoginButton
@onready var auth_status: Label = $MainCard/ContentArea/Margin/ContentStack/LoginPage/LoginCenter/LoginContent/AuthStatus
@onready var epic_register_button: Button = $MainCard/ContentArea/Margin/ContentStack/RegisterPage/RegisterCenter/RegisterContent/RegisterProviderRow/EpicRegisterButton
@onready var discord_register_button: Button = $MainCard/ContentArea/Margin/ContentStack/RegisterPage/RegisterCenter/RegisterContent/RegisterProviderRow/DiscordRegisterButton
@onready var username_input: LineEdit = $MainCard/ContentArea/Margin/ContentStack/RegisterPage/RegisterCenter/RegisterContent/UsernameInput
@onready var terms_check_box: CheckBox = $MainCard/ContentArea/Margin/ContentStack/RegisterPage/RegisterCenter/RegisterContent/TermsCheckBox
@onready var create_account_button: Button = $MainCard/ContentArea/Margin/ContentStack/RegisterPage/RegisterCenter/RegisterContent/CreateAccountButton
@onready var registration_status: Label = $MainCard/ContentArea/Margin/ContentStack/RegisterPage/RegisterCenter/RegisterContent/RegistrationStatus

var _auth_in_progress := false
var _registration_flow := false
var _identity_verified := false
var _requested_provider := ""


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	name_input.text_submitted.connect(_on_start_pressed)
	epic_login_button.pressed.connect(_begin_login.bind("epic", false))
	discord_login_button.pressed.connect(_begin_login.bind("discord", false))
	epic_register_button.pressed.connect(_begin_login.bind("epic", true))
	discord_register_button.pressed.connect(_begin_login.bind("discord", true))
	terms_check_box.toggled.connect(_refresh_registration_button)
	username_input.text_changed.connect(_on_username_changed)
	create_account_button.pressed.connect(_on_create_account_pressed)
	NetworkManager.eos_initialized.connect(_on_eos_initialized)
	NetworkManager.login_succeeded.connect(_on_login_succeeded)
	NetworkManager.login_failed.connect(_on_login_failed)

	setup_button_animations(login_button)
	setup_button_animations(register_button)
	setup_button_animations(play_button)
	setup_button_animations(start_button)
	setup_button_animations(epic_login_button)
	setup_button_animations(discord_login_button)
	setup_button_animations(epic_register_button)
	setup_button_animations(discord_register_button)
	setup_button_animations(create_account_button)
	_refresh_registration_button()
	_try_auto_login()


func _on_start_pressed(_text: String = "") -> void:
	start_requested.emit(name_input.text.strip_edges())


func _begin_login(provider: String, registration: bool) -> void:
	if _auth_in_progress:
		return
	_auth_in_progress = true
	_registration_flow = registration
	_identity_verified = false
	_requested_provider = provider
	_set_auth_controls(true)
	_set_auth_status("正在初始化 %s 登入…" % _provider_name(provider))
	if NetworkManager.is_eos_ready:
		_run_requested_login()
	else:
		NetworkManager.init_eos()


func _on_eos_initialized(success: bool, message: String) -> void:
	if not _auth_in_progress:
		return
	if not success:
		_on_login_failed(message if not message.is_empty() else "EOS 初始化失敗")
		return
	_run_requested_login()


func _run_requested_login() -> void:
	_set_auth_status("正在開啟 %s 授權…" % _provider_name(_requested_provider))
	NetworkManager.login(_requested_provider)


func _on_login_succeeded() -> void:
	if not _auth_in_progress:
		return
	_auth_in_progress = false
	_set_auth_controls(false)
	# 從雲端（PlayerDataStorage）或本地快取讀回暱稱
	var saved_name: String = await _restore_display_name()
	if not _registration_flow:
		get_tree().change_scene_to_file("res://ui/lobby.tscn")
		return
	_identity_verified = true
	if username_input.text.strip_edges().is_empty():
		var preferred_name := name_input.text.strip_edges()
		username_input.text = preferred_name if not preferred_name.is_empty() else saved_name
	registration_status.text = "帳號已驗證。設定公開暱稱後即可開始。"
	_refresh_registration_button()


func _on_login_failed(message: String) -> void:
	_auth_in_progress = false
	_set_auth_controls(false)
	_set_auth_status(message if not message.is_empty() else "登入失敗，請再試一次。")


func _on_username_changed(_new_text: String) -> void:
	_refresh_registration_button()


# ==========================================================================
# 自動登入（persistent auth，D1）
# ==========================================================================

## 啟動時嘗試以先前 Account Portal 登入儲存的 refresh token 自動登入。
## 無 token 或失敗時靜默返回，不干擾手動登入流程。
func _try_auto_login() -> void:
	if NetworkManager.is_logged_in:
		return
	if NetworkManager.is_eos_ready:
		_do_auto_login()
		return
	NetworkManager.eos_initialized.connect(_on_auto_login_eos_ready, CONNECT_ONE_SHOT)
	NetworkManager.init_eos()


func _on_auto_login_eos_ready(success: bool, _message: String) -> void:
	if success:
		_do_auto_login()


func _do_auto_login() -> void:
	var ok: bool = await NetworkManager.try_persistent_login()
	if ok:
		get_tree().change_scene_to_file("res://ui/lobby.tscn")


func _refresh_registration_button(_pressed := false) -> void:
	var can_create := _identity_verified and terms_check_box.button_pressed and not username_input.text.strip_edges().is_empty()
	create_account_button.disabled = not can_create


func _on_create_account_pressed() -> void:
	var nickname := username_input.text.strip_edges()
	if nickname.is_empty() or not _identity_verified or not terms_check_box.button_pressed:
		return
	create_account_button.disabled = true
	# Credentials remain with the external provider; this only stores display preferences.
	var profile := {
		"display_name": nickname,
		"product_user_id": NetworkManager.product_user_id,
		"terms_accepted": true,
	}
	var cloud_ok := false
	if PlayerStorage.is_available():
		registration_status.text = "正在同步暱稱到雲端…"
		cloud_ok = await PlayerStorage.save_profile(profile)
	# 無論雲端成功與否都保留本地快取作為 fallback
	_save_local_profile(nickname)
	NetworkManager.display_name = nickname
	if cloud_ok:
		registration_status.text = "暱稱已同步到雲端。"
	else:
		registration_status.text = "雲端同步未完成，暱稱僅儲存於本機。"
	get_tree().change_scene_to_file("res://ui/lobby.tscn")


func _set_auth_controls(disabled: bool) -> void:
	epic_login_button.disabled = disabled
	discord_login_button.disabled = disabled
	epic_register_button.disabled = disabled
	discord_register_button.disabled = disabled


# ==========================================================================
# 暱稱同步（EOS PlayerDataStorage + 本地快取）
# ==========================================================================

## 登入後讀回暱稱：優先雲端，其次本地快取（B3 / B4）。
func _restore_display_name() -> String:
	if PlayerStorage.is_available():
		var cloud := await PlayerStorage.load_profile()
		var cloud_name := str(cloud.get("display_name", ""))
		if not cloud_name.is_empty():
			NetworkManager.display_name = cloud_name
			return cloud_name
	var local_name := _load_local_display_name()
	if not local_name.is_empty():
		NetworkManager.display_name = local_name
	return local_name


func _load_local_display_name() -> String:
	var cfg := ConfigFile.new()
	if cfg.load("user://player_profile.cfg") != OK:
		return ""
	return str(cfg.get_value("profile", "display_name", ""))


func _save_local_profile(nickname: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "display_name", nickname)
	cfg.set_value("profile", "product_user_id", NetworkManager.product_user_id)
	cfg.set_value("profile", "terms_accepted", true)
	cfg.save("user://player_profile.cfg")


func _set_auth_status(message: String) -> void:
	auth_status.text = message
	registration_status.text = message if _registration_flow else ""


func _provider_name(provider: String) -> String:
	match provider:
		"epic":
			return "Epic Games"
		"discord":
			return "Discord"
	return provider


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

```

