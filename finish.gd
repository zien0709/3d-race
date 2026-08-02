extends Area3D

@onready var race_manager: Node = $"../RaceManager"

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		print("抵達終點！")
		race_manager.finish_race()
