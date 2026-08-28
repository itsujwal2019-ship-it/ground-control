extends Node2D

const KEY_SCENE := preload("res://scenes/key_item.tscn")

const PLAYER_COLORS := [
	Color(1.0, 0.2, 0.2),   # Red
	Color(0.2, 0.5, 1.0),   # Blue
	Color(0.2, 0.85, 0.2),  # Green
	Color(1.0, 0.85, 0.1),  # Yellow
	Color(0.7, 0.2, 1.0),   # Purple
]

@export var active_players: int = 1

func _ready() -> void:
	call_deferred("spawn_keys")

func spawn_keys() -> void:
	if KEY_SCENE == null:
		push_error("KeySpawner: key_item.tscn failed to load!")
		return

	var points: Array[Vector2] = []
	for child in get_children():
		if child is Marker2D:
			points.append(child.global_position)
	points.shuffle()

	for i in active_players:
		if points.is_empty():
			push_warning("KeySpawner: not enough spawn points.")
			break
		var key: Node = KEY_SCENE.instantiate()
		key.set("key_color", PLAYER_COLORS[i])
		get_parent().add_child(key)
		key.global_position = points.pop_front()
		print("KeySpawner: spawned key at ", key.global_position, " color=", PLAYER_COLORS[i])
