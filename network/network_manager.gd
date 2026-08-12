extends Node

## 網路管理：單人 / 開房(host) / 加入(client)。
## 線上模式透過 Epic Online Services (EOSG 插件)：
##  - 登入：Epic Dev Auth Tool（開發）或 Epic Account Portal
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

const LOCAL_PEER_ID := 1
const MAX_PLAYERS := 12  ## 連線數上限（配合 12 格出發位置）
const EOS_CONFIG_PATH := "res://eos_config.cfg"
const EOS_SOCKET_ID := "race_3d"

var mode: int = Mode.SINGLEPLAYER
var is_eos_ready := false
var is_logged_in := false
var display_name := ""
var product_user_id := ""

var _peer = null


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func set_mode(new_mode: int) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	mode_changed.emit(mode)


func is_online() -> bool:
	return mode != Mode.SINGLEPLAYER


func is_host() -> bool:
	return mode == Mode.HOST


func _hauth() -> Variant:
	return get_node_or_null("/root/HAuth")


func _hplatform() -> Variant:
	return get_node_or_null("/root/HPlatform")


func _hlog() -> Variant:
	return get_node_or_null("/root/HLog")


# ==========================================================================
# EOS 初始化與登入
# ==========================================================================

## 讀取 eos_config.cfg 並初始化 EOS SDK + Platform。
func init_eos() -> void:
	if is_eos_ready:
		eos_initialized.emit(true, "")
		return
	var hp = _hplatform()
	var hauth = _hauth()
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

	var hlog = _hlog()
	if hlog != null:
		hlog.log_level = int(hlog.LogLevel.INFO) if "LogLevel" in hlog else 0
	hp.log_msg.connect(_on_eos_log, CONNECT_DEFERRED)
	hauth.logged_in.connect(_on_logged_in)
	hauth.logged_out.connect(_on_logged_out)

	var setup_success: bool = await hp.setup_eos_async(creds)
	if not setup_success:
		eos_initialized.emit(false, "EOS 初始化失敗，詳見 Output / HPlatform log")
		return

	is_eos_ready = true
	eos_initialized.emit(true, "")


## 依設定檔 [login] method 選擇登入方式（devtool / account_portal）
func login() -> void:
	if not is_eos_ready:
		login_failed.emit("EOS 尚未初始化，請先呼叫 init_eos()")
		return
	var config := ConfigFile.new()
	if config.load(EOS_CONFIG_PATH) == OK:
		var method: String = config.get_value("login", "method", "devtool")
		if method == "account_portal":
			login_account_portal()
			return
		if method == "anonymous":
			login_anonymous()
			return
	login_devtool()


## Epic Dev Auth Tool 登入（開發用，需先開 DevAuthTool）
func login_devtool(server_url := "", credential_name := "") -> void:
	if not is_eos_ready:
		login_failed.emit("EOS 尚未初始化")
		return
	var hauth = _hauth()
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
	var hauth = _hauth()
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
	var hauth = _hauth()
	if hauth == null or not hauth.has_method("login_anonymous_async"):
		login_failed.emit("EOS 執行期未就緒")
		return
	if display_name.is_empty():
		display_name = "Player_%d" % randi_range(1000, 9999)
	var ok: bool = await hauth.login_anonymous_async(display_name)
	if not ok:
		login_failed.emit("匿名登入失敗")


func logout() -> void:
	if not is_logged_in:
		return
	disconnect_from_game()
	var hauth = _hauth()
	if hauth != null and hauth.has_method("logout_async"):
		await hauth.logout_async()


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
	var hauth = _hauth()
	display_name = hauth.get("display_name", "") if hauth != null else ""
	product_user_id = hauth.get("product_user_id", "") if hauth != null else ""
	login_succeeded.emit()


func _on_logged_out() -> void:
	is_logged_in = false
	display_name = ""
	product_user_id = ""
	logged_out.emit()


func _on_eos_log(msg) -> void:
	## 之後可接 UI / 檔案 log
	pass
