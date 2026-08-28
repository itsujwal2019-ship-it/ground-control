extends CanvasLayer

@onready var key_label: Label = $KeyLabel
@onready var minimap_button: Button = $MinimapButton
@onready var minimap_panel: Panel = $MinimapPanel

var minimap_open := false

func _ready() -> void:
	minimap_button.pressed.connect(_toggle_minimap)
	minimap_panel.visible = false
	update_key_status(false, Color.WHITE)

func update_key_status(has_key: bool, color: Color) -> void:
	if has_key:
		key_label.text = "KEY [collected]"
		key_label.modulate = color
	else:
		key_label.text = "KEY [find yours]"
		key_label.modulate = Color(0.6, 0.6, 0.6)

func _toggle_minimap() -> void:
	minimap_open = !minimap_open
	minimap_panel.visible = minimap_open
