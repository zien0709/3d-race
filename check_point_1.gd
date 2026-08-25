extends Area3D

@export var checkpoint_index: int = 1

@onready var race_manager: Node = $"../../RaceManager"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	# 只處理加入 "player_car" 群組的車輛
	if not body.is_in_group("player_car"):
		return

	# 僅車輛的擁有者（authority）回報，避免重複觸發
	if body.get_multiplayer_authority() != multiplayer.get_unique_id():
		return

	if multiplayer.has_multiplayer_peer():
		# 本地推進 + HUD 更新（用於衝線驗證）
		race_manager.register_checkpoint(checkpoint_index)
		# 回報 host 做權威名次計算
		race_manager.report_checkpoint.rpc_id(1, multiplayer.get_unique_id(), checkpoint_index)
	else:
		race_manager.register_checkpoint(checkpoint_index)
