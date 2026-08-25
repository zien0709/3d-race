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

## 傳輸層選擇：開發階段用 ENET（IP 直連本機測試），
## 多人架構驗證完成後切成 EOS（維持現有 EOSGMultiplayerPeer 流程）。
## 遊戲邏輯層（RPC / Synchronizer / Spawner）與傳輸層無關，不受此切換影響。
enum Transport {
	ENET,
	EOS,
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
## 開發階段預設 ENET；架構驗證完成後切到 EOS。
var transport: int = Transport.EOS
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


func set_transport(new_transport: int) -> void:
	if transport == new_transport:
		return
	transport = new_transport
	print("NetworkManager: transport 切換為 %s" % ["ENET", "EOS"][transport])
	# 若已連線，需重連才生效
	if is_online():
		print("警告：已在線上狀態，需重新連線才生效新傳輸層")


func is_online() -> bool:
	return mode != Mode.SINGLEPLAYER


func is_host() -> bool:
	return mode == Mode.HOST

func send_chat_message(message: String) -> void:
	## Send chat message via EOS party system
	## TODO: Implement actual EOS party chat message sending
	## For now, print to console for testing
	var nm = get_node_or_null("/root/NetworkManager")
	if nm != null:
		var display: String = nm.get_display_name()
		if display.is_empty():
			display = "Player"
		print("[Chat] %s: %s" % [display, message])

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


## Device ID 登入
func login_device_id() -> void:
	if not is_eos_ready:
		login_failed.emit("EOS 尚未初始化")
		return
	var hauth := _hauth()
	if hauth == null or not hauth.has_method("login_device_id_async"):
		login_failed.emit("EOS 執行期未就緒")
		return
	var ok: bool = await hauth.login_device_id_async("Device")
	if not ok:
		login_failed.emit("Device ID 登入失敗")


## Connect 匿名登入（device id，不需 EAS / Account Portal）。
## 適合開發與本機多人測試。
func login_anonymous(p_display_name := "") -> void:
	if not is_eos_ready:
		login_failed.emit("EOS 尚未初始化")
		return
	var hauth := _hauth()
	if hauth == null or not hauth.has_method("login_anonymous_async"):
		login_failed.emit("EOS 執行期未就緒")
		return
	if p_display_name.is_empty():
		p_display_name = "Player_%d" % randi_range(1000, 9999)
	var ok: bool = await hauth.login_anonymous_async(p_display_name)
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
	match transport:
		Transport.ENET:
			var peer := ENetMultiplayerPeer.new()
			var err := peer.create_server(24565, MAX_PLAYERS)
			if err != OK:
				return err
			_attach_peer(peer)
			set_mode(Mode.HOST)
			return OK

		Transport.EOS:
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

	return ERR_UNCONFIGURED


## 加入 host 的房：host_user_id 是 host 的 EOS product user id（從 lobby 取得）。
func join_game(host_user_id: String, port: int = 24565) -> int:
	match transport:
		Transport.ENET:
			var peer := ENetMultiplayerPeer.new()
			var err := peer.create_client(host_user_id, port)
			if err != OK:
				return err
			_attach_peer(peer)
			set_mode(Mode.CLIENT)
			return OK

		Transport.EOS:
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

	return ERR_UNCONFIGURED


## 斷開網路連線，回到單人模式。
func disconnect_from_game() -> void:
	if _peer:
		multiplayer.multiplayer_peer = null
		_peer = null
	if is_online():
		set_mode(Mode.SINGLEPLAYER)


func get_peer_user_id(peer_id: int) -> String:
	if _peer and _peer.has_method("get_peer_user_id"):
		return _peer.get_peer_user_id(peer_id)
	return ""


func get_peer_id_for_user(user_id: String) -> int:
	if _peer and _peer.has_method("get_peer_id"):
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


func _on_eos_log(_msg) -> void:
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
	_exchange_code_for_token(code)
