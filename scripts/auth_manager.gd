extends Node

signal login_succeeded(display_name: String, product_user_id: String)
signal login_failed(message: String)
signal logout
signal eos_initialized(success: bool, message: String)
signal environment_ready
signal weather_changed(old_intensity: float, new_intensity: float)
signal wind_changed(direction: Vector3, speed: float)
signal discord_oauth_started()
signal discord_oauth_completed(code: String, error: String)

## Internal state
var _is_logged_in := false
var _display_name := ""
var _product_user_id := ""
var _is_eos_ready := false
var _weather_intensity := 0.0
var _time_of_day := 12.0
var _wind_direction := Vector3(1.0, 0.0, 0.0)
var _wind_speed := 1.0

## Singleton references (lazy init)
var _network_manager = null
var _player_storage = null
var _environment_manager = null

func _ready() -> void:
	## No autoload init needed - other nodes reference us by path
	pass

## --- Public API ---

func set_network_manager(node_path: String) -> void:
	var nm = get_node_or_null(node_path)
	if nm != null:
		_network_manager = nm
		_init_network_signals()

func set_player_storage(node_path: String) -> void:
	var ps = get_node_or_null(node_path)
	if ps != null:
		_player_storage = ps
		_init_storage_signals()

func set_environment_manager(node_path: String) -> void:
	var em = get_node_or_null(node_path)
	if em != null:
		_environment_manager = em
		_init_environment_signals()

## Lazy fallback: resolve autoload singletons if nobody injected them.
func _ensure_network_manager() -> Node:
	if _network_manager == null or not is_instance_valid(_network_manager):
		_network_manager = get_node_or_null("/root/NetworkManager")
		if _network_manager != null:
			_init_network_signals()
	return _network_manager

func _ensure_player_storage() -> Node:
	if _player_storage == null or not is_instance_valid(_player_storage):
		_player_storage = get_node_or_null("/root/PlayerStorage")
	return _player_storage

## --- EOS Initialization ---

func init_eos() -> void:
	if _is_eos_ready:
		eos_initialized.emit(true, "")
		return
	if _ensure_network_manager() == null:
		eos_initialized.emit(false, "NetworkManager not set")
		return
	_network_manager.init_eos()

## --- Login/Logout ---

func login(provider: String = "") -> void:
	if not _is_eos_ready:
		login_failed.emit("EOS not initialized, call init_eos() first")
		return
	var nm := _ensure_network_manager()
	if nm == null or not nm.has_method("login"):
		login_failed.emit("NetworkManager not set")
		return
	nm.login(provider)

func try_persistent_login() -> bool:
	if not _is_eos_ready:
		return false
	var nm := _ensure_network_manager()
	if nm == null or not nm.has_method("try_persistent_login"):
		return false
	return bool(await nm.try_persistent_login())

func logout_user() -> void:
	if not _is_logged_in:
		return
	_is_logged_in = false
	_display_name = ""
	_product_user_id = ""
	_ensure_player_storage()
	if _player_storage != null and _player_storage.has_method("delete_persistent_auth_async"):
		await _player_storage.delete_persistent_auth_async()
	logout.emit()

## --- Profile Management (Cloud + Local) ---

func save_profile(profile: Dictionary) -> bool:
	_ensure_player_storage()
	if not _is_logged_in or _player_storage == null:
		return false
	if not _player_storage.has_method("is_available") or not _player_storage.is_available():
		return false
	if _player_storage.has_method("save_profile"):
		return await _player_storage.save_profile(profile)
	return false

func load_profile() -> Dictionary:
	_ensure_player_storage()
	if not _is_logged_in or _player_storage == null:
		return {}
	if not _player_storage.has_method("is_available") or not _player_storage.is_available():
		return {}
	if _player_storage.has_method("load_profile"):
		return await _player_storage.load_profile()
	return {}

func has_profile() -> bool:
	_ensure_player_storage()
	if not _is_logged_in or _player_storage == null:
		return false
	if not _player_storage.has_method("is_available") or not _player_storage.is_available():
		return false
	if _player_storage.has_method("has_profile"):
		return await _player_storage.has_profile()
	return false

## --- Environment sync (weather, time, wind) ---

func sync_environment_from_network(data: Dictionary) -> void:
	if data.has("weather_intensity"):
		_weather_intensity = data["weather_intensity"]
		weather_changed.emit(_weather_intensity - (data["old_intensity"] if data.has("old_intensity") else 0.0), _weather_intensity)
	if data.has("time_of_day"):
		_time_of_day = data["time_of_day"]
	if data.has("wind_direction"):
		var dir = data["wind_direction"]
		if dir is Dictionary:
			_wind_direction = Vector3(dir["x"], dir["y"], dir["z"])
		elif dir is Vector3:
			_wind_direction = dir
		wind_changed.emit(_wind_direction, _wind_speed)
	if data.has("wind_speed"):
		_wind_speed = data["wind_speed"]

## --- Helper accessors ---

func is_logged_in() -> bool:
	return _is_logged_in

func display_name() -> String:
	return _display_name

func product_user_id() -> String:
	return _product_user_id

func is_eos_ready() -> bool:
	return _is_eos_ready

## --- Signals from NetworkManager (delegated) ---

func _on_nm_eos_initialized(success: bool, message: String) -> void:
	if success:
		_is_eos_ready = true
	eos_initialized.emit(success, message)

func _on_nm_login_succeeded() -> void:
	var hauth := _get_hauth()
	if hauth != null:
		var disp = hauth.get("display_name")
		_display_name = str(disp) if disp != null else ""
		var uid = hauth.get("product_user_id")
		_product_user_id = str(uid) if uid != null else ""
		_is_logged_in = true
		login_succeeded.emit(_display_name, _product_user_id)
	else:
		_is_logged_in = true
		_display_name = ""
		_product_user_id = ""
		login_succeeded.emit(_display_name, _product_user_id)

func _on_nm_login_failed(message: String) -> void:
	login_failed.emit(message)

func _on_nm_logged_out() -> void:
	logout_user()

func _on_nm_environment_sync(data: Dictionary) -> void:
	sync_environment_from_network(data)

## --- Godot node helpers (lazy) ---

func _get_hauth() -> Object:
	return get_node_or_null("/root/HAuth")

## --- Signal wiring ---

func _init_network_signals() -> void:
	if _network_manager == null:
		return
	if not _network_manager.eos_initialized.is_connected(_on_nm_eos_initialized):
		_network_manager.eos_initialized.connect(_on_nm_eos_initialized)
	if not _network_manager.login_succeeded.is_connected(_on_nm_login_succeeded):
		_network_manager.login_succeeded.connect(_on_nm_login_succeeded)
	if not _network_manager.login_failed.is_connected(_on_nm_login_failed):
		_network_manager.login_failed.connect(_on_nm_login_failed)
	if not _network_manager.logged_out.is_connected(_on_nm_logged_out):
		_network_manager.logged_out.connect(_on_nm_logged_out)

func _init_storage_signals() -> void:
	pass

func _init_environment_signals() -> void:
	pass

## --- Storage callbacks ---

func _on_write_file_data(_ret: Dictionary) -> void:
	pass

func _on_read_file_data(_ret: Dictionary) -> void:
	pass
