extends PanelContainer

@onready var timer_label: Label = $Margin/VBox/TimerLabel
@onready var checkpoint_label: Label = $Margin/VBox/CheckpointLabel
@onready var checkpoint_bar: ProgressBar = $Margin/VBox/CheckpointBar
@onready var best_time_label: Label = $Margin/VBox/BestTimeLabel

var _bar_tween: Tween
var _chk_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_waiting(waiting: bool) -> void:
	visible = not waiting


func reset(total_checkpoints: int) -> void:
	timer_label.text = "0.00"
	checkpoint_label.text = "檢查點：0 / %d" % total_checkpoints
	checkpoint_bar.max_value = total_checkpoints
	checkpoint_bar.value = 0


func set_time(seconds: float) -> void:
	timer_label.text = "%.2f" % seconds


func set_checkpoint(current: int, total: int) -> void:
	checkpoint_label.text = "檢查點：%d / %d" % [current, total]

	if _bar_tween and _bar_tween.is_valid():
		_bar_tween.kill()
	_bar_tween = create_tween()
	_bar_tween.tween_property(checkpoint_bar, "value", float(current), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	checkpoint_label.pivot_offset = checkpoint_label.get_minimum_size() * 0.5
	if _chk_tween and _chk_tween.is_valid():
		_chk_tween.kill()
	_chk_tween = create_tween()
	_chk_tween.tween_property(checkpoint_label, "scale", Vector2.ONE, 0.3).from(Vector2(1.3, 1.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_best_time(best_time: float) -> void:
	if best_time < 0.0:
		best_time_label.text = "最佳：--"
		return
	best_time_label.text = "最佳：%.2f 秒" % best_time


func play_intro() -> void:
	pivot_offset = size * 0.5
	scale = Vector2(0.8, 0.8)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
