extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var hud = $HUD
@onready var spaceship = $Spaceship

const PLAYER_COLOR := Color(1.0, 0.2, 0.2)  # Red for solo Phase 1

func _ready() -> void:
	player.set_player_color(PLAYER_COLOR)
	player.player_id = 1
	spaceship.player_won.connect(_on_player_won)

func _process(_delta: float) -> void:
	hud.update_key_status(player.has_key, player.player_color)

func _on_player_won(_id: int) -> void:
	pass  # spaceship.gd handles display + reload
