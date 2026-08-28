extends Node2D

const PLAYER_SCENE  := preload("res://scenes/player.tscn")
const SOLO_COLOR    := Color(1.0, 0.2, 0.2)

@onready var spaceship   = $Spaceship
@onready var key_spawner = $KeySpawner
@onready var hud         = $HUD
@onready var _solo_player = $Player

var local_player: Node = null
var remote_players: Dictionary = {}  # pid -> Node
var _net_tick := 0

func _ready() -> void:
	if NetworkManager.my_id.is_empty():
		_setup_solo()
	else:
		_setup_multiplayer()

# ---------- Solo ----------
func _setup_solo() -> void:
	local_player = _solo_player
	local_player.set_player_color(SOLO_COLOR)
	local_player.player_id = 1
	spaceship.player_won.connect(_on_player_won)

# ---------- Multiplayer ----------
func _setup_multiplayer() -> void:
	# Reuse the scene's Player node as local avatar
	local_player = _solo_player
	local_player.is_local = true
	local_player.set_player_color(NetworkManager.my_color)

	# Deterministic key spawning shared across all clients
	var total := 1 + NetworkManager.players.size()
	key_spawner.active_players = total
	key_spawner.network_seed   = NetworkManager.game_seed

	# Spawn avatars for players already in room
	for pid in NetworkManager.players:
		_spawn_remote(pid, NetworkManager.players[pid]["color"])

	# Network events
	NetworkManager.player_joined.connect(_on_net_joined)
	NetworkManager.player_left.connect(_on_net_left)
	NetworkManager.position_received.connect(_on_net_position)
	NetworkManager.key_collected_by.connect(_on_net_key_collected)
	NetworkManager.player_won.connect(_on_net_player_won)
	spaceship.player_won.connect(_on_player_won)

func _spawn_remote(pid: String, color: Color) -> void:
	var p: Node = PLAYER_SCENE.instantiate()
	p.name      = "Remote_" + pid
	p.is_local  = false
	p.set_player_color(color)
	p.position  = Vector2(300 + remote_players.size() * 60, 560)
	add_child(p)
	remote_players[pid] = p

# ---------- Per-frame ----------
func _physics_process(_delta: float) -> void:
	if local_player:
		hud.update_key_status(local_player.has_key, local_player.player_color)

	if not NetworkManager.my_id.is_empty() and local_player:
		_net_tick = (_net_tick + 1) % 3  # ~20 Hz
		if _net_tick == 0:
			NetworkManager.send_position(local_player.global_position)

# ---------- Network handlers ----------
func _on_net_joined(pid: String, color: Color) -> void:
	if not remote_players.has(pid):
		_spawn_remote(pid, color)

func _on_net_left(pid: String) -> void:
	if remote_players.has(pid):
		remote_players[pid].queue_free()
		remote_players.erase(pid)

func _on_net_position(pid: String, pos: Vector2) -> void:
	if remote_players.has(pid):
		remote_players[pid].target_position = pos

func _on_net_key_collected(pid: String) -> void:
	# Find and remove the key whose color matches that player
	var color := Color.BLACK
	if NetworkManager.players.has(pid):
		color = NetworkManager.players[pid]["color"]
	for key in get_tree().get_nodes_in_group("keys"):
		if key.key_color.is_equal_approx(color):
			key.queue_free()
			break

func _on_net_player_won(_pid: String) -> void:
	_show_win("Another player reached the ship first!")

# ---------- Win ----------
func _on_player_won(_player_id: int) -> void:
	if not NetworkManager.my_id.is_empty():
		NetworkManager.send_win()
	_show_win("YOU WIN!")

func _show_win(msg: String) -> void:
	var label := Label.new()
	label.text = msg
	label.add_theme_font_size_override("font_size", 64)
	label.set_anchors_preset(Control.PRESET_CENTER)
	add_child(label)
	await get_tree().create_timer(3.0).timeout
	if NetworkManager.my_id.is_empty():
		get_tree().reload_current_scene()
	else:
		NetworkManager.reset()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
