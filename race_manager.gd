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

	update_start_countdown(delta)

	if not race_started or race_finished:
		return

	race_time += delta
	time_trial_hud.set_time(race_time)

	ranking_update_accum += delta
	if ranking_update_accum >= RANKING_UPDATE_INTERVAL:
		ranking_update_accum = 0.0
		ranking.update_car(1, player.global_position)
		ranking.emit_changed()

func _ready() -> void:
	load_best_time()
	refresh_best_time_label()

	start_screen.start_requested.connect(_on_start_requested)
	start_screen.show_for_waiting()

	finish_screen.next_player_requested.connect(prepare_next_player)
	finish_screen.home_requested.connect(_on_home_requested)

	countdown.clear()

	rank_panel.hide_panel()
	finish_screen.hide_results()

func setup_ranking(
	checkpoint_positions: Array,
	finish_position: Vector3,
	start_position: Vector3
) -> void:
	ranking.setup(checkpoint_positions, finish_position, start_position)
	ranking.register_car(1, "玩家")
	ranking.changed.connect(rank_panel.update_entries)

func _on_start_requested(entered_name: String) -> void:
	if entered_name.is_empty():
		start_screen.show_name_error("名字不能空白")
		return
	start_race(entered_name)


func start_race(player_name: String) -> void:
	self.player_name = player_name
	waiting_for_player = false

	start_screen.hide_for_race()

	restart_race()

	# HUD Pop In
	time_trial_hud.play_intro()

	ranking.cars[1]["name"] = player_name
	ranking.emit_changed()
	rank_panel.play_intro()

func finish_race() -> void:
	if race_finished:
		return

	if next_checkpoint <= total_checkpoints:
		print("還沒有通過所有檢查點！")
		return

	race_finished = true

	ranking.mark_finished(1)
	ranking.emit_changed()

	leaderboard_ui.register_score(player_name, race_time)

	# 提交到 EOS 公開排行榜（毫秒）
	leaderboard_ui.submit_public(race_time)

	time_trial_hud.set_time(race_time)

	var is_new_record := best_time < 0.0 or race_time < best_time

	if is_new_record:
		best_time = race_time

		save_best_time()
		refresh_best_time_label()

	finish_screen.show_results(race_time, is_new_record)

func register_checkpoint(checkpoint_index: int) -> void:
	if race_finished:
		return

	if checkpoint_index != next_checkpoint:
		print("檢查點順序錯誤")
		return

	next_checkpoint += 1
	time_trial_hud.set_checkpoint(checkpoint_index, total_checkpoints)

	ranking.advance_car(1)
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

		return

	if go_display_time > 0.0:
		go_display_time -= delta

		if go_display_time <= 0.0:
			countdown.set_text("", Color.WHITE)

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

	countdown_time = 3.0
	go_display_time = 0.0

	time_trial_hud.reset(total_checkpoints)
	countdown.clear()

	finish_screen.hide_results()
	leaderboard_ui.set_waiting(true)
	start_screen.show_for_waiting()

	if ranking.cars.has(1):
		ranking.cars[1]["next_index"] = 0
		ranking.cars[1]["progress"] = 0.0
		rank_panel.clear_entries()
	rank_panel.hide_panel()

func _on_home_requested() -> void:
	get_tree().change_scene_to_file("res://ui/lobby.tscn")
