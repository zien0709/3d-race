extends Node

## 公開排行榜管理（EOS Stats + Leaderboards）。
## 使用 stats: "race_time_ms"（毫秒整數，min aggregation）。
## 需要在 Epic Dev Portal 建立對應 Stat 與 Leaderboard Definition：
##   Stat Name: race_time_ms
##   Leaderboard ID: race_time_battle
##   Aggregation: Min

signal leaderboard_updated(records: Array)
signal score_submitted(ok: bool)
signal my_rank_fetched(rank: int, score: int)

const STAT_NAME := "race_time_ms"
const LEADERBOARD_ID := "race_time_battle"

var _records: Array = []
var _my_rank: int = -1
var _my_best_ms: int = 0


func _ready() -> void:
	NetworkManager.login_succeeded.connect(_on_login)


# ==========================================================================
# 提交成績
# ==========================================================================

## 將比賽時間提交到 EOS Stats（毫秒取整，min aggregation）。
func submit_race_time(time_seconds: float) -> void:
	if not NetworkManager.is_logged_in:
		score_submitted.emit(false)
		return
	var ms := int(time_seconds * 1000.0)
	if ms <= 0:
		score_submitted.emit(false)
		return
	var ok := await _ingest_async(STAT_NAME, ms)
	if ok:
		if _my_best_ms <= 0 or ms < _my_best_ms:
			_my_best_ms = ms
		await refresh_my_rank()
	score_submitted.emit(ok)


# ==========================================================================
# 查詢排行榜
# ==========================================================================

## 從 EOS Leaderboards 拉取排行榜資料。
func refresh_leaderboard() -> void:
	if not NetworkManager.is_logged_in:
		leaderboard_updated.emit([])
		return
	var eos := _eos()
	if eos == null:
		leaderboard_updated.emit([])
		return

	var hleader := _hleaderboards()
	if hleader == null:
		leaderboard_updated.emit([])
		return

	var records: Array = await hleader.get_leaderboard_records_async(LEADERBOARD_ID)
	_records = records
	leaderboard_updated.emit(records)


## 查詢自己的排名（透過 QueryLeaderboardUserScores）。
func refresh_my_rank() -> void:
	if not NetworkManager.is_logged_in:
		my_rank_fetched.emit(-1, 0)
		return
	var eos := _eos()
	if eos == null:
		my_rank_fetched.emit(-1, 0)
		return
	var my_uid := NetworkManager.product_user_id
	if my_uid.is_empty():
		my_rank_fetched.emit(-1, 0)
		return
	var query_opts = eos.Leaderboards.QueryLeaderboardUserScoresOptions.new()
	query_opts.user_ids = [my_uid]
	query_opts.stat_info = [{
		"stat_name": STAT_NAME,
		"aggregation": eos.Leaderboards.LeaderboardAggregation.Min,
	}]
	eos.Leaderboards.LeaderboardsInterface.query_leaderboard_user_scores(query_opts)
	var ret: Dictionary = await IEOS.leaderboards_interface_query_leaderboard_user_scores_callback
	if not eos.is_success(ret):
		my_rank_fetched.emit(-1, 0)
		return

	var count_opts = eos.Leaderboards.GetLeaderboardUserScoreCountOptions.new()
	var count: int = eos.Leaderboards.LeaderboardsInterface.get_leaderboard_user_score_count(count_opts)
	if count == 0:
		my_rank_fetched.emit(-1, 0)
		return

	var copy_opts = eos.Leaderboards.CopyLeaderboardUserScoreByIndexOptions.new()
	copy_opts.leaderboard_user_score_index = 0
	copy_opts.stat_name = STAT_NAME
	var copy_ret: Dictionary = eos.Leaderboards.LeaderboardsInterface.copy_leaderboard_user_score_by_index(copy_opts)
	if not eos.is_success(copy_ret):
		my_rank_fetched.emit(-1, 0)
		return
	_my_rank = int(copy_ret.get("rank", -1))
	_my_best_ms = int(copy_ret.get("score", 0))
	my_rank_fetched.emit(_my_rank, _my_best_ms)


func get_my_best_ms() -> int:
	return _my_best_ms


func get_my_rank() -> int:
	return _my_rank


func get_records() -> Array:
	return _records


# ==========================================================================
# 內部
# ==========================================================================

func _ingest_async(stat_name: String, amount: int) -> bool:
	var eos := _eos()
	if eos == null:
		return false
	var hstats := _hstats()
	if hstats == null:
		return false
	var result: EOS.Result = await hstats.ingest_stat_async(stat_name, amount)
	return result == eos.Result.Success


func _hstats() -> Node:
	return get_node_or_null("/root/HStats")


func _hleaderboards() -> Node:
	return get_node_or_null("/root/HLeaderboards")


func _eos() -> GDScript:
	return load("res://addons/epic-online-services-godot/eos.gd")


func _on_login() -> void:
	_my_rank = -1
	_my_best_ms = 0
	refresh_leaderboard()
