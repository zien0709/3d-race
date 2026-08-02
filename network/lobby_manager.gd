extends Node

## 房間 / 大廳管理（佔位）
## EOS Lobbies 部分先註解：開房(12人)、搜尋、加入、就緒、開始。
## 目前只留資料結構與訊號，遊戲層可以先吃這些介面。

@warning_ignore("unused_signal")
signal lobby_created(lobby_info: Dictionary)
@warning_ignore("unused_signal")
signal lobby_joined(lobby_info: Dictionary)
@warning_ignore("unused_signal")
signal member_joined(member_id: String)
@warning_ignore("unused_signal")
signal member_left(member_id: String)
signal ready_state_changed(ready_map: Dictionary)
signal match_started(peer_order: Array)

const MAX_PLAYERS := 12

var current_lobby: Dictionary = {}
var is_host: bool = false
## players: [{ "peer_id": int, "name": String, "ready": bool }]
var players: Array = []


func create_lobby() -> void:
	# EOS：HLobbies.create_lobby_async({ max_lobby_members = MAX_PLAYERS, ... })
	# 先註解。目前直接在本機登記 host。
	is_host = true
	players = []
	players.append({"peer_id": 1, "name": "P1", "ready": false})


func join_lobby(_lobby_info: Dictionary) -> void:
	# EOS：HLobbies.join_async(lobby)
	pass


func add_player(peer_id: int, display_name: String) -> void:
	players.append({"peer_id": peer_id, "name": display_name, "ready": false})
	ready_state_changed.emit(get_ready_map())


func set_ready(is_ready: bool) -> void:
	# 在多人時由 UI 呼叫；目前先寫入本機玩家狀態
	for player in players:
		if player["peer_id"] == NetworkManager.LOCAL_PEER_ID:
			player["ready"] = is_ready
			break
	ready_state_changed.emit(get_ready_map())


func get_ready_map() -> Dictionary:
	var map := {}
	for player in players:
		map[player["peer_id"]] = player["ready"]
	return map


func start_match() -> void:
	# 所有人就緒後由 host 觸發；目前直接廣播本機單人順序
	match_started.emit([1])
