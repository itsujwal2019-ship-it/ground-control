extends Control

@onready var host_button:   Button   = $VBox/HostButton
@onready var code_input:    LineEdit = $VBox/JoinRow/CodeInput
@onready var join_button:   Button   = $VBox/JoinRow/JoinButton
@onready var status_label:  Label    = $VBox/StatusLabel

var _intent := ""  # "host" or "join"

func _ready() -> void:
	NetworkManager.reset()
	NetworkManager.connected_to_server.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.room_created.connect(_on_room_ready)
	NetworkManager.room_joined.connect(_on_room_ready)
	NetworkManager.server_error.connect(_on_error)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	status_label.text = ""

func _on_host_pressed() -> void:
	_intent = "host"
	_set_busy("Connecting to server...")
	NetworkManager.connect_to_server()

func _on_join_pressed() -> void:
	var code := code_input.text.strip_edges().to_upper()
	if code.length() != 4:
		status_label.text = "Enter a 4-letter room code."
		return
	_intent = "join"
	_set_busy("Connecting to server...")
	NetworkManager.connect_to_server()

func _on_connected() -> void:
	status_label.text = "Connected! Setting up room..."
	if _intent == "host":
		NetworkManager.create_room()
	else:
		NetworkManager.join_room(code_input.text)

func _on_room_ready(_code: String) -> void:
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_connection_failed() -> void:
	_on_error("Could not reach the server. Is it running?")

func _on_error(msg: String) -> void:
	status_label.text = "Error: " + msg
	_set_busy("", false)

func _set_busy(msg: String, busy: bool = true) -> void:
	status_label.text = msg
	host_button.disabled = busy
	join_button.disabled = busy
	code_input.editable  = not busy
