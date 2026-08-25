extends Area3D

@onready var race_manager: Node = $"../RaceManager"

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	# 多人大廳：只處理加入 "player_car" 群組、且由本端擁有的車
	if not body.is_in_group("player_car"):
		return
	if body.get_multiplayer_authority() != multiplayer.get_unique_id():
		return

	print("抵達終點！")
	race_manager.finish_race()
