extends VBoxContainer
class_name OtherDetailPanel

## OtherDetailPanel - 其他玩家詳細資料面板
## 顯示車輛名稱、分數、等級、排名、最佳單圈、近期比賽、車輛屬性（唯讀）

const C_TEXT := Color(0.85, 0.88, 0.92)
const C_MUTED := Color(0.5, 0.55, 0.6)
const C_CYAN := Color(0.22, 0.74, 0.97)
const C_GREEN := Color(0.3, 0.9, 0.4)
const C_BORDER := Color(0.3, 0.35, 0.4, 0.3)

@onready var car_name_value: Label = $InfoContainer/CarNameRow/CarNameValue
@onready var score_value: Label = $InfoContainer/ScoreRow/ScoreValue
@onready var class_value: Label = $InfoContainer/ClassRow/ClassValue
@onready var rank_value: Label = $InfoContainer/RankRow/RankValue
@onready var best_lap_value: Label = $InfoContainer/BestLapRow/BestLapValue
@onready var matches_container: HBoxContainer = $InfoContainer/MatchesContainer
@onready var speed_bar: ProgressBar = $InfoContainer/StatsContainer/SpeedRow/SpeedBar
@onready var speed_value: Label = $InfoContainer/StatsContainer/SpeedRow/SpeedValue
@onready var handling_bar: ProgressBar = $InfoContainer/StatsContainer/HandlingRow/HandlingBar
@onready var handling_value: Label = $InfoContainer/StatsContainer/HandlingRow/HandlingValue
@onready var accel_bar: ProgressBar = $InfoContainer/StatsContainer/AccelRow/AccelBar
@onready var accel_value: Label = $InfoContainer/StatsContainer/AccelRow/AccelValue

const StatBarScript := preload("res://ui/lobby/components/inspector/stat_bar.gd")
const MatchDotsScript := preload("res://ui/lobby/components/inspector/match_dots.gd")

var _match_dots: Control = null

func _ready() -> void:
	_setup_match_dots()

func _setup_match_dots() -> void:
	if matches_container:
		_match_dots = HBoxContainer.new()
		_match_dots.set_script(MatchDotsScript)
		matches_container.add_child(_match_dots)

func update_data(data: Dictionary) -> void:
	# data = {
	#   "car_name": "Default Car",
	#   "score": 850,
	#   "cls": "S",
	#   "rank": "大師 I",
	#   "best_lap": "1:23.456",
	#   "matches": [true, false, true, true, false],
	#   "stats": {"speed": 0.85, "handling": 0.72, "accel": 0.90}
	# }
	
	if car_name_value:
		car_name_value.text = str(data.get("car_name", "Default Car"))
	
	if score_value:
		score_value.text = str(data.get("score", 0))
	
	if class_value:
		class_value.text = str(data.get("cls", "A"))
	
	if rank_value:
		rank_value.text = str(data.get("rank", "--"))
	
	if best_lap_value:
		best_lap_value.text = str(data.get("best_lap", "--:--.---"))
	
	# Update matches dots
	if _match_dots:
		var matches: Array = data.get("matches", [])
		_match_dots.update_dots(matches)
	
	# Update stat bars
	var stats: Dictionary = data.get("stats", {})
	if speed_bar:
		speed_bar.value = float(stats.get("speed", 0.5)) * 100.0
	if speed_value:
		speed_value.text = "%d" % int(float(stats.get("speed", 0.5)) * 100)
	
	if handling_bar:
		handling_bar.value = float(stats.get("handling", 0.5)) * 100.0
	if handling_value:
		handling_value.text = "%d" % int(float(stats.get("handling", 0.5)) * 100)
	
	if accel_bar:
		accel_bar.value = float(stats.get("accel", 0.5)) * 100.0
	if accel_value:
		accel_value.text = "%d" % int(float(stats.get("accel", 0.5)) * 100)

func clear_data() -> void:
	if car_name_value:
		car_name_value.text = "Default Car"
	if score_value:
		score_value.text = "-"
	if class_value:
		class_value.text = "-"
	if rank_value:
		rank_value.text = "--"
	if best_lap_value:
		best_lap_value.text = "--:--.---"
	if _match_dots:
		_match_dots.update_dots([])
	if speed_bar:
		speed_bar.value = 0
	if speed_value:
		speed_value.text = "0"
	if handling_bar:
		handling_bar.value = 0
	if handling_value:
		handling_value.text = "0"
	if accel_bar:
		accel_bar.value = 0
	if accel_value:
		accel_value.text = "0"