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
	match _requested_provider:
		"epic":
			NetworkManager.login_account_portal()
		"discord":
			NetworkManager.login_discord()
		_:
			_on_login_failed("此登入提供者尚未設定")


func _on_login_succeeded() -> void:
	if not _auth_in_progress:
		return
	_auth_in_progress = false
	_set_auth_controls(false)
	# 從雲端（PlayerDataStorage）或本地快取讀回暱稱
	var saved_name := await _restore_display_name()
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
