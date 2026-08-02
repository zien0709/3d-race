extends Area3D

@export var checkpoint_index: int = 1

@onready var race_manager: Node = $"../../RaceManager"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.name != "Player":
		return

	race_manager.register_checkpoint(checkpoint_index)
