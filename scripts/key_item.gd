extends Area2D

@export var key_color := Color.WHITE

@onready var visual: Polygon2D = $Visual

func _ready() -> void:
	add_to_group("keys")
	# Set polygon shape in code — avoids .tscn PackedVector2Array parsing issues
	visual.polygon = PackedVector2Array([
		Vector2(0, -14), Vector2(12, 0), Vector2(0, 14), Vector2(-12, 0)
	])
	visual.color = key_color
	print("KeyItem ready: color=", key_color, " pos=", global_position)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("collect_key"):
		if body.collect_key(key_color):
			queue_free()
