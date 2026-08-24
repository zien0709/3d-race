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

## --- EOS Initialization ---

func init_eos() -> void:
	if _is_eos_ready:
		eos_initialized.emit(true, "")
		return
	
	if _network_manager == null:
		eos_initialized.emit(false, "NetworkManager not set")
		return
	
	if not _network_manager.has_method("setup_eos_async"):
		eos_initialized.emit(false, "NetworkManager missing setup_eos_async")
		return
	
	var config_file := ConfigFile.new()
	var load_ok := config_file.load("res://eos_config.cfg")
	if load_ok != OK:
		eos_initialized.emit(false, "Cannot load res://eos_config.cfg")
		return
	
	var creds := Dictionary()
	creds["product_name"] = config_file.get_value("eos", "product_name", "3D Race")
	creds["product_version"] = config_file.get_value("eos", "product_version", "0.1")
	creds["product_id"] = config_file.get_value("eos", "product_id", "")
	creds["sandbox_id"] = config_file.get_value("eos", "sandbox_id", "")
	creds["deployment_id"] = config_file.get_value("eos", "deployment_id", "")
	creds["client_id"] = config_file.get_value("eos", "client_id", "")
	creds["client_secret"] = config_file.get_value("eos", "client_secret", "")
	creds["encryption_key"] = config_file.get_value("eos", "encryption_key", "")
	
	## Validate required fields
	if creds["product_id"].is_empty() or creds["sandbox_id"].is_empty() \
			or creds["deployment_id"].is_empty() or creds["client_id"].is_empty():
		eos_initialized.emit(false,
				"EOS credentials incomplete: please fill product_id / sandbox_id / deployment_id / client_id / client_secret in res://eos_config.cfg")
		return
	
	var success: bool = await _network_manager.setup_eos_async(creds)
	if not success:
		eos_initialized.emit(false, "EOS initialization failed, check Output / HPlatform log")
		return
	
	_is_eos_ready = true
	eos_initialized.emit(true, "")

## --- Login/Logout ---

func login(provider: String = "") -> void:
	if not _is_eos_ready:
		login_failed.emit("EOS not initialized, call init_eos() first")
		return
	
	var method := provider.strip_edges()
	if method.is_empty():
		## Read from config if no provider specified
		var config := ConfigFile.new()
		if config.load("res://eos_config.cfg") == OK:
			method = config.get_value("login", "method", "account_portal")
		else:
			method = "account_portal"
	
	match method:
		"epic", "account_portal":
			_login_account_portal()
		"discord":
			_login_discord()
		"anonymous":
			_login_anonymous()
		_:
			login_failed.emit("Unknown login method: %s" % method)

func _login_account_portal() -> void:
	var auth_node := _get_hauth()
	if auth_node == null or not auth_node.has_method("login_account_portal_async"):
		login_failed.emit("EOS runtime not ready")
		return
	var ok: bool = await auth_node.login_account_portal_async()
	if not ok:
		login_failed.emit("Epic Account Portal login failed")

func _login_discord() -> void:
	var config := ConfigFile.new()
	if config.load("res://eos_config.cfg") != OK:
		login_failed.emit("Cannot load res://eos_config.cfg")
		return
	var client_id: String = config.get_value("discord", "client_id", "")
	if client_id.is_empty():
		login_failed.emit("Discord client_id not set (please set in eos_config.cfg [discord])")
		return
	
	_discord_state = _random_state()
	_oauth_state = _discord_state
	var redirect_uri := "http://localhost:14514/callback"
	var scope := "identify"
	var url := "https://discord.com/api/oauth2/authorize?client_id=%s&redirect_uri=%s&response_type=code&scope=%s&state=%s" % [
		client_id, redirect_uri.uri_encode(), scope, _oauth_state
	]
	_start_oauth_server()
	OS.shell_open(url)
	discord_oauth_started.emit()

func _start_oauth_server() -> void:
	_stop_oauth_server()
	_oauth_server = TCPServer.new()
	var err := _oauth_server.listen(14514)
	if err != OK:
		_oauth_server = null
		discord_oauth_completed.emit("", "Cannot start callback server (port 14514)")
		return

func _stop_oauth_server() -> void:
	if _oauth_server:
		_oauth_server.stop()
		_oauth_server = null

func _random_state() -> String:
	var s := ""
	for i in range(32):
		s += "0123456789abcdef"[randi() % 16]
	return s

func _login_anonymous() -> void:
	login_anonymous()

func login_anonymous(display_name: String = "") -> void:
	if not _is_eos_ready:
		login_failed.emit("EOS not initialized")
		return
	var auth_node := _get_hauth()
	if auth_node == null or not auth_node.has_method("login_anonymous_async"):
		login_failed.emit("EOS runtime not ready")
		return
	if display_name.is_empty():
		display_name = "Player_%d" % randi_range(1000, 9999)
	var ok: bool = await auth_node.login_anonymous_async(display_name)
	if not ok:
		login_failed.emit("Anonymous login failed")

func try_persistent_login() -> bool:
	if not _is_eos_ready:
		return false
	var auth_node := _get_hauth()
	if auth_node == null or not auth_node.has_method("login_persistent_auth_async"):
		return false
	_suppress_login_error = true
	var ok: bool = await auth_node.login_persistent_auth_async()
	_suppress_login_error = false
	return ok

func logout_user() -> void:
	if not _is_logged_in:
		return
	_is_logged_in = false
	_display_name = ""
	_product_user_id = ""
	if _player_storage != null and _player_storage.has_method("delete_persistent_auth_async"):
		await _player_storage.delete_persistent_auth_async()
	logout.emit()

## --- Profile Management (Cloud + Local) ---

