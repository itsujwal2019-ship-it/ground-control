extends CanvasLayer

@onready var key_label:        Label   = $KeyLabel
@onready var minimap_button:   Button  = $MinimapButton
@onready var minimap_panel:    Panel   = $MinimapPanel
@onready var pause_button:     Button  = $PauseButton
@onready var pause_overlay:    Control = $PauseOverlay
@onready var pause_label:      Label   = $PauseOverlay/CenterBox/PauseLabel
@onready var countdown_label:  Label   = $PauseOverlay/CenterBox/CountdownLabel
@onready var resume_button:    Button  = $PauseOverlay/CenterBox/ResumeButton

var minimap_open    := false
var _pause_left     := 0.0

func _ready() -> void:
	process_mode                  = Node.PROCESS_MODE_ALWAYS
	pause_overlay.process_mode    = Node.PROCESS_MODE_ALWAYS
	pause_button.process_mode     = Node.PROCESS_MODE_ALWAYS
	resume_button.process_mode    = Node.PROCESS_MODE_ALWAYS

	minimap_button.pressed.connect(_toggle_minimap)
	minimap_panel.visible  = false
	pause_overlay.visible  = false
	update_key_status(false, Color.WHITE)

	pause_button.pressed.connect(_on_pause_pressed)
	resume_button.pressed.connect(_on_resume_pressed)

	NetworkManager.game_paused.connect(_on_game_paused)
	NetworkManager.game_resumed.connect(_on_game_resumed)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _pause_left > 0.0:
			_on_resume_pressed()
		else:
			_on_pause_pressed()

func _process(delta: float) -> void:
	if _pause_left > 0.0:
		_pause_left -= delta
		countdown_label.text = "Auto-resuming in: %d" % ceili(_pause_left)
		if _pause_left <= 0.0:
			_do_resume()

func update_key_status(has_key: bool, color: Color) -> void:
	if has_key:
		key_label.text     = "KEY [collected]"
		key_label.modulate = color
	else:
		key_label.text     = "KEY [find yours]"
		key_label.modulate = Color(0.6, 0.6, 0.6)

func _toggle_minimap() -> void:
	minimap_open          = !minimap_open
	minimap_panel.visible = minimap_open

func _on_pause_pressed() -> void:
	if NetworkManager.my_id.is_empty():
		pause_label.text     = "Game paused"
		pause_label.modulate = Color.WHITE
		_pause_left          = 20.0
		countdown_label.text = "Auto-resuming in: 20"
		pause_overlay.visible = true
		get_tree().paused    = true
	else:
		NetworkManager.send_pause()

func _on_resume_pressed() -> void:
	if NetworkManager.my_id.is_empty():
		_do_resume()
	else:
		NetworkManager.send_resume()

func _on_game_paused(by_pid: String) -> void:
	var color: Color
	if by_pid == NetworkManager.my_id:
		color = NetworkManager.my_color
		pause_label.text = "You paused the game"
	else:
		color = NetworkManager.players.get(by_pid, {}).get("color", Color.WHITE)
		pause_label.text = "● paused the game"
	pause_label.modulate = color
	_pause_left          = 20.0
	countdown_label.text = "Auto-resuming in: 20"
	pause_overlay.visible = true
	get_tree().paused    = true

func _on_game_resumed() -> void:
	_do_resume()

func _do_resume() -> void:
	_pause_left           = 0.0
	pause_overlay.visible = false
	get_tree().paused     = false
