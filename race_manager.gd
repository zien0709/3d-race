extends Node

const SAVE_PATH: String = "user://race_scores.cfg"

@onready var player: VehicleBody3D = $"../Player"
@onready var timer_label: Label = $"../UI/HUD/Margin/VBox/TimerLabel"
@onready var countdown_label: Label = $"../UI/CountdownCenter/CountdownLabel"
@onready var checkpoint_label: Label = $"../UI/HUD/Margin/VBox/CheckpointLabel"
@onready var checkpoint_bar: ProgressBar = $"../UI/HUD/Margin/VBox/CheckpointBar"
@onready var hud_panel: PanelContainer = $"../UI/HUD"
@onready var login_button: Button = $"../UI/StartCenter/MainCard/TabHeader/LoginButton"
@onready var register_button: Button = $"../UI/StartCenter/MainCard/TabHeader/RegisterButton"
@onready var play_button: Button = $"../UI/StartCenter/MainCard/TabHeader/PlayButton"
@onready var finish_center: CenterContainer = $"../UI/FinishCenter"
@onready var final_time_label: Label = $"../UI/FinishCenter/FinishPanel/VBoxContainer/FinalTimeLabel"
@onready var new_record_label: Label = $"../UI/FinishCenter/FinishPanel/VBoxContainer/NewRecordLabel"
@onready var best_time_label: Label = $"../UI/HUD/Margin/VBox/BestTimeLabel"
@onready var start_center: Control = $"../UI/StartCenter"
@onready var name_input: LineEdit = $"../UI/StartCenter/MainCard/ContentArea/Margin/ContentStack/PlayPage/PlayCenter/ContentVBox/NameInput"
@onready var start_button: Button = $"../UI/StartCenter/MainCard/ContentArea/Margin/ContentStack/PlayPage/PlayCenter/ContentVBox/Footer/StartButton"
@onready var leaderboard_panel: PanelContainer = %LeaderboardPanel
@onready var leaderboard_grid: GridContainer = %LeaderboardGrid
@onready var leaderboard_title: Label = %LeaderboardTitle
@onready var local_tab: Button = %LocalTab
@onready var public_tab: Button = %PublicTab
@onready var public_leaderboard_grid: GridContainer = %PublicLeaderboardGrid
@onready var next_player_button: Button = %NextPlayerButton
@onready var rank_panel: PanelContainer = $"../UI/RankPanel"
@export var total_checkpoints: int = 2

const RANKING_UPDATE_INTERVAL: float = 0.15

var ranking := RaceRanking.new()
var ranking_update_accum: float = 0.0

var leaderboard: Array = []
var _showing_public := false
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
var _bar_tween: Tween
var _chk_tween: Tween
var _final_time_tween: Tween
var _record_pulse_tween: Tween

func restart_race() -> void:
	if player:
		player.respawn_car()

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
	login_button.visible = waiting_for_player
	leaderboard_panel.visible = waiting_for_player
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
	
	next_player_button.pressed.connect(prepare_next_player)
	local_tab.pressed.connect(_on_local_tab_pressed)
	public_tab.pressed.connect(_on_public_tab_pressed)
	LeaderboardManager.leaderboard_updated.connect(_on_public_leaderboard_updated)
	
	countdown_label.text = ""
	start_button.pressed.connect(start_race)
	name_input.text_submitted.connect(_on_name_submitted)
	name_input.call_deferred("grab_focus")

	rank_panel.visible = false

	# 初始化排行榜分頁狀態（本地為預設）
	local_tab.disabled = true
	public_tab.disabled = false
	leaderboard_grid.visible = true
	public_leaderboard_grid.visible = false

	# Setup Micro-interactions for interactive UI buttons
	setup_button_animations(login_button)
	setup_button_animations(register_button)
	setup_button_animations(play_button)
	setup_button_animations(start_button)
	setup_button_animations(next_player_button)


func setup_button_animations(btn: Button) -> void:
	if not btn:
		return
	btn.pivot_offset = btn.size * 0.5
	if not btn.resized.is_connected(_on_btn_resized.bind(btn)):
		btn.resized.connect(_on_btn_resized.bind(btn))
	btn.mouse_entered.connect(_on_btn_mouse_entered.bind(btn))
	btn.mouse_exited.connect(_on_btn_mouse_exited.bind(btn))
	btn.button_down.connect(_on_btn_button_down.bind(btn))
	btn.button_up.connect(_on_btn_button_up.bind(btn))


func _on_btn_resized(btn: Button) -> void:
	btn.pivot_offset = btn.size * 0.5


