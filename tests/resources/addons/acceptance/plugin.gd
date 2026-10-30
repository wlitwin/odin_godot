@tool
extends EditorPlugin
func _enter_tree() -> void:
	if OS.get_environment("RESOURCES_EDITOR_CHECK") == "1": call_deferred("_run_checks")
func _run_checks() -> void:
	await get_tree().process_frame
	for _i in 600:
		if not EditorInterface.get_resource_filesystem().is_scanning():
			var checks = load("res://test_editor_resources.gd").new()
			checks.run(get_tree())
			return
		await get_tree().process_frame
	print("RESOURCES_EDITOR_FAIL: editor initial scan did not finish")
	get_tree().quit(1)
