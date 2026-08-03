extends Node

const SAVE_PATH: String = "user://race_scores.cfg"

@onready var player: VehicleBody3D = $"../Player"
@onready var timer_label: Label = $"../UI/HUD/Margin/VBox/TimerLabel"
@onready var countdown_label: Label = $"../UI/CountdownCenter/CountdownLabel"
@onready var checkpoint_label: Label = $"../UI/HUD/Margin/VBox/CheckpointLabel"
@onready var checkpoint_bar: ProgressBar = $"../UI/HUD/Margin/VBox/CheckpointBar"
@onready var hud_panel: PanelContainer = $"../UI/HUD"
@onready var eos_login_button: Button = $"../UI/EOSLoginButton"
@onready var finish_center: CenterContainer = $"../UI/FinishCenter"
@onready var final_time_label: Label = $"../UI/FinishCenter/FinishPanel/VBoxContainer/FinalTimeLabel"
@onready var new_record_label: Label = $"../UI/FinishCenter/FinishPanel/VBoxContainer/NewRecordLabel"
@onready var best_time_label: Label = $"../UI/HUD/Margin/VBox/BestTimeLabel"
@onready var start_center: CenterContainer = $"../UI/StartCenter"
@onready var name_input: LineEdit = $"../UI/StartCenter/MainVBox/FormCenter/FormVBox/NameInput"
@onready var start_button: Button = $"../UI/StartCenter/MainVBox/FormCenter/FormVBox/StartButton"
@onready var leaderboard_button: Button = %LeaderboardButton
@onready var leaderboard_center: CenterContainer = %LeaderboardCenter
@onready var leaderboard_grid: GridContainer = %LeaderboardGrid
@onready var close_leaderboard_button: Button = %CloseLeaderboardButton
@onready var next_player_button: Button = %NextPlayerButton
@onready var rank_panel: PanelContainer = $"../UI/RankPanel"
@export var total_checkpoints: int = 2

const RANKING_UPDATE_INTERVAL: float = 0.15

var ranking := RaceRanking.new()
var ranking_update_accum: float = 0.0

var leaderboard: Array = []
var player_name: String = ""
var waiting_for_player: bool = true
var best_time: float = -1.0
var race_started: bool = false
var countdown_time: float = 3.0
var go_display_time: float = 0.0

var next_checkpoint: int = 1
var race_time: float = 0.0
var race_finished: bool = false

var _last_countdown_text: String = ""
var _countdown_tween: Tween

func restart_race() -> void:
	race_time = 0.0
	race_finished = false
	race_started = false

	next_checkpoint = 1

	countdown_time = 3.0
	go_display_time = 0.0

	timer_label.text = "0.00"
	checkpoint_label.text = "檢查點：0 / %d" % total_checkpoints
	checkpoint_bar.value = 0
	countdown_label.text = "3"
	countdown_label.scale = Vector2.ONE
	countdown_label.modulate = Color.WHITE
	_last_countdown_text = ""
	
	finish_center.visible = false
	new_record_label.visible = false

func _process(delta: float) -> void:
	hud_panel.visible = not waiting_for_player
	eos_login_button.visible = waiting_for_player
	if waiting_for_player:
		return
	
	update_start_countdown(delta)

	if not race_started or race_finished:
		return

	race_time += delta
	timer_label.text = "%.2f" % race_time

	ranking_update_accum += delta
	if ranking_update_accum >= RANKING_UPDATE_INTERVAL:
		ranking_update_accum = 0.0
		ranking.update_car(1, player.global_position)
		ranking.emit_changed()

func _ready() -> void:
	load_leaderboard()
	load_best_time()
	refresh_best_time_label()
	
	start_center.visible = true
	
	leaderboard_button.pressed.connect(open_leaderboard)
	close_leaderboard_button.pressed.connect(close_leaderboard)
	next_player_button.pressed.connect(prepare_next_player)
	
	countdown_label.text = ""
	start_button.pressed.connect(start_race)
	name_input.text_submitted.connect(_on_name_submitted)
	name_input.call_deferred("grab_focus")

	rank_panel.visible = false

func setup_ranking(
	checkpoint_positions: Array,
	finish_position: Vector3,
	start_position: Vector3
) -> void:
	ranking.setup(checkpoint_positions, finish_position, start_position)
	ranking.register_car(1, "玩家")
	ranking.changed.connect(rank_panel.update_entries)

func _on_name_submitted(_text: String) -> void:
	start_race()


func start_race() -> void:
	var entered_name := name_input.text.strip_edges()
	if entered_name.is_empty():
		name_input.placeholder_text = "名字不能空白"
		return

	player_name = entered_name
	waiting_for_player = false

	start_center.visible = false
	restart_race()

	ranking.cars[1]["name"] = player_name
	ranking.emit_changed()
	rank_panel.visible = true

func finish_race() -> void:
	if race_finished:
		return

	if next_checkpoint <= total_checkpoints:
		print("還沒有通過所有檢查點！")
		return

	race_finished = true

	ranking.mark_finished(1)
	ranking.emit_changed()

	register_score(player_name, race_time)
	
	timer_label.text = "%.2f" % race_time
	finish_center.visible = true

	final_time_label.text = "%.2f 秒" % race_time

	if best_time < 0.0 or race_time < best_time:
		best_time = race_time

		save_best_time()
		refresh_best_time_label()

		new_record_label.visible = true
	else:
		new_record_label.visible = false
		