func _on_btn_mouse_entered(btn: Button) -> void:
	if btn.disabled:
		return
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_btn_mouse_exited(btn: Button) -> void:
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_btn_button_down(btn: Button) -> void:
	if btn.disabled:
		return
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_btn_button_up(btn: Button) -> void:
	var target_scale := Vector2(1.05, 1.05) if btn.is_hovered() else Vector2.ONE
	var tw := create_tween()
	tw.tween_property(btn, "scale", target_scale, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

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

	# Smooth StartCenter Slide & Fade Out
	start_center.pivot_offset = start_center.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(start_center, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(start_center, "position:y", start_center.position.y - 40.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		start_center.visible = false
		start_center.modulate.a = 1.0
		start_center.position.y += 40.0
	)

	restart_race()

	# HUD Pop In
	hud_panel.pivot_offset = hud_panel.size * 0.5
	hud_panel.scale = Vector2(0.8, 0.8)
	hud_panel.modulate.a = 0.0
	var hud_tw := create_tween().set_parallel(true)
	hud_tw.tween_property(hud_panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hud_tw.tween_property(hud_panel, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	ranking.cars[1]["name"] = player_name
	ranking.emit_changed()
	rank_panel.visible = true
	rank_panel.pivot_offset = rank_panel.size * 0.5
	rank_panel.scale = Vector2(0.8, 0.8)
	rank_panel.modulate.a = 0.0
	var rank_tw := create_tween().set_parallel(true)
	rank_tw.tween_property(rank_panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rank_tw.tween_property(rank_panel, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

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

	# 提交到 EOS 公開排行榜（毫秒）
	if LeaderboardManager and NetworkManager.is_logged_in:
		LeaderboardManager.submit_race_time(race_time)
	
	timer_label.text = "%.2f" % race_time
	finish_center.visible = true
	finish_center.modulate.a = 0.0
	finish_center.scale = Vector2(0.7, 0.7)
	finish_center.pivot_offset = finish_center.size * 0.5
	
	var pop_tw := create_tween().set_parallel(true)
	pop_tw.tween_property(finish_center, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pop_tw.tween_property(finish_center, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Count-up timer animation
	if _final_time_tween and _final_time_tween.is_valid():
		_final_time_tween.kill()
	_final_time_tween = create_tween()
	_final_time_tween.tween_method(func(val: float): final_time_label.text = "成績：%.2f 秒" % val, 0.0, race_time, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if best_time < 0.0 or race_time < best_time:
		best_time = race_time

		save_best_time()
		refresh_best_time_label()

		new_record_label.visible = true
		new_record_label.pivot_offset = new_record_label.get_minimum_size() * 0.5
		if _record_pulse_tween and _record_pulse_tween.is_valid():
			_record_pulse_tween.kill()
		_record_pulse_tween = create_tween().set_loops()
		_record_pulse_tween.tween_property(new_record_label, "scale", Vector2(1.15, 1.15), 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_record_pulse_tween.tween_property(new_record_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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

	if _bar_tween and _bar_tween.is_valid():
		_bar_tween.kill()
	_bar_tween = create_tween()
	_bar_tween.tween_property(checkpoint_bar, "value", float(checkpoint_index), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	checkpoint_label.pivot_offset = checkpoint_label.get_minimum_size() * 0.5
	if _chk_tween and _chk_tween.is_valid():
		_chk_tween.kill()
	_chk_tween = create_tween()
	_chk_tween.tween_property(checkpoint_label, "scale", Vector2.ONE, 0.3).from(Vector2(1.3, 1.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	

func _on_local_tab_pressed() -> void:
	_showing_public = false
	leaderboard_title.text = "排行榜"
	leaderboard_grid.visible = true
	public_leaderboard_grid.visible = false
	local_tab.disabled = true
	public_tab.disabled = false
	refresh_leaderboard_ui()


func _on_public_tab_pressed() -> void:
	_showing_public = true
	leaderboard_title.text = "公開排行榜"
	leaderboard_grid.visible = false
	public_leaderboard_grid.visible = true
	local_tab.disabled = false
	public_tab.disabled = true
	LeaderboardManager.refresh_leaderboard()


func _on_public_leaderboard_updated(records: Array) -> void:
	if not _showing_public:
		return
	_refresh_public_leaderboard_ui(records)


func _refresh_public_leaderboard_ui(records: Array) -> void:
	for child in public_leaderboard_grid.get_children():
		child.queue_free()

	_add_leaderboard_header(public_leaderboard_grid)

	if records.is_empty():
		_add_leaderboard_row(public_leaderboard_grid, "", "尚無紀錄", "")
		return

	var count: int = mini(10, records.size())
	for i in range(count):
		var rec: Dictionary = records[i]
		var display_name: String = str(rec.get("display_name", "未知"))
		var score_int: int = int(rec.get("stat_value", 0))
		var time_str: String = "%.2f 秒" % (score_int / 1000.0)
		_add_leaderboard_row(public_leaderboard_grid, str(i + 1), display_name, time_str)


func _add_leaderboard_header(grid: GridContainer) -> void:
	_make_label(grid, "名次", 60.0)
	_make_label(grid, "姓名", 180.0)
	_make_label(grid, "時間", 70.0)


func _add_leaderboard_row(grid: GridContainer, rank: String, pname: String, time: String) -> void:
	_make_label(grid, rank, 60.0)
	_make_label(grid, pname, 180.0)
	_make_label(grid, time, 70.0)


func _make_label(grid: GridContainer, txt: String, min_w: float) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.custom_minimum_size.x = min_w
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	grid.add_child(lbl)
	
func refresh_leaderboard_ui() -> void:
	for child in leaderboard_grid.get_children():
		child.queue_free()

	add_leaderboard_cell(
		"名次",
		60.0
	)

	add_leaderboard_cell(
		"姓名",
		180.0
	)

	add_leaderboard_cell(
		"時間",
		70.0
	)

	if leaderboard.is_empty():
		add_leaderboard_cell(
			"",
			60.0
		)

		add_leaderboard_cell(
			"尚無紀錄",
			180.0
		)

		add_leaderboard_cell(
			"",
			70.0
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
			60.0
		)

		add_leaderboard_cell(
			score_name,
			180.0
		)

		add_leaderboard_cell(
			"%.2f 秒" % score_time,
			70.0
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
	leaderboard_panel.visible = true
	start_center.visible = true

	if ranking.cars.has(1):
		ranking.cars[1]["next_index"] = 0
		ranking.cars[1]["progress"] = 0.0
		rank_panel.clear_entries()
	rank_panel.visible = false

	name_input.call_deferred("grab_focus")
