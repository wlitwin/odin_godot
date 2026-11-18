@tool
extends EditorPlugin

func _enter_tree() -> void:
	if OS.get_environment("SHARED_SPIKE_RELOAD") == "1":
		_start.call_deferred()

func _start() -> void:
	var driver = load("res://test_shared_reload.gd").new()
	add_child(driver)
