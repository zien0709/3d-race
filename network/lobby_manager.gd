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

var current_lobby: Dictionary = {}
var is_host: bool = false
## players: [{ "peer_id": int, "product_user_id": String, "name": String, "ready": bool }]
var players: Array = []

var _lobby = null


# ==========================================================================
# 開房 / 搜尋 / 加入 / 離開
# ==========================================================================

## 開房：建立 12 人 EOS lobby，並在 host 端開 listen server。
func create_lobby() -> void:
	if not _nm().is_logged_in:
		lobby_created.emit({})
		return

	var hlobbies = _hlobbies()
	var eos = _eos_class()
	if hlobbies == null or eos == null:
		lobby_created.emit({})
		return

	var opts = eos.Lobby.CreateLobbyOptions.new()
	opts.max_lobby_members = MAX_PLAYERS
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

	lobby.add_attribute("game", "3d_race")
	lobby.add_attribute("host_name", _nm().display_name)
	await lobby.update_async()

	_sync_members()
	lobby_created.emit(_lobby_info())

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
	var joined: Variant = await hlobbies.join_async(lobby)
	if not joined:
		lobby_joined.emit({})
		return

	is_host = false
	_bind_lobby(joined)
	_sync_members()
	lobby_joined.emit(_lobby_info())

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
func _sync_members() -> void:
	if not _lobby:
		return
	var new_players: Array = []
	for member in _lobby.members:
		var ready := false
		var ready_attr: Dictionary = member.get_attribute(ATTR_READY)
		if not ready_attr.is_empty():
			ready = bool(ready_attr.value)
		new_players.append({
			"peer_id": _resolve_peer_id(member.product_user_id),
			"product_user_id": member.product_user_id,
			"name": member.display_name,
			"ready": ready,
		})
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
		"max_players": MAX_PLAYERS,
	}
