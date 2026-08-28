extends MultiplayerSpawner

## 遠端玩家車輛 spawner（佔位）
## EOS 連線啟用後，host 收到新 peer 連線時會透過 spawn_function 生出遠端車。
## 現在單機模式不會觸發（沒有 peer）。

const PLAYER_SCENE := preload("res://player.tscn")


func _ready() -> void:
	spawn_function = _spawn_remote_player


func _spawn_remote_player(data: Variant) -> Node:
	var peer_id: int = int(data.get("peer_id", 1))
	var player := PLAYER_SCENE.instantiate()
	player.name = "Player_%d" % peer_id
	player.set("is_local_player", false)
	# 從 MatchConfig 解析該 peer 的車型
	var car_id := ""
	if LobbyManager != null and LobbyManager.match_config.has("players"):
		for p in LobbyManager.match_config["players"]:
			if int(p.get("peer_id", -1)) == peer_id:
				car_id = str(p.get("car_id", ""))
				break
	if not car_id.is_empty():
		player.set("car_id", car_id)
	var slot: Dictionary = StartGrid.get_slot(maxi(peer_id - 1, 0))
	player.position = slot["position"]
	player.rotation = Vector3(0.0, float(slot["yaw"]), 0.0)
	player.set_multiplayer_authority(peer_id)
	return player
