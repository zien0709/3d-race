extends Node

const SAVE_PATH: String = "user://race_scores.cfg"

signal race_active_changed(active: bool)

@onready var player: VehicleBody3D = $"../Player"
@onready var time_trial_hud = $"../UI/HUD"
@onready var countdown = $"../UI/CountdownCenter"
@onready var start_screen = $"../UI/StartCenter"
@onready var finish_screen = $"../UI/FinishCenter"
@onready var leaderboard_ui = $"../UI/LeaderboardPanel"
@onready var rank_panel: PanelContainer = $"../UI/RankPanel"
@export var total_checkpoints: int = 2

const RANKING_UPDATE_INTERVAL: float = 0.15

var ranking := RaceRanking.new()
var ranking_update_accum: float = 0.0

var player_name: String = ""
var waiting_for_player: bool = true
var best_time: float = -1.0
var race_started: bool = false
var countdown_time: float = 3.0
var go_display_time: float = 0.0

var next_checkpoint: int = 1
var race_time: float = 0.0
var race_finished: bool = false

var _race_active := false
var _is_host: bool = false
var _connected_peers: Array[int] = []
var _finished_peers: Array[int] = []

func restart_race() -> void:
	if player:
		player.respawn_car()

	race_time = 0.0
	race_finished = false
	race_started = false

	next_checkpoint = 1

	countdown_time = 3.0
	go_display_time = 0.0

	time_trial_hud.reset(total_checkpoints)
	countdown.reset()

	finish_screen.hide_results()

func _process(delta: float) -> void:
	var race_active := not waiting_for_player
	if race_active != _race_active:
		_race_active = race_active
		race_active_changed.emit(race_active)
	time_trial_hud.set_waiting(waiting_for_player)
	leaderboard_ui.set_waiting(waiting_for_player)
	if waiting_for_player:
		return

	# 只有 host 執行倒數與比賽計時
	if _is_host:
		update_start_countdown(delta)

	if not race_started or race_finished:
		return

	if _is_host:
		race_time += delta
		time_trial_hud.set_time(race_time)

	ranking_update_accum += delta
	if ranking_update_accum >= RANKING_UPDATE_INTERVAL:
		ranking_update_accum = 0.0
		if not multiplayer.has_multiplayer_peer():
			# 單機：更新本地玩家
			if player:
				ranking.update_car(1, player.global_position)
				ranking.emit_changed()
		elif _is_host:
			# host：更新自己 + 廣播給所有 client
			if player:
				ranking.update_car(multiplayer.get_unique_id(), player.global_position)
			ranking.emit_changed()
			rpc("apply_ranking_sync", ranking.get_ordered())
		else:
			# client：把自己的位置回報給 host
			if player:
				report_progress.rpc_id(1, multiplayer.get_unique_id(), player.global_position)

func _ready() -> void:
	# host 定義：伺服器端，或單機（無網路 peer）時本機即為權威
	_is_host = multiplayer.is_server() or (not multiplayer.has_multiplayer_peer())

	load_best_time()
	refresh_best_time_label()

	start_screen.start_requested.connect(_on_start_requested)
	start_screen.show_for_waiting()

	finish_screen.next_player_requested.connect(prepare_next_player)
	finish_screen.home_requested.connect(_on_home_requested)

	countdown.clear()

	rank_panel.hide_panel()
	finish_screen.hide_results()

	# 監聽網路連線事件
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# 如果是主機，註冊本地玩家
	if _is_host:
		_on_peer_connected(multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1)

func setup_ranking(
	checkpoint_positions: Array,
	finish_position: Vector3,
	start_position: Vector3
) -> void:
	ranking.setup(checkpoint_positions, finish_position, start_position)
	# 註冊本地玩家
	var local_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	ranking.register_car(local_id, "玩家")
	ranking.changed.connect(rank_panel.update_entries)

func _on_start_requested(entered_name: String) -> void:
	if entered_name.is_empty():
		start_screen.show_name_error("名字不能空白")
		return
	start_race(entered_name)


