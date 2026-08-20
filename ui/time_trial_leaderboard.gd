extends PanelContainer

signal score_registered(player_name: String, rank: int)

const SAVE_PATH: String = "user://race_scores.cfg"

@onready var leaderboard_grid: GridContainer = %LeaderboardGrid
@onready var leaderboard_title: Label = %LeaderboardTitle
@onready var local_tab: Button = %LocalTab
@onready var public_tab: Button = %PublicTab
@onready var public_leaderboard_grid: GridContainer = %PublicLeaderboardGrid

var leaderboard: Array = []
var _showing_public := false


func _ready() -> void:
	load_leaderboard()
	local_tab.pressed.connect(_on_local_tab_pressed)
	public_tab.pressed.connect(_on_public_tab_pressed)
	LeaderboardManager.leaderboard_updated.connect(_on_public_leaderboard_updated)

	# 初始化排行榜分頁狀態（本地為預設）
	local_tab.disabled = true
	public_tab.disabled = false
	leaderboard_grid.visible = true
	public_leaderboard_grid.visible = false

	refresh_leaderboard_ui()


func set_waiting(waiting: bool) -> void:
	visible = waiting


func register_score(score_name: String, score_time: float) -> int:
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
		return -1

	leaderboard.sort_custom(is_score_faster)

	save_leaderboard()
	refresh_leaderboard_ui()

	print("目前排行榜：", leaderboard)

	var rank: int = -1
	for index in range(leaderboard.size()):
		if str(leaderboard[index].get("name", "")) == score_name:
			rank = index + 1
			break
	score_registered.emit(score_name, rank)
	return rank


func submit_public(time_seconds: float) -> void:
	# 提交到 EOS 公開排行榜（毫秒）
	if LeaderboardManager and NetworkManager.is_logged_in:
		LeaderboardManager.submit_race_time(time_seconds)


func is_score_faster(score_a: Dictionary, score_b: Dictionary) -> bool:
	return float(score_a["time"]) < float(score_b["time"])
	

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


func refresh_leaderboard_ui() -> void:
	for child in leaderboard_grid.get_children():
		child.queue_free()

	add_leaderboard_cell("名次", 60.0)
	add_leaderboard_cell("姓名", 180.0)
	add_leaderboard_cell("時間", 70.0)

	if leaderboard.is_empty():
		add_leaderboard_cell("", 60.0)
		add_leaderboard_cell("尚無紀錄", 180.0)
		add_leaderboard_cell("", 70.0)
		return

	var display_count: int = mini(10, leaderboard.size())
		
	for index in range(display_count):
		var score: Dictionary = leaderboard[index]
		var score_name: String = str(score.get("name", "未知"))
		var score_time: float = float(score.get("time", 0.0))

		add_leaderboard_cell(str(index + 1), 60.0)
		add_leaderboard_cell(score_name, 180.0)
		add_leaderboard_cell("%.2f 秒" % score_time, 70.0)


func add_leaderboard_cell(cell_text: String, minimum_width: float) -> void:
	var cell_label := Label.new()

	cell_label.text = cell_text
	cell_label.custom_minimum_size.x = minimum_width
	cell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell_label.add_theme_font_size_override("font_size", 24)

	leaderboard_grid.add_child(cell_label)


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