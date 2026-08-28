extends Control

## LobbyMain - Main lobby coordinator
## Thin controller that manages component communication and LobbyManager integration

signal start_requested(player_name: String)

## Component references
@onready var header: Control = $Header
@onready var inspector: Control = $MainContainer/LeftPanel/LeftContent/Inspector
@onready var chat_trigger: Control = $MainContainer/LeftPanel/ChatTrigger
@onready var showcase: Control = $MainContainer/CenterRightPanel/Showcase
@onready var ready_button: Control = $BottomBar/ReadyButton
@onready var chat_preview: Control = $BottomBar/ChatPreview
@onready var quick_phrases: Control = $BottomBar/QuickPhrases
@onready var floating_chat: Control = $MainContainer/LeftPanel/LeftContent/FloatingChat
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
var auto_start_countdown_end: float = 0.0

## Room config (persisted)
var room_config: Dictionary = {
	"name": "",
	"map": "東京灣夜景",
	"mode": "經典競速",
	"privacy": "public",
	"max_players": 0,
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
	# 若登入已在 _ready 前完成（boot 階段 persistent login），補觸發
	if auth_manager != null and auth_manager.is_logged_in:
		# 從 PlayerStorage 讀取暱稱（HAuth 可能沒有 display_name）
		if auth_manager.display_name().is_empty():
			var ps = get_node_or_null("/root/PlayerStorage")
			if ps != null and ps.has_method("is_available") and ps.is_available():
				var profile = await ps.load_profile()
				if profile.has("display_name") and str(profile["display_name"]) != "":
					auth_manager._display_name = str(profile["display_name"])
		_on_auth_succeeded(auth_manager.display_name())
	_refresh_all()

func _init_signals() -> void:
	auth_manager = get_node_or_null("/root/AuthManager")
	if auth_manager != null:
		auth_manager.login_succeeded.connect(_on_auth_succeeded)
		auth_manager.login_failed.connect(_on_auth_failed)
		auth_manager.eos_initialized.connect(_on_eos_initialized)

	var nm = get_node_or_null("/root/NetworkManager")
	if nm != null:
		nm.chat_message_received.connect(_on_chat_message_received)

	lobby_manager = get_node_or_null("/root/LobbyManager")
	if lobby_manager != null:
		lobby_manager.member_joined.connect(_on_member_joined)
		lobby_manager.member_left.connect(_on_member_left)
		lobby_manager.ready_state_changed.connect(_on_ready_state_changed)
		lobby_manager.match_started.connect(_on_match_started)
		lobby_manager.lobby_created.connect(_on_lobby_created)
		lobby_manager.lobby_joined.connect(_on_lobby_joined)
		lobby_manager.room_config_updated.connect(_on_room_config_updated)

func _connect_components() -> void:
	## Header signals
	header.room_settings_requested.connect(_on_room_settings_requested)
	header.system_settings_requested.connect(_on_system_settings_requested)
	header.invite_requested.connect(_on_invite_requested)
	header.leave_room_requested.connect(_on_leave_room_requested)

	## Inspector signals
	inspector.customize_requested.connect(_on_customize_requested)

	## Chat signals
	chat_trigger.chat_toggled.connect(_on_chat_toggled)
	floating_chat.tab_changed.connect(_on_chat_tab_changed)
	floating_chat.message_sent.connect(_on_chat_message_sent)
	floating_chat.closed.connect(_on_chat_closed)

	## Showcase signals
	showcase.slot_selected.connect(_on_showcase_slot_selected)

	## Bottom bar signals
	if quick_phrases != null and quick_phrases.has_signal("phrase_selected"):
		quick_phrases.phrase_selected.connect(_on_quick_phrase_selected)
	if chat_preview != null and chat_preview.has_signal("preview_clicked"):
		chat_preview.preview_clicked.connect(_on_chat_preview_clicked)

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

func _on_auth_succeeded(_display_name: String) -> void:
	_update_default_room_name()
	_auto_create_room_if_needed()
	_refresh_all()

func _on_auth_failed(_message: String) -> void:
	_refresh_all()

func _on_eos_initialized(_success: bool, _message: String) -> void:
	if _success:
		_update_default_room_name()
		_auto_create_room_if_needed()
	_refresh_all()

func _update_default_room_name() -> void:
	if room_config["name"] == "" and auth_manager != null:
		var display_name: String = str(auth_manager.display_name())
		if display_name != "":
			room_config["name"] = "%s的房間" % display_name
			room_config["host_name"] = display_name

func _auto_create_room_if_needed() -> void:
	if lobby_manager == null:
		return
	if not _net_is_logged_in():
		return
	if not lobby_manager.current_lobby.is_empty():
		return
	if room_overlay_open:
		return
	call_deferred("_do_auto_create_room")

func _do_auto_create_room() -> void:
	if lobby_manager == null or not _net_is_logged_in():
		return
	if not lobby_manager.current_lobby.is_empty():
		return
	show_toast("正在自動建立房間…")
	_update_default_room_name()
	await lobby_manager.create_lobby(room_config)

## --- LobbyManager signal handlers ---

func _on_member_joined(_player_id: String) -> void:
	_refresh_players()
	_refresh_all()

func _on_member_left(player_id: String) -> void:
	if selected_id == player_id:
		selected_id = ""
	_refresh_players()
	_refresh_all()

func _on_ready_state_changed(ready_map: Dictionary) -> void:
	is_ready = bool(ready_map.get("local_player_peer_id", false))
	_refresh_ready_button()
	_refresh_showcase()
	check_auto_start()

func _on_match_started(_order: Array) -> void:
	start_requested.emit("")

func _on_lobby_created(_info: Dictionary) -> void:
	_refresh_players()
	_refresh_all()

func _on_lobby_joined(_info: Dictionary) -> void:
	_refresh_players()
	_refresh_all()

func _on_room_config_updated(rc: Dictionary) -> void:
	# 非房主即時同步房主設定
	if lobby_manager != null and not lobby_manager.is_host:
		room_config = rc.duplicate(true)
		if room_overlay_open:
			room_overlay.open(room_config, false)
		_refresh_all()

## --- Component signal handlers ---

func _on_room_settings_requested() -> void:
	room_overlay_open = true
	var host_flag: bool = false
	if lobby_manager != null:
		host_flag = lobby_manager.is_host
	room_overlay.open(room_config, host_flag)
	_refresh_all()

func _on_system_settings_requested() -> void:
	show_toast("系統設定（即將推出）")

func _on_invite_requested() -> void:
	show_toast("好友列表（即將推出）")

func _on_leave_room_requested() -> void:
	room_overlay_open = false
	var lm := lobby_manager
	if lm != null and not lm.current_lobby.is_empty():
		await lm.leave_lobby()
		show_toast("已離開房間")
		_refresh_players()
		_refresh_all()

func _on_customize_requested() -> void:
	customize_view_open = true
	customize_view.open()
	_refresh_all()

func _on_chat_toggled(opened: bool) -> void:
	chat_open = opened
	floating_chat.visible = chat_open
	inspector.visible = not chat_open
	if chat_open:
		floating_chat.focus_input()
	_refresh_all()

func _on_chat_closed() -> void:
	chat_open = false

func _on_quick_phrase_selected(phrase: String) -> void:
	var sender_name := "玩家"
	if lobby_manager != null:
		sender_name = str(lobby_manager.get_display_name())
	_on_chat_message_received(sender_name, phrase, "room")
	if chat_preview != null and chat_preview.has_method("update_preview"):
		chat_preview.update_preview(sender_name, phrase)

func _on_chat_preview_clicked() -> void:
	chat_open = true
	floating_chat.visible = true
	inspector.visible = false
	floating_chat.focus_input()
	floating_chat.visible = false
	inspector.visible = true
	chat_trigger.set_chat_open(false)
	_refresh_all()

func _on_chat_tab_changed(tab: String) -> void:
	chat_tab = tab
	floating_chat.set_active_tab(chat_tab)
	_load_chat_history_for_tab(chat_tab)

func _load_chat_history_for_tab(tab: String) -> void:
	floating_chat.clear_messages()
	for msg in chat_messages:
		if msg.get("tab", "") == tab:
			var sender = msg.get("sender", "")
			var text = msg.get("text", "")
			var is_self = (sender == (auth_manager.display_name() if auth_manager != null else ""))
			floating_chat.add_message(sender, text, is_self)

func _on_chat_message_received(sender: String, text: String, tab: String) -> void:
	chat_messages.append({"sender": sender, "text": text, "tab": tab})
	if tab == chat_tab:
		var is_self = (sender == (auth_manager.display_name() if auth_manager != null else ""))
		floating_chat.add_message(sender, text, is_self)

func _on_chat_message_sent(text: String) -> void:
	var t := text.strip_edges()
	if t == "":
		return
	# Send via NetworkManager (EOS P2P chat)
	var nm = get_node_or_null("/root/NetworkManager")
	if nm != null and nm.has_method("send_chat_message"):
		nm.send_chat_message(t, chat_tab)
	# RPC will echo back; _on_chat_message_received handles display

func _on_showcase_slot_selected(index: int, _is_self: bool) -> void:
	if index >= players.size():
		return
	var p: Dictionary = players[index]
	# 雙擊自己的卡槽才進入改裝（需先選中再點一次，且 ID 非空）
	if not selected_id.is_empty() and selected_id == p["id"] and p["is_self"]:
		customize_view_open = true
		customize_view.open()
	else:
		selected_id = p["id"]
	_refresh_all()

func _on_ready_pressed() -> void:
	if lobby_manager == null:
		show_toast("Lobby module not loaded")
		return
	
	# 檢查是否為線上模式
	var online: bool = lobby_manager.has_method("is_online") and lobby_manager.is_online()
	
	if not online:
		# 離線模式：直接開始計時賽
		start_race()
		return
	
	# 線上模式邏輯
	if not _net_is_logged_in():
		show_toast("請先登入（點左上玩家卡）")
		return
	
	if lobby_manager.is_host:
		# House: 檢查是否所有人都已準備，若是則開始比賽
		if _all_lobby_ready(lobby_manager):
			show_toast("正在開始比賽...")
			start_race()
		else:
			show_toast("請等待所有玩家準備")
	else:
		# Client: 切換自己的就緒狀態
		if lobby_manager.has_method("set_ready"):
			var ready_map = lobby_manager.get_ready_map()
			var current_ready = bool(ready_map.get("local_player_peer_id", false))
			lobby_manager.set_ready(not current_ready)
		_refresh_all()

func check_auto_start() -> void:
	if not lobby_manager.is_host:
		return
	if _all_lobby_ready(lobby_manager):
		var auto_start = room_config.get("auto_start", "倒數10秒")
		if auto_start == "立即開始":
			show_toast("自動啟動比賽...")
			lobby_manager.start_match(true)
		elif auto_start == "倒數10秒":
			start_auto_countdown()

func start_auto_countdown() -> void:
	auto_start_countdown_end = Time.get_time_dict_from_system()["unix"] + 10.0
	var timer = get_tree().create_timer(10.0)
	await timer.timeout
	auto_start_countdown_end = 0.0
	if lobby_manager.is_host and _all_lobby_ready(lobby_manager):
		show_toast("自動啟動比賽...")
		lobby_manager.start_match(true)

func start_race() -> void:
	if lobby_manager == null:
		show_toast("Lobby module not loaded")
		return
	
	if room_config["name"] == "":
		show_toast("請先設定房間名稱")
		return
	
	# 離線模式不需要檢查 is_host
	var online: bool = lobby_manager.has_method("is_online") and lobby_manager.is_online()
	if online and not lobby_manager.is_host:
		show_toast("只有房主可以開始比賽")
		return
	
	if online and lobby_manager.current_lobby.is_empty():
		show_toast("目前沒有可開始的房間")
		return
	
	var auto_start: bool = room_config.get("auto_start", "倒數10秒") == "立即開始"
	
	if auto_start:
		show_toast("自動啟動比賽...")
		lobby_manager.start_match(true)
	else:
		show_toast("正在開始比賽...")
		lobby_manager.start_match()

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
		await lobby_manager.update_lobby_settings(room_config)
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
	# 若已在房間中
	if not lm.current_lobby.is_empty():
		var current_id: String = str(lm.current_lobby.get("lobby_id", ""))
		var target_id: String = str(lb.lobby_id) if "lobby_id" in lb else ""
		# 同一間房（相同 Godot 實例）→ 提示已在房中
		if current_id != "" and current_id == target_id:
			show_toast("已在這間房間中")
			return
		# 不同房間 → 自動離開再加入
		show_toast("已在房間中，先離開後再加入…")
		await lm.leave_lobby()
		_refresh_players()
		_refresh_all()
	show_toast("正在加入房間…")
	var join_timer := get_tree().create_timer(15.0)
	await lm.join_lobby(lb)
	if join_timer.time_left > 0.0:
		# 加入在逾時前完成
		if lm.current_lobby.is_empty():
			show_toast("加入失敗，請再試一次")
			lm.browser_busy = false
		else:
			_refresh_players()
			_refresh_all()
	else:
		show_toast("加入逾時，請再試一次")
		lm.browser_busy = false

func _on_lobby_browser_closed() -> void:
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
	_update_default_room_name()
	_refresh_players()
	_refresh_header()
	_refresh_inspector()
	_refresh_showcase()
	# ready_button must be refreshed LAST to avoid being overwritten
	_refresh_ready_button()
	var in_lobby: bool = lobby_manager != null and not lobby_manager.current_lobby.is_empty()
	if header != null and header.has_method("set_in_room"):
		header.set_in_room(in_lobby)

func _refresh_header() -> void:
	var nm_display := ""
	if lobby_manager != null:
		nm_display = str(lobby_manager.get_display_name())
	# Fallback: 從 PlayerStorage 讀暱稱
	if nm_display.is_empty() and auth_manager != null:
		nm_display = auth_manager.display_name()
	# Mock data for level/rank/ping (待接入真實 API)
	var mock_level := 1
	var mock_rank := "🥉 青銅 I"
	var mock_puid := ""
	if lobby_manager != null:
		mock_puid = str(lobby_manager.get_local_player_id())
	var mock_ping := 0
	header.update_profile(nm_display, mock_level, mock_rank, mock_puid, mock_ping)
	header.update_room_capsule(room_config, players, lobby_manager)

func _refresh_inspector() -> void:
	var p := _get_selected_player()
	inspector.update_player(p)

func _refresh_showcase() -> void:
	var max_p: int
	var in_lobby: bool = lobby_manager != null and not lobby_manager.current_lobby.is_empty()
	if in_lobby and lobby_manager.max_members > 0:
		max_p = lobby_manager.max_members
	else:
		max_p = int(room_config.get("max_players", 4))
		if max_p <= 0:
			max_p = 4
	showcase.set_max_slots(max_p)
	showcase.update_slots(players, selected_id)

func _refresh_ready_button() -> void:
	var nm := auth_manager
	var lm := lobby_manager
	var online: bool = nm != null and lm != null and lm.has_method("is_online") and lm.is_online()
	if not online:
		# Offline mode: always host, always enabled
		ready_button.set_mode(true, true, false)
		return
	var all_rdy: bool = _all_lobby_ready(lm)
	var is_host_state: bool = false
	if lm != null:
		is_host_state = lm.is_host
		# Safety: if we have players or are in lobby, check ownership
		if not is_host_state:
			# If lobby creation failed (empty lobby) but we have a local player,
			# treat as host since we're the room creator
			var has_players: bool = players.size() > 0
			var in_lobby: bool = not lm.current_lobby.is_empty()
			if has_players or in_lobby:
				is_host_state = true
	ready_button.set_mode(is_host_state, all_rdy, is_ready)

@warning_ignore("inferred_declaration", "shadowed_variable")
func _refresh_players() -> void:
	# re-parsed
	if lobby_manager == null:
		players = []
		return
	
	var lm := lobby_manager
	
	# Query local player name from LobbyManager (sync, avoids async PlayerStorage)
	var player_name := "玩家"
	if lm.has_method("get_display_name"):
		var disp: Variant = lm.get_display_name()
		if disp is String and not (disp as String).is_empty():
			player_name = disp as String
		else:
			var auth2 := get_node_or_null("/root/AuthManager")
			if auth2 != null and auth2.has_method("display_name") and str(auth2.display_name()) != "":
				player_name = str(auth2.display_name())
	
	# Get host's product_user_id to reorder players (host first = slot 1)
	var host_puid: String = ""
	if lm.has_method("_lobby") and lm._lobby != null:
		host_puid = str(lm._lobby.owner_product_user_id)
	
	var new_players: Array = []
	for member in lm.players:
		var pid: String = member.get("product_user_id", "")
		var is_self: bool = pid == lm.get_local_player_id()
		# Name from member attribute; fallback to stored profile or "玩家"
		var member_name: String = str(member.get("name", player_name))
		if member_name.is_empty():
			member_name = player_name
		
		# Use stored stats if available, otherwise defaults
		var stats: Dictionary = member.get_stats() if member.has_method("get_stats") else {"speed": 0.85, "handling": 0.72, "accel": 0.90}
		
		new_players.append({
			"id": pid,
			"name": member_name,
			"car_name": "Default Car",
			"score": int(stats.speed * 1000),
			"cls": "S",
			"rank": "大師 I",
			"best_lap": "1:23.456",
			"matches": [true, false, true, true, false],
			"stats": stats,
			"is_self": is_self,
			"is_host": pid == host_puid
		})
	
	# Offline mode fallback: add mock local player if lobby has no members
	if new_players.is_empty():
		var local_id := "local_player"
		if lm.has_method("get_local_player_id"):
			local_id = str(lm.get_local_player_id())
		new_players.append({
			"id": local_id,
			"name": player_name,
			"car_name": "Default Car",
			"score": 850,
			"cls": "S",
			"rank": "大師 I",
			"best_lap": "1:23.456",
			"matches": [true, false, true, true, false],
			"stats": {"speed": 0.85, "handling": 0.72, "accel": 0.90},
			"is_self": true,
			"is_host": true
		})
	
	# Reorder: host first (slot 1), then self if not host, then others
	new_players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_host: bool = a["id"] == host_puid
		var b_host: bool = b["id"] == host_puid
		if a_host and not b_host:
			return true
		if b_host and not a_host:
			return false
		var a_self: bool = a["is_self"]
		var b_self: bool = b["is_self"]
		if a_self and not b_self:
			return true
		if b_self and not a_self:
			return false
		return false
	)
	
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
	# Method 1: Check via lobby manager (preferred)
	if lobby_manager != null and lobby_manager.has_method("_nm"):
		var nm = lobby_manager._nm()
		if nm != null:
			return nm.is_logged_in
	# Method 2: Fallback - check NetworkManager directly
	var direct_nm = get_node_or_null("/root/NetworkManager")
	if direct_nm != null and "is_logged_in" in direct_nm:
		return direct_nm.is_logged_in
	return false

func _all_lobby_ready(lm) -> bool:
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
