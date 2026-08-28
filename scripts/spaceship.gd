extends Area2D

signal player_won(player_id: int)

func _ready() -> void:
	add_to_group("spaceship")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("can_board_ship") and body.can_board_ship():
		player_won.emit(body.player_id)