func register_checkpoint(checkpoint_index: int) -> void:
	if race_finished:
		return

	if checkpoint_index != next_checkpoint:
		print("檢查點順序錯誤")
		return

	next_checkpoint += 1
	checkpoint_label.text = "檢查點：%d / %d" % [
		checkpoint_index,
		total_checkpoints
	]
	checkpoint_bar.value = checkpoint_index

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
			_set_countdown_text(str(ceili(countdown_time)), Color.WHITE)
		else:
			race_started = true
			_set_countdown_text("GO!", Color(0.15, 1.0, 0.4))
			go_display_time = 1.0

		return

	if go_display_time > 0.0:
		go_display_time -= delta

		if go_display_time <= 0.0:
			_set_countdown_text("", Color.WHITE)


func _set_countdown_text(text: String, color: Color) -> void:
	countdown_label.text = text
	countdown_label.modulate = color
	if text.is_empty():
		return
	if text == _last_countdown_text:
		return
	_last_countdown_text = text
	if _countdown_tween and _countdown_tween.is_valid():
		_countdown_tween.kill()
	countdown_label.pivot_offset = countdown_label.get_minimum_size() * 0.5
	_countdown_tween = create_tween()
	_countdown_tween.tween_property(
		countdown_label, "scale", Vector2.ONE, 0.35
	).from(Vector2(0.45, 0.45)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	if best_time < 0.0:
		best_time_label.text = "最佳：--"
		return

	best_time_label.text = "最佳：%.2f 秒" % best_time

func load_leaderboard() -> void:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)

	if error != OK:
		return

	var saved_leaderboard = config.get_value(
		"scores",
		"leaderboard",
		[]
	)

	if saved_leaderboard is Array:
		leaderboard = saved_leaderboard
		
func save_leaderboard() -> void:
	var config := ConfigFile.new()

	# 先讀取原本的檔案，避免清掉 best_time
	config.load(SAVE_PATH)

	config.set_value(
		"scores",
		"leaderboard",
		leaderboard
	)

	var error := config.save(SAVE_PATH)

	if error != OK:
		push_error("無法儲存排行榜")
		
func register_score(score_name: String, score_time: float) -> void:
	var existing_index: int = -1

	for index in range(leaderboard.size()):
		var score: Dictionary = leaderboard[index]

		if str(score.get("name", "")) == score_name:
			existing_index = index
			break
	
	if existing_index == -1:
		# 第一次使用這個名字
		leaderboard.append({
			"name": score_name,
			"time": score_time
		})

	elif score_time < float(leaderboard[existing_index]["time"]):
		# 同名，但這次成績更快
		leaderboard[existing_index]["time"] = score_time

	else:
		# 同名，而且沒有刷新紀錄
		return

	leaderboard.sort_custom(is_score_faster)

	#if leaderboard.size() > 10:
		#leaderboard.resize(10)

	save_leaderboard()
	refresh_leaderboard_ui()

	print("目前排行榜：", leaderboard)
	
func is_score_faster(score_a: Dictionary, score_b: Dictionary) -> bool:
	return float(score_a["time"]) < float(score_b["time"])
	
func open_leaderboard() -> void:
	refresh_leaderboard_ui()

	start_center.visible = false
	leaderboard_center.visible = true


func close_leaderboard() -> void:
	leaderboard_center.visible = false
	start_center.visible = true

	name_input.call_deferred("grab_focus")
	
func refresh_leaderboard_ui() -> void:
	for child in leaderboard_grid.get_children():
		child.queue_free()

	add_leaderboard_cell(
		"名次",
		100.0
	)

	add_leaderboard_cell(
		"姓名",
		300.0
	)

	add_leaderboard_cell(
		"時間",
		100.0
	)

	if leaderboard.is_empty():
		add_leaderboard_cell(
			"",
			100.0
		)

		add_leaderboard_cell(
			"尚無紀錄",
			300.0
		)

		add_leaderboard_cell(
			"",
			100.0
		)

		return

	var display_count: int = mini(10, leaderboard.size())
		
	for index in range(display_count):
		var score: Dictionary = leaderboard[index]
#
		var score_name: String = str(
			score.get("name", "未知")
		)

		var score_time: float = float(
			score.get("time", 0.0)
		)
		
		

		add_leaderboard_cell(
			str(index + 1),
			100.0
		)

		add_leaderboard_cell(
			score_name,
			300.0
		)

		add_leaderboard_cell(
			"%.2f 秒" % score_time,
			100.0
		)

func add_leaderboard_cell(
	cell_text: String,
	minimum_width: float
) -> void:
	var cell_label := Label.new()

	cell_label.text = cell_text
	cell_label.custom_minimum_size.x = minimum_width
	cell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell_label.add_theme_font_size_override("font_size", 24)

	cell_label.add_theme_font_size_override(
		"font_size",
		24
	)

	leaderboard_grid.add_child(cell_label)

func prepare_next_player() -> void:
	player.respawn_car()

	player_name = ""
	name_input.text = ""

	waiting_for_player = true
	race_started = false
	race_finished = false

	race_time = 0.0
	next_checkpoint = 1

	countdown_time = 3.0
	go_display_time = 0.0

	timer_label.text = "0.00"
	checkpoint_label.text = "檢查點：0 / %d" % total_checkpoints
	checkpoint_bar.value = 0
	countdown_label.text = ""
	countdown_label.scale = Vector2.ONE
	countdown_label.modulate = Color.WHITE
	_last_countdown_text = ""

	finish_center.visible = false
	new_record_label.visible = false
	leaderboard_center.visible = false
	start_center.visible = true

	if ranking.cars.has(1):
		ranking.cars[1]["next_index"] = 0
		ranking.cars[1]["progress"] = 0.0
		rank_panel.clear_entries()
	rank_panel.visible = false

	name_input.call_deferred("grab_focus")
