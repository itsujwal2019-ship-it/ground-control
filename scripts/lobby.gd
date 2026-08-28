extends Control

@onready var code_label:    Label          = $VBox/CodeLabel
@onready var player_list:   VBoxContainer  = $VBox/PlayerList
@onready var start_button:  Button         = $VBox/StartButton
@onready var wait_label:    Label          = $VBox/WaitLabel

func _ready() -> void:
	code_label.text = "Room Code:  %s" % NetworkManager.room_code
	start_button.visible = NetworkManager.is_host
	wait_label.visible   = not NetworkManager.is_host

	start_button.pressed.connect(_on_start_pressed)

	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.game_started.connect(_on_game_started)

	# Show self
	_add_row(NetworkManager.my_id, NetworkManager.my_color, true)
	# Show players already in room (joiner case)
	for pid in NetworkManager.players:
		_add_row(pid, NetworkManager.players[pid]["color"], false)

func _add_row(pid: String, color: Color, is_self: bool) -> void:
	var hbox := HBoxContainer.new()
	hbox.name = "Row_" + pid

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(24, 24)
	swatch.color = color

	var lbl := Label.new()
	lbl.text = ("You" if is_self else "Player") + "  [%s]" % pid

	hbox.add_child(swatch)
	hbox.add_child(lbl)
	player_list.add_child(hbox)

func _on_player_joined(pid: String, color: Color) -> void:
	_add_row(pid, color, false)

func _on_player_left(pid: String) -> void:
	var row := player_list.get_node_or_null("Row_" + pid)
	if row:
		row.queue_free()

func _on_start_pressed() -> void:
	NetworkManager.start_game()

func _on_game_started(_seed_value: int) -> void:
	get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")
