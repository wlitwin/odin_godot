@tool
extends EditorPlugin
func _enter_tree():
	if OS.get_environment("KIT_UI_EDITOR_CHECK") == "1":
		call_deferred("run")
func run():
	var driver = load("res://editor.gd").new()
	driver.plugin = self
	add_child(driver)