func start_race(player_name: String) -> void:
	self.player_name = player_name
	waiting_for_player = false
	_finished_peers.clear()

	start_screen.hide_for_race()

	restart_race()

	# HUD Pop In
	time_trial_hud.play_intro()

	var local_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	ranking.cars[local_id]["name"] = player_name
	ranking.emit_changed()
	rank_panel.play_intro()

	# 如果是多人模式且是 host，廣播開始比賽
	if _is_host and multiplayer.has_multiplayer_peer():
		rpc("start_race_sync", player_name)

# 多人同步 RPC：host 廣播比賽開始
@rpc("any_peer", "call_remote", "reliable")
func start_race_sync(player_name: String) -> void:
	if not _is_host:  # client 端接收
		self.player_name = player_name
		waiting_for_player = false
		start_screen.hide_for_race()
		restart_race()
		time_trial_hud.play_intro()

		var local_id := multiplayer.get_unique_id()
		ranking.cars[local_id]["name"] = player_name
		ranking.emit_changed()
		rank_panel.play_intro()

		# 回報顯示名稱給 host
		report_player_name.rpc_id(1, local_id, player_name)


func finish_race() -> void:
	if race_finished:
		return

	if next_checkpoint <= total_checkpoints:
		print("還沒有通過所有檢查點！")
		return

	race_finished = true

	var local_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	ranking.mark_finished(local_id)
	ranking.emit_changed()

	# 本地提交 EOS 排行榜（單機/多人各自提交自己的成績）
	leaderboard_ui.register_score(player_name, race_time)
	leaderboard_ui.submit_public(race_time)

	time_trial_hud.set_time(race_time)

	var is_new_record := best_time < 0.0 or race_time < best_time

	if is_new_record:
		best_time = race_time

		save_best_time()
		refresh_best_time_label()

	if not multiplayer.has_multiplayer_peer():
		# 單機：直接顯示
		finish_screen.show_results(race_time, is_new_record)
		return

	# 多人模式：回報衝線時間給 host，由 host 統一廣播最終名次
	if _is_host:
		_on_finish_reported(local_id, race_time)
	else:
		report_finish.rpc_id(1, local_id, race_time)


# 客戶端回報衝線時間給 host
@rpc("any_peer", "call_remote", "reliable")
func report_finish(peer_id: int, finish_time: float) -> void:
	_on_finish_reported(peer_id, finish_time)


func _on_finish_reported(peer_id: int, finish_time: float) -> void:
	if not _is_host:
		return

	if peer_id not in _finished_peers:
		_finished_peers.append(peer_id)

	ranking.mark_finished(peer_id)
	ranking.emit_changed()

	# 確認所有連線玩家（含 host 自己）都已衝線才結算
	var all_finished := true
	for pid in _connected_peers:
		if pid not in _finished_peers:
			all_finished = false
			break

	if all_finished:
		broadcast_final_results()


func broadcast_final_results() -> void:
	# 由 host 計算最終排名並廣播（含本機）
	var ordered := ranking.get_ordered()
	show_final_results_sync(ordered)
	if multiplayer.has_multiplayer_peer():
		rpc("show_final_results_sync", ordered)


@rpc("any_peer", "call_remote", "reliable")
func show_final_results_sync(ordered: Array) -> void:
	# 所有端顯示最終排名
	finish_screen.show_results_multiplayer(ordered)


# 客戶端週期性回報自己的世界座標給 host（host 據此計算名次）
@rpc("any_peer", "call_remote", "reliable")
func report_progress(peer_id: int, world_position: Vector3) -> void:
	if not _is_host:
		return
	if ranking.cars.has(peer_id):
		ranking.update_car(peer_id, world_position)
		ranking.emit_changed()


# host 廣播最新名次給所有 client
@rpc("any_peer", "call_remote", "reliable")
func apply_ranking_sync(ordered: Array) -> void:
	rank_panel.update_entries(ordered)


# 客戶端回報自己的顯示名稱給 host
@rpc("any_peer", "call_remote", "reliable")
func report_player_name(peer_id: int, display_name: String) -> void:
	if not _is_host:
		return
	if ranking.cars.has(peer_id):
		ranking.cars[peer_id]["name"] = display_name
		ranking.emit_changed()


