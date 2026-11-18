extends Control
@export var custom_title: String = "My custom root script"
func _ready():
	var window := get_tree().root
	window.set_meta("kit_ui_custom_ready_count", int(window.get_meta("kit_ui_custom_ready_count",0))+1)
