extends Control

# World area the minimap represents
const WORLD_RECT := Rect2(0, 0, 1280, 720)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.08, 0.18, 1.0))

	# Platforms (match level_01.tscn layout)
	var platforms := [
		Rect2(0, 644, 1280, 32),       # Ground
		Rect2(170, 588, 220, 24),      # Platform1
		Rect2(490, 448, 220, 24),      # Platform2
		Rect2(810, 308, 220, 24),      # Platform3
	]
	for p in platforms:
		draw_rect(_world_rect_to_map(p), Color(0.3, 0.35, 0.6, 1.0))

	# Spaceship
	for node in get_tree().get_nodes_in_group("spaceship"):
		var pos := _world_to_map(node.global_position)
		draw_circle(pos, 5.0, Color(0.8, 0.9, 1.0))

	# Keys
	for node in get_tree().get_nodes_in_group("keys"):
		var pos := _world_to_map(node.global_position)
		draw_circle(pos, 4.0, node.key_color)

	# Players
	for node in get_tree().get_nodes_in_group("players"):
		var pos := _world_to_map(node.global_position)
		draw_circle(pos, 5.0, node.player_color)
		# Direction triangle
		var dir := Vector2(node.get_node("Visual").scale.x, 0)
		draw_line(pos, pos + dir * 7.0, node.player_color, 2.0)

func _world_to_map(world_pos: Vector2) -> Vector2:
	return Vector2(
		(world_pos.x - WORLD_RECT.position.x) / WORLD_RECT.size.x * size.x,
		(world_pos.y - WORLD_RECT.position.y) / WORLD_RECT.size.y * size.y
	)

func _world_rect_to_map(world_rect: Rect2) -> Rect2:
	var top_left := _world_to_map(world_rect.position)
	var bot_right := _world_to_map(world_rect.end)
	return Rect2(top_left, bot_right - top_left)