# 檢查點回報 RPC（從 check_point_1.gd 呼叫）
@rpc("any_peer", "call_remote", "reliable")
func report_checkpoint(peer_id: int, checkpoint_index: int) -> void:
	if not _is_host:
		return

	# 驗證檢查點順序
	var car = ranking.cars.get(peer_id)
	if car and car.next_index + 1 == checkpoint_index:
		ranking.advance_car(peer_id)
		ranking.emit_changed()
		print("玩家 ", peer_id, " 通過檢查點 ", checkpoint_index)


# 原有單機版 register_checkpoint 保留給單機模式
func register_checkpoint(checkpoint_index: int) -> void:
	if race_finished:
		return

	if checkpoint_index != next_checkpoint:
		print("檢查點順序錯誤")
		return

	next_checkpoint += 1
	time_trial_hud.set_checkpoint(checkpoint_index, total_checkpoints)

	var local_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	ranking.advance_car(local_id)
	ranking.emit_changed()

	print(
		"通過檢查點：",
		checkpoint_index,
		"/",
		total_checkpoints
	)

func update_start_countdown(delta: float) -> void:
	if not race_started:
		countdown_time -= delta

		if countdown_time > 0.0:
			countdown.set_text(str(ceili(countdown_time)), Color.WHITE)
		else:
			race_started = true
			countdown.set_text("GO!", Color(0.15, 1.0, 0.4))
			go_display_time = 1.0

			# host 廣播比賽正式開始
			if _is_host and multiplayer.has_multiplayer_peer():
				rpc("race_started_sync")

		return

	if go_display_time > 0.0:
		go_display_time -= delta

		if go_display_time <= 0.0:
			countdown.set_text("", Color.WHITE)


@rpc("any_peer", "call_remote", "reliable")
func race_started_sync() -> void:
	race_started = true

func load_best_time() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)

	if error != OK:
		return

	best_time = float(
		config.get_value("scores", "best_time", -1.0)
	)

func save_best_time() -> void:
	var config := ConfigFile.new()

	# 避免儲存最佳成績時清掉排行榜
	config.load(SAVE_PATH)

	config.set_value(
		"scores",
		"best_time",
		best_time
	)

	var error := config.save(SAVE_PATH)

	if error != OK:
		push_error("無法儲存最佳成績")

func refresh_best_time_label() -> void:
	time_trial_hud.set_best_time(best_time)

func prepare_next_player() -> void:
	player.respawn_car()

	player_name = ""
	start_screen.clear_name()

	waiting_for_player = true
	race_started = false
	race_finished = false

	race_time = 0.0
	next_checkpoint = 1
	_finished_peers.clear()

	countdown_time = 3.0
	go_display_time = 0.0

	time_trial_hud.reset(total_checkpoints)
	countdown.clear()

	finish_screen.hide_results()
	leaderboard_ui.set_waiting(true)
	start_screen.show_for_waiting()

	# 重置所有車輛的排名進度
	for car_id in ranking.cars:
		ranking.cars[car_id]["next_index"] = 0
		ranking.cars[car_id]["progress"] = 0.0
	rank_panel.clear_entries()
	rank_panel.hide_panel()

	# 多人模式：廣播重置
	if _is_host and multiplayer.has_multiplayer_peer():
		rpc("prepare_next_player_sync")


@rpc("any_peer", "call_remote", "reliable")
func prepare_next_player_sync() -> void:
	prepare_next_player()

func _on_home_requested() -> void:
	get_tree().change_scene_to_file("res://ui/lobby.tscn")


func _on_peer_connected(peer_id: int) -> void:
	if not _is_host:
		return
	_connected_peers.append(peer_id)
	# 註冊新玩家到排名
	ranking.register_car(peer_id, "玩家 %d" % peer_id)
	ranking.emit_changed()


func _on_peer_disconnected(peer_id: int) -> void:
	if not _is_host:
		return
	_connected_peers.erase(peer_id)
	# 移除斷線玩家的排名
	if ranking.cars.has(peer_id):
		ranking.cars.erase(peer_id)
		ranking.emit_changed()
