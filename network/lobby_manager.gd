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
const ATTR_MAP := "map"
const ATTR_MODE := "mode"
const ATTR_DAMAGE := "damage_mode"
const ATTR_CAR_RESTRICTION := "car_restriction"
const ATTR_AUTO_START := "auto_start"

var current_lobby: Dictionary = {}
var is_host: bool = false
## players: [{ "peer_id": int, "product_user_id": String, "name": String, "ready": bool }]
var players: Array = []

## 大廳瀏覽器狀態（UI 搜尋用）
var browser_busy: bool = false
var browser_results: Array = []

var _lobby = null


# ==========================================================================
# UI 查詢輔助（大廳介面用）
# ==========================================================================

func get_display_name() -> String:
	var nm = _nm()
	return str(nm.display_name) if nm != null else ""

func get_local_player_id() -> String:
	var nm = _nm()
	return str(nm.product_user_id) if nm != null else ""

func is_online() -> bool:
	var nm = _nm()
	return nm != null and nm.is_logged_in

func puid_text() -> String:
	var nm = _nm()
	if nm == null or not nm.is_logged_in:
		return "PUID: 未登入"
	return "PUID: %s" % str(nm.product_user_id)

## 房間人數上限（在房中取 lobby 實際值，否則用常數）
var max_members: int:
	get:
		return int(_lobby.max_members) if _lobby else MAX_PLAYERS

## 讀取目前（或指定）lobby 的 attribute；回傳 default_value 若不存在。
func lobby_attr(key: String, default_value: Variant = "", lobby: Variant = null) -> Variant:
	var target = lobby if lobby != null else _lobby
	if target == null:
		return default_value
	var attr: Dictionary = target.get_attribute(key)
	if attr.is_empty():
		return default_value
	return attr.value

## 把搜尋結果整理成 UI 好用的資訊。
func result_info(lb) -> Dictionary:
	if lb == null:
		return {}
	var host_name: String = str(lobby_attr(ATTR_HOST_NAME, "", lb))
	if host_name.is_empty():
		host_name = str(lobby_attr(ATTR_DISPLAY_NAME, "", lb))
	var room_name: String = str(lobby_attr(ATTR_ROOM_NAME, "", lb))
	# EOS 搜尋結果不帶 attribute，改從本機 lobby 讀取
	if (host_name.is_empty() or room_name.is_empty()) and _lobby != null:
		var target_id: String = str(lb.lobby_id) if "lobby_id" in lb else ""
		var local_id: String = str(_lobby.lobby_id) if "lobby_id" in _lobby else ""
		if target_id != "" and target_id == local_id:
			if host_name.is_empty():
				host_name = str(lobby_attr(ATTR_HOST_NAME, "Host", _lobby))
			if room_name.is_empty():
				room_name = str(lobby_attr(ATTR_ROOM_NAME, "", _lobby))
	if host_name.is_empty():
		host_name = "Host"
	if room_name.is_empty():
		if host_name.is_empty():
			room_name = "未命名房間"
		else:
			room_name = "%s的房間" % host_name
	return {
		"lobby": lb,
		"room_name": room_name,
		"host_name": host_name,
		"max_members": int(lb.max_members),
		"available_slots": int(lb.available_slots),
	}


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
	var room_name: String = str(room_config.get("name", "%s的房間" % _nm().display_name))
	var host_name: String = str(room_config.get("host_name", _nm().display_name))

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
	lobby.add_attribute(ATTR_HOST_NAME, host_name)
	lobby.add_attribute(ATTR_ROOM_NAME, room_name)
	lobby.add_attribute(ATTR_DISPLAY_NAME, host_name)
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
	print("[LobbyManager] join_lobby: attempting join for lobby_id=", lobby.lobby_id)
	var joined: Variant = await hlobbies.join_async(lobby)
	if not joined:
		print("[LobbyManager] join_lobby: join failed (returned null/false)")
		lobby_joined.emit({})
		return
	print("[LobbyManager] join_lobby: join succeeded")

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


## host 更新房間設定（寫進 lobby attribute，client 端透過 lobby_updated 同步）。
## max_players 在 EOS 建房後不可改，其餘規則皆可即時更新。
func update_lobby_settings(room_config: Dictionary) -> void:
	if not is_host or not _lobby:
		return
	if room_config.has("name"):
		_lobby.add_attribute(ATTR_ROOM_NAME, str(room_config["name"]))
	if room_config.has("map"):
		_lobby.add_attribute(ATTR_MAP, str(room_config["map"]))
	if room_config.has("mode"):
		_lobby.add_attribute(ATTR_MODE, str(room_config["mode"]))
	if room_config.has("damage_mode"):
		_lobby.add_attribute(ATTR_DAMAGE, str(room_config["damage_mode"]))
	if room_config.has("car_restriction"):
		_lobby.add_attribute(ATTR_CAR_RESTRICTION, str(room_config["car_restriction"]))
	if room_config.has("auto_start"):
		_lobby.add_attribute(ATTR_AUTO_START, str(room_config["auto_start"]))
	await _lobby.update_async()


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
