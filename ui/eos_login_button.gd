extends Button

## 主選單右上角的 EOS 登入按鈕。
## 未登入：顯示「登入」或「Discord 登入」，點擊後依 eos_config.cfg 的 [login] method 登入。
## 登入中：顯示「登入中…」（並停用按鈕）。
## 已登入：顯示「玩家名稱」+ 狀態點。

const LOGIN_TEXT := "登入"
const DISCORD_LOGIN_TEXT := "Discord 登入"
const LOGGING_IN_TEXT := "登入中…"

var _login_pending_after_init := false
var _login_method := "devtool"

func _ready() -> void:
	pressed.connect(_on_pressed)

	NetworkManager.eos_initialized.connect(_on_eos_initialized)
	NetworkManager.login_succeeded.connect(_on_login_succeeded)
	NetworkManager.login_failed.connect(_on_login_failed)
	NetworkManager.logged_out.connect(_on_logged_out)

	_detect_login_method()

	if NetworkManager.is_eos_ready:
		_refresh()
	else:
		text = LOGIN_TEXT
		disabled = false


func _detect_login_method() -> void:
	var config := ConfigFile.new()
	if config.load(NetworkManager.EOS_CONFIG_PATH) == OK:
		_login_method = config.get_value("login", "method", "devtool")


func _on_pressed() -> void:
	if not NetworkManager.is_eos_ready:
		text = LOGGING_IN_TEXT
		disabled = true
		_login_pending_after_init = true
		NetworkManager.init_eos()
		return
	text = LOGGING_IN_TEXT
	disabled = true
	NetworkManager.login()


func _on_eos_initialized(success: bool, _message: String) -> void:
	if success:
		_refresh()
		if _login_pending_after_init:
			_login_pending_after_init = false
			text = LOGGING_IN_TEXT
			disabled = true
			NetworkManager.login()
		return
	_login_pending_after_init = false
	text = _get_login_text()
	disabled = false
	NetworkManager.login_failed.emit("EOS 初始化失敗")


func _on_login_succeeded() -> void:
	_refresh()


func _on_login_failed(_message: String) -> void:
	text = _get_login_text()
	disabled = false


func _on_logged_out() -> void:
	text = _get_login_text()
	disabled = false


func _refresh() -> void:
	if NetworkManager.is_logged_in:
		text = "%s\n● 已連線" % NetworkManager.display_name
		disabled = true
	else:
		text = _get_login_text()
		disabled = false


func _get_login_text() -> String:
	_detect_login_method()
	if _login_method == "discord":
		var config := ConfigFile.new()
		if config.load(NetworkManager.EOS_CONFIG_PATH) == OK:
			var dc_id: String = config.get_value("discord", "client_id", "")
			if not dc_id.is_empty():
				return DISCORD_LOGIN_TEXT
	return LOGIN_TEXT
