extends Node2D

const KEY_SCENE := preload("res://scenes/key_item.tscn")

# Must match relay.js COLORS order exactly
const PLAYER_COLORS: Array[Color] = [
	Color(1.0, 0.2,  0.2,  1),  # Red
	Color(0.2, 0.5,  1.0,  1),  # Blue
	Color(0.2, 0.85, 0.2,  1),  # Green
	Color(1.0, 0.85, 0.1,  1),  # Yellow
	Color(0.7, 0.2,  1.0,  1),  # Purple
]

@export var active_players: int = 1
@export var network_seed:   int = 0

func _ready() -> void:
	call_deferred("spawn_keys")

func spawn_keys() -> void:
	if KEY_SCENE == null:
		push_error("KeySpawner: failed to load key_item.tscn")
		return

	var points: Array[Vector2] = []
	for child in get_children():
		if child is Marker2D:
			points.append(child.global_position)

	if network_seed != 0:
		seed(network_seed)
	points.shuffle()

	for i in active_players:
		if points.is_empty():
			push_warning("KeySpawner: not enough spawn points.")
			break
		var key: Node = KEY_SCENE.instantiate()
		key.set("key_color", PLAYER_COLORS[i])
		get_parent().add_child(key)
		key.global_position = points.pop_front()
		print("KeySpawner: spawned key[%d] at %v color=%s" % [i, key.global_position, PLAYER_COLORS[i]])
