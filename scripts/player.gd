extends CharacterBody2D

const SPEED         := 220.0
const JUMP_VELOCITY := -480.0
const GRAVITY       := 980.0
const MAX_JUMPS     := 2

var jump_count   := 0
var player_color := Color.WHITE
var has_key      := false
var player_id    := 1
var is_local     := true          # false for remote network players
var target_position := Vector2.ZERO  # used by remote players for lerp

@onready var visual: Polygon2D = $Visual

func _ready() -> void:
	add_to_group("players")
	visual.polygon = PackedVector2Array([
		Vector2(-8, -22), Vector2(8, -22),
		Vector2(10, -8),  Vector2(8, 22),
		Vector2(-8, 22),  Vector2(-10, -8),
	])
	target_position = global_position
	if not is_local:
		$CollisionShape2D.disabled = true

func _physics_process(delta: float) -> void:
	if not is_local:
		# Smoothly follow network position
		global_position = global_position.lerp(target_position, 12.0 * delta)
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			jump_count = 0
		if jump_count < MAX_JUMPS:
			velocity.y  = JUMP_VELOCITY
			jump_count += 1

	if is_on_floor():
		jump_count = 0

	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * SPEED if direction != 0 else move_toward(velocity.x, 0, SPEED)

	if direction > 0:
		visual.scale.x = 1.0
	elif direction < 0:
		visual.scale.x = -1.0

	move_and_slide()

func set_player_color(color: Color) -> void:
	player_color = color
	visual.color  = color

func collect_key(key_color: Color) -> bool:
	if key_color.is_equal_approx(player_color):
		has_key = true
		if not NetworkManager.my_id.is_empty():
			NetworkManager.send_key_collected()
		return true
	return false

func can_board_ship() -> bool:
	return has_key
