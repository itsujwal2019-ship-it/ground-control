extends Area2D

signal player_won(player_id: int)

func _ready() -> void:
	add_to_group("spaceship")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("can_board_ship") and body.can_board_ship():
		player_won.emit(body.player_id)
		_show_win(body.player_id, body.player_color)

func _show_win(id: int, color: Color) -> void:
	var label := Label.new()
	label.text = "Player %d WINS!" % id
	label.modulate = color
	label.add_theme_font_size_override("font_size", 64)
	label.set_anchors_preset(Control.PRESET_CENTER)
	get_tree().current_scene.add_child(label)
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()
