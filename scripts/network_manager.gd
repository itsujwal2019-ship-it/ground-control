extends Node

# --- Signals ---
signal connected_to_server
signal connection_failed
signal room_created(code: String)
signal room_joined(code: String)
signal player_joined(pid: String, color: Color)
signal player_left(pid: String)
signal game_started(seed_value: int)
signal position_received(pid: String, pos: Vector2)
signal key_collected_by(pid: String)
signal player_won(pid: String)
signal server_error(message: String)

# Change this to your deployed relay URL after hosting
const SERVER_URL := "ws://localhost:8080"

var my_id    := ""
var my_color := Color.WHITE
var room_code := ""
var is_host  := false
var game_seed := 0
# pid -> { color: Color }
var players: Dictionary = {}

var _socket := WebSocketPeer.new()
var _ready_state_prev := WebSocketPeer.STATE_CLOSED

func _process(_delta: float) -> void:
	_socket.poll()
	var state := _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		while _socket.get_available_packet_count() > 0:
			_handle_packet(_socket.get_packet())

	if state != _ready_state_prev:
		if state == WebSocketPeer.STATE_CLOSED and _ready_state_prev == WebSocketPeer.STATE_CONNECTING:
			connection_failed.emit()
		_ready_state_prev = state

func connect_to_server() -> void:
	_socket = WebSocketPeer.new()
	_ready_state_prev = WebSocketPeer.STATE_CONNECTING
	_socket.connect_to_url(SERVER_URL)

func _send(data: Dictionary) -> void:
	if _socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_socket.send_text(JSON.stringify(data))

func _handle_packet(raw: PackedByteArray) -> void:
	var data = JSON.parse_string(raw.get_string_from_utf8())
	if not data is Dictionary:
		return
	match data.get("type", ""):
		"connected":
			my_id = str(data["id"])
			connected_to_server.emit()
		"room_created":
			room_code  = str(data["code"])
			my_color   = _to_color(data["color"])
			is_host    = true
			room_created.emit(room_code)
		"room_joined":
			room_code  = str(data["code"])
			my_color   = _to_color(data["color"])
			is_host    = false
			for p in data["players"]:
				players[str(p["id"])] = { "color": _to_color(p["color"]) }
			room_joined.emit(room_code)
		"player_joined":
			var pid := str(data["id"])
			var c   := _to_color(data["color"])
			players[pid] = { "color": c }
			player_joined.emit(pid, c)
		"player_left":
			var pid := str(data["id"])
			players.erase(pid)
			player_left.emit(pid)
		"game_start":
			game_seed = int(data["seed"])
			game_started.emit(game_seed)
		"move":
			position_received.emit(str(data["id"]), Vector2(float(data["x"]), float(data["y"])))
		"key_collected":
			key_collected_by.emit(str(data["id"]))
		"win":
			player_won.emit(str(data["id"]))
		"error":
			server_error.emit(str(data["message"]))

# --- Public API ---
func create_room() -> void:
	_send({ "type": "create_room" })

func join_room(code: String) -> void:
	_send({ "type": "join_room", "code": code.strip_edges().to_upper() })

func start_game() -> void:
	_send({ "type": "start_game", "seed": randi() % 99999 })

func send_position(pos: Vector2) -> void:
	_send({ "type": "move", "x": snappedf(pos.x, 0.5), "y": snappedf(pos.y, 0.5) })

func send_key_collected() -> void:
	_send({ "type": "key_collected" })

func send_win() -> void:
	_send({ "type": "win" })

func reset() -> void:
	players.clear()
	my_id     = ""
	my_color  = Color.WHITE
	room_code = ""
	is_host   = false
	game_seed = 0

func _to_color(arr) -> Color:
	return Color(float(arr[0]), float(arr[1]), float(arr[2]), 1.0)
