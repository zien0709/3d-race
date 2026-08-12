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
