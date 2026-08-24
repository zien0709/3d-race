extends Control

## LobbyMain - Main lobby coordinator
## Thin controller that manages component communication and LobbyManager integration

signal start_requested(player_name: String)

## Component references
@onready var header: Control = $Header
@onready var inspector: Control = $MainContainer/LeftPanel/Inspector
@onready var chat_trigger: Control = $MainContainer/LeftPanel/ChatTrigger
@onready var showcase: Control = $MainContainer/CenterRightPanel/Showcase
@onready var ready_button: Control = $MainContainer/CenterRightPanel/ReadyButton
@onready var floating_chat: Control = $FloatingChat
@onready var room_overlay: Control = $RoomOverlay
@onready var lobby_browser: Control = $LobbyBrowser
@onready var customize_view: Control = $CustomizeView
@onready var toast: Control = $Toast

## State
var selected_id: String = ""
var chat_open: bool = false
var chat_tab: String = "room"
var room_overlay_open: bool = false
var customize_view_open: bool = false
var is_ready: bool = false

## Room config (persisted)
var room_config: Dictionary = {
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

## Lobby data
var players: Array = []
var chat_messages: Array = []

## Singleton references
var lobby_manager: Object = null
var auth_manager: Object = null

func _ready() -> void:
	_init_signals()
	_connect_components()
	_refresh_all()

func _init_signals() -> void:
	auth_manager = get_node_or_null("/root/AuthManager")
	if auth_manager != null:
		auth_manager.login_succeeded.connect(_on_auth_succeeded)
		auth_manager.login_failed.connect(_on_auth_failed)
		auth_manager.eos_initialized.connect(_on_eos_initialized)

	lobby_manager = get_node_or_null("/root/LobbyManager")
	if lobby_manager != null:
		lobby_manager.member_joined.connect(_on_member_joined)
		lobby_manager.member_left.connect(_on_member_left)
		lobby_manager.ready_state_changed.connect(_on_ready_state_changed)
		lobby_manager.match_started.connect(_on_match_started)
		lobby_manager.lobby_created.connect(_on_lobby_created)
		lobby_manager.lobby_joined.connect(_on_lobby_joined)

func _connect_components() -> void:
	## Header signals
	header.room_settings_requested.connect(_on_room_settings_requested)
	header.create_room_requested.connect(_on_create_room_requested)
	header.leave_room_requested.connect(_on_leave_room_requested)
	header.leave_lobby_requested.connect(_on_leave_lobby_requested)
	header.browser_requested.connect(_on_browser_requested)

	## Inspector signals
	inspector.customize_requested.connect(_on_customize_requested)

	## Chat signals
	chat_trigger.chat_toggled.connect(_on_chat_toggled)
	floating_chat.tab_changed.connect(_on_chat_tab_changed)
	floating_chat.message_sent.connect(_on_chat_message_sent)
	floating_chat.closed.connect(_on_chat_closed)

	## Showcase signals
	showcase.slot_selected.connect(_on_showcase_slot_selected)

	## Ready button signals
	ready_button.pressed.connect(_on_ready_pressed)

	## Room overlay signals
	room_overlay.config_changed.connect(_on_room_config_changed)
	room_overlay.saved.connect(_on_room_overlay_saved)
	room_overlay.cancelled.connect(_on_room_overlay_cancelled)

	## Lobby browser signals
	lobby_browser.search_requested.connect(_on_lobby_search_requested)
	lobby_browser.join_requested.connect(_on_lobby_join_requested)
	lobby_browser.closed.connect(_on_lobby_browser_closed)

	## Customize signals
	customize_view.back_requested.connect(_on_customize_back)

	## Toast
	# No signals needed

## --- AuthManager signal handlers ---

func _on_auth_succeeded(display_name: String) -> void:
	_refresh_all()

func _on_auth_failed(message: String) -> void:
	_refresh_all()

func _on_eos_initialized(success: bool, message: String) -> void:
	_refresh_all()

## --- LobbyManager signal handlers ---

func _on_member_joined(player_id: String) -> void:
	_refresh_players()
	_refresh_all()

func _on_member_left(player_id: String) -> void:
	if selected_id == player_id:
		selected_id = ""
	_refresh_players()
	_refresh_all()

func _on_ready_state_changed(ready_map: Dictionary) -> void:
	is_ready = ready_map.get("local_player_peer_id", false) or ready_map.size() > 0
	ready_button.update_ready_state(is_ready, lobby_manager)
	_refresh_all()

func _on_match_started(_order: Array) -> void:
	start_requested.emit("")

func _on_lobby_created(info: Dictionary) -> void:
	_refresh_all()

func _on_lobby_joined(info: Dictionary) -> void:
	_refresh_players()
	_refresh_all()

## --- Component signal handlers ---

func _on_room_settings_requested() -> void:
	room_overlay_open = true
	room_overlay.open(room_config)
	_refresh_all()

func _on_create_room_requested() -> void:
	if lobby_manager == null:
		show_toast("Lobby module not loaded")
		return
	if not _net_is_logged_in():
		show_toast("請先登入（點左上玩家卡）")
		return
	if not lobby_manager.current_lobby.is_empty():
		show_toast("已在房間中")
		return
	room_overlay_open = false
	show_toast("正在建立房間…")
	lobby_manager.create_lobby(room_config)

func _on_leave_room_requested() -> void:
	room_overlay_open = false
	var lm := lobby_manager
	if lm != null and not lm.current_lobby.is_empty():
		await lm.leave_lobby()
		show_toast("已離開房間")
		_refresh_players()
		_refresh_all()

func _on_leave_lobby_requested() -> void:
	var lm := lobby_manager
	if lm != null and not lm.current_lobby.is_empty():
		await lm.leave_lobby()
		show_toast("已離開房間")
		_refresh_players()
		_refresh_all()

func _on_browser_requested() -> void:
	lobby_browser.open()
	_refresh_all()

func _on_customize_requested() -> void:
	customize_view_open = true
	customize_view.open()
	_refresh_all()

func _on_chat_toggled(opened: bool) -> void:
	chat_open = opened
	floating_chat.visible = chat_open
	if chat_open:
		floating_chat.focus_input()
	_refresh_all()

func _on_chat_closed() -> void:
	chat_open = false
	chat_trigger.set_chat_open(false)
	_refresh_all()

func _on_chat_tab_changed(tab: String) -> void:
	chat_tab = tab
	floating_chat.set_active_tab(chat_tab)

func _on_chat_message_sent(text: String) -> void:
	var t := text.strip_edges()
	if t == "":
		return
	chat_messages.append(["You", t])
	floating_chat.add_message("You", t, true)

func _on_showcase_slot_selected(index: int, is_self: bool) -> void:
	if index >= players.size():
		return
	var p: Dictionary = players[index]
	if selected_id == p["id"] and p["is_self"]:
		customize_view_open = true
		customize_view.open()
	else:
		selected_id = p["id"]
	_refresh_all()

func _on_ready_pressed() -> void:
	start_requested.emit("")

func _on_room_config_changed(row: String, value: String) -> void:
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
	room_overlay.update_chips()
	_refresh_all()

func _on_room_overlay_saved() -> void:
	var new_name: String = str(room_overlay.get_room_name())
	if new_name != "":
		room_config["name"] = new_name
	room_overlay_open = false
	if lobby_manager != null and lobby_manager.is_host and not lobby_manager.current_lobby.is_empty():
		lobby_manager.update_lobby_settings(room_config)
	show_toast("設定已儲存")
	_refresh_all()

func _on_room_overlay_cancelled() -> void:
	room_overlay_open = false
	_refresh_all()

func _on_lobby_search_requested() -> void:
	lobby_browser.set_status("搜尋中…")
	if not _net_is_logged_in():
		show_toast("請先登入（點左上玩家卡）")
		lobby_browser.close()
		return
	if lobby_manager == null:
		show_toast("房間模組未就緒")
		lobby_browser.close()
		return
	call_deferred("_do_search")

func _do_search() -> void:
	lobby_manager.browser_busy = true
	lobby_browser.set_status("搜尋中…")
	var results: Array = await lobby_manager.search_lobbies()
	lobby_manager.browser_busy = false
	lobby_manager.browser_results = results
	lobby_browser.set_results(results, lobby_manager)

func _on_lobby_join_requested(lb) -> void:
	var lm := lobby_manager
	if lm == null:
		show_toast("Lobby module not loaded")
		return
	show_toast("正在加入房間…")
	lm.join_lobby(lb)

func _on_lobby_browser_closed() -> void:
	lobby_browser.close()
	_refresh_all()

func _on_customize_back() -> void:
	customize_view_open = false
	customize_view.close()
	_refresh_all()

## --- Refresh methods ---

func show_toast(msg: String) -> void:
	if toast != null and toast.has_method("show_message"):
		toast.show_message(msg)
	else:
		push_warning(msg)

func _refresh_all() -> void:
	_refresh_header()
	_refresh_inspector()
	_refresh_showcase()
	_refresh_ready_button()

func _refresh_header() -> void:
	var nm_display := ""
	if lobby_manager != null:
		nm_display = str(lobby_manager.get_display_name())
	header.update_user_card(nm_display, lobby_manager)
	header.update_room_card(room_config, players, lobby_manager)

func _refresh_inspector() -> void:
	var p := _get_selected_player()
	inspector.update_player(p)

func _refresh_showcase() -> void:
	showcase.update_slots(players, selected_id)

func _refresh_ready_button() -> void:
	var nm := auth_manager
	var lm := lobby_manager
	var online: bool = nm != null and lm != null and lm.has_method("is_online") and lm.is_online()
	if not online:
		ready_button.set_offline_mode()
		return
	if lm != null and lm.is_host and _all_lobby_ready():
		ready_button.set_host_ready_mode()
		return
	if is_ready:
		ready_button.set_ready_mode()
	else:
		ready_button.set_waiting_mode()

func _refresh_players() -> void:
	if lobby_manager == null:
		players = []
		return
	
	var lm := lobby_manager
	
	# Query local player name from PlayerStorage profile
	var player_name := "玩家"
	var auth := get_node_or_null("/root/AuthManager")
	if auth != null and auth.is_eos_ready:
		var ps := auth._ensure_player_storage()
		if ps != null and ps.has_method("load_profile"):
			var saved := ps.load_profile()
			if saved.has("display_name"):
				player_name = saved["display_name"]
	
	new_players: Array = []
	for member in lm.players:
		var pid: String = member.get("product_user_id", "")
		var is_self: bool = pid == lm.get_local_player_id()
		# Name from member attribute; fallback to stored profile or "玩家"
		var name := member.get("name", player_name)
		if name.is_empty():
			name = player_name
		
		# Use stored stats if available, otherwise defaults
		var stats := member.has_method("get_stats") ? member.get_stats() : {"speed": 0.85, "handling": 0.72, "accel": 0.90}
		
		new_players.append({
			"id": pid,
			"name": name,
			"car_name": "Default Car",
			"score": int(stats.speed * 1000),  # approximate score from speed stat
			"cls": "S",
			"rank": "大師 I",
			"best_lap": "1:23.456",
			"matches": [true, false, true, true, false],
			"stats": stats,
			"is_self": is_self
		})
	
	players = new_players
	if selected_id == "" and players.size() > 0:
		selected_id = players[0]["id"]
	
	_refresh_inspector()

func _get_selected_player() -> Dictionary:
	for p in players:
		if p["id"] == selected_id:
			return p
	if players.is_empty():
		return {}
	return players[0]

func _net_is_logged_in() -> bool:
	if lobby_manager != null and lobby_manager.has_method("_nm"):
		var nm = lobby_manager._nm()
		return nm != null and nm.is_logged_in
	return false

func _all_lobby_ready() -> bool:
	var lm := lobby_manager
	if lm == null:
		return false
	var lp: Array = lm.players if "players" in lm else []
	for p in lp:
		if p is Dictionary and not p.get("ready", false):
			return false
	return true

func _on_lobby_result(kind: String, info: Dictionary) -> void:
	lobby_manager.browser_busy = false
	if info.is_empty():
		show_toast("失敗：%s 失敗" % ("開房" if kind == "created" else "加入"))
		return
	lobby_browser.close()
	room_overlay_open = false
	room_config["invite_code"] = str(info.get("lobby_id", "")).substr(0, 12).to_upper()
	if info.get("is_host", false):
		show_toast("已開房，等待其他玩家加入")
	else:
		show_toast("已加入房間")
	_refresh_players()
	_refresh_all()