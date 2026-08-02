extends Node

## 網路管理（佔位）
## EOS 連線部分目前先註解掉，保留結構，之後再啟用：
## 1. 安裝 EOSG 插件後，在 init_eos() 填入憑證並初始化 SDK
## 2. host_game() / join_game() 建立 EOSGMultiplayerPeer 並指定給 multiplayer
## 3. 透過 peer_connected / peer_disconnected 通知遊戲層

enum Mode {
	SINGLEPLAYER,  ## 單機計時賽（現在用的模式）
	HOST,          ## 開房（listen server，peer id = 1）
	CLIENT,        ## 加入別人的房
}

signal mode_changed(mode: int)
@warning_ignore("unused_signal")
signal peer_connected(peer_id: int)
@warning_ignore("unused_signal")
signal peer_disconnected(peer_id: int)

const LOCAL_PEER_ID := 1
const MAX_PLAYERS := 12  ## 連線數上限（配合 12 格出發位置）

var mode: int = Mode.SINGLEPLAYER


func set_mode(new_mode: int) -> void:
	mode = new_mode
	mode_changed.emit(mode)


func is_online() -> bool:
	return mode != Mode.SINGLEPLAYER


func is_host() -> bool:
	return mode == Mode.HOST


# ==========================================================================
# EOS（未啟用 — 先註解）
# 所需外掛：Epic Online Services Godot (EOSG) -> EOSGMultiplayerPeer
# ==========================================================================
#
# func init_eos() -> void:
# 	# 1) 用 ProductId / SandboxId / DeploymentId / ClientId / ClientSecret /
# 	#    EncryptionKey 初始化 HPlatform
# 	# 2) HAuth.login_async(...) 登入（DevAuth 或 Epic 帳號）
# 	pass
#
# func host_game() -> void:
# 	# var peer := EOSGMultiplayerPeer.new()
# 	# var err := peer.create_server("game", 0)
# 	# peer.set_server_auto_accept_connection_requests(true)
# 	# multiplayer.multiplayer_peer = peer
# 	# multiplayer.peer_connected.connect(_on_peer_connected)
# 	# multiplayer.peer_disconnected.connect(_on_peer_disconnected)
# 	# set_mode(Mode.HOST)
# 	pass
#
# func join_game() -> void:
# 	# var peer := EOSGMultiplayerPeer.new()
# 	# peer.create_client("game", 0)
# 	# multiplayer.multiplayer_peer = peer
# 	# multiplayer.connected_to_server.connect(_on_connected_to_server)
# 	# multiplayer.connection_failed.connect(_on_connection_failed)
# 	# set_mode(Mode.CLIENT)
# 	pass
#
# func _on_peer_connected(peer_id: int) -> void:
# 	peer_connected.emit(peer_id)
#
# func _on_peer_disconnected(peer_id: int) -> void:
# 	peer_disconnected.emit(peer_id)
#
# func _on_connected_to_server() -> void:
# 	pass
#
# func _on_connection_failed() -> void:
# 	pass