func save_profile(profile: Dictionary) -> bool:
	if not _is_logged_in or _player_storage == null:
		return false
	if not _player_storage.has_method("is_available") or not _player_storage.is_available():
		return false
	
	var json_text := JSON.stringify(profile)
	var opts = _player_storage.get_class("PlayerDataStorage").new_write_file_options()
	opts.local_user_id = _product_user_id
	opts.filename = "profile.json"
	opts.data = json_text.to_utf8_buffer()
	opts.chunk_length_bytes = 4096
	
	var write_cb = _player_storage.get_class("PlayerDataStorage").new()
	write_cb.playerdatastorage_interface_write_file_data_callback.connect(_on_write_file_data)
	
	var eos = _player_storage.get_class("PlayerDataStorage").new()
	eos.PlayerDataStorage.PlayerDataStorageInterface.write_file(opts)
	var ret = await write_cb
	return bool(_environment_manager.is_success(ret) if _environment_manager != null else false)

func load_profile() -> Dictionary:
	if not _is_logged_in or _player_storage == null:
		return {}
	if not _player_storage.has_method("is_available") or not _player_storage.is_available():
		return {}
	
	var opts = _player_storage.get_class("PlayerDataStorage").new_read_file_options()
	opts.local_user_id = _product_user_id
	opts.filename = "profile.json"
	opts.read_chunk_length_bytes = 4096
	
	var read_buffer := PackedByteArray()
	var read_cb = _player_storage.get_class("PlayerDataStorage").new()
	read_cb.playerdatastorage_interface_read_file_data_callback.connect(_on_read_file_data)
	
	var eos = _player_storage.get_class("PlayerDataStorage").new()
	eos.PlayerDataStorage.PlayerDataStorageInterface.read_file(opts)
	var ret = await read_cb
	
	if not bool(_environment_manager.is_success(ret) if _environment_manager != null else false):
		return {}
	
	var json_text: String = ret.get("data_chunk", PackedByteArray()).get_string_from_utf8()
	var parsed = JSON.parse_string(json_text)
	return parsed as Dictionary if parsed is Dictionary else {}

func has_profile() -> bool:
	if not _is_logged_in or _player_storage == null:
		return false
	if not _player_storage.has_method("is_available") or not _player_storage.is_available():
		return false
	
	var opts = _player_storage.get_class("PlayerDataStorage").new_query_file_options()
	opts.local_user_id = _product_user_id
	opts.filename = "profile.json"
	
	var query_cb = _player_storage.get_class("PlayerDataStorage").new()
	var eos = _player_storage.get_class("PlayerDataStorage").new()
	eos.PlayerDataStorage.PlayerDataStorageInterface.query_file(opts)
	var ret = await query_cb
	return bool(_environment_manager.is_success(ret) if _environment_manager != null else false)

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

## --- Internal: Discord OAuth callback handling ---

var _oauth_server: TCPServer = null
var _oauth_state := ""
var _discord_http = null
var _discord_auth_code := ""
var _discord_conn = null
var _discord_conn_time := 0.0
var _discord_state := ""

func _process(delta: float) -> void:
	if _oauth_server and _oauth_server.is_connection_available():
		_discord_conn = _oauth_server.take_connection()
		_discord_conn_time = 0.0
	if _discord_conn:
		_discord_conn_time += delta
		if _discord_conn.get_available_bytes() > 0:
			_handle_oauth_response(_discord_conn)
		elif _discord_conn_time > 10.0:
			_discord_conn.disconnect_from_host()
			_discord_conn = null
			discord_oauth_completed.emit("", "Callback timeout")

func _handle_oauth_response(conn: Object) -> void:
	var raw = conn.get_data(conn.get_available_bytes())
	var data := ""
	if raw.size() > 1 and raw[1] is PackedByteArray:
		data = raw[1].get_string_from_utf8()
	_stop_oauth_server()
	_discord_conn = null
	
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
	
	var body := "<html><body><h2>Closed, please return to the game.</h2></body></html>"
	var resp := "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\n\r\n%s" % [body.length(), body]
	conn.put_data(resp.to_utf8_buffer())
	conn.disconnect_from_host()
	
	if error.is_empty() and code.is_empty():
		discord_oauth_completed.emit("", "Auth failed: no code received")
		return
	if state != _oauth_state:
		discord_oauth_completed.emit("", "Auth failed: state mismatch (possible CSRF)")
		return
	_discord_auth_code = code
	discord_oauth_completed.emit(code, "")

func _on_discord_oauth_completed(code: String, error: String) -> void:
	if not error.is_empty():
		login_failed.emit(error)
		return
	if code.is_empty():
		login_failed.emit("Discord auth failed")
		return
	## Exchange code for token and login
	var eos_class := _get_eos_class()
	if eos_class == null:
		login_failed.emit("EOS class not loaded")
		return
	
	var opts = eos_class.Auth.LoginOptions.new()
	opts.credentials = eos_class.Auth.Credentials.new()
	opts.credentials.type = eos_class.Auth.LoginCredentialType.ExternalAuth
	opts.credentials.external_type = eos_class.ExternalCredentialType.DiscordAccessToken
	opts.credentials.token = _discord_auth_code
	opts.scope_flags = eos_class.Auth.ScopeFlags.None
	opts.login_flags = eos_class.Auth.LoginFlags.None
	
	var ok: bool = await _get_hauth().login_async(opts)
	if not ok:
		login_failed.emit("Discord login failed (Discord account not linked to Epic account)")

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

func _get_eos_class() -> Object:
	return load("res://addons/epic-online-services-godot/eos.gd") as GDScript

func _get_node(path: String) -> Node:
	return get_node_or_null(path)

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

# Suppress persistent login error flag (compatibility)
var _suppress_login_error := false
