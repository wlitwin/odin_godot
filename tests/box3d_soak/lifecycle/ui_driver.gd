extends Node

# Test-owned adapter to the actual shipped UI methods. No Runtime/World access.
var _path := ""
var _seen := 0

func _ready() -> void:
	_path = OS.get_environment("B3_LIFECYCLE_UI_FILE")
	set_process(OS.get_environment("B3_ROLE") == "client" and not _path.is_empty())

func _process(_delta: float) -> void:
	if not FileAccess.file_exists(_path):
		return
	var command = JSON.parse_string(FileAccess.get_file_as_string(_path))
	if not command is Dictionary or not command.get("id") is float:
		_failure("invalid_control_file")
		return
	var command_id := int(command["id"])
	if command_id <= _seen:
		return
	_seen = command_id
	var action: String = command.get("action", "")
	if action != "reset" and action != "reconnect":
		_failure("unsupported_public_UI_action")
		return
	var scene := get_tree().current_scene
	var method := "on_" + action
	if scene == null or not scene.has_method(method):
		_failure("actual_scene_public_method_unavailable:" + method)
		return
	print(JSON.stringify({"event":"STATUS", "stage":"lifecycle_UI", "phase":"invoke",
		"role":"client", "id":command_id, "method":method,
		"scope":"actual_shipped_UI_method_NOT_request_delivery_or_Reset_proof"}))
	scene.call(method)
	print(JSON.stringify({"event":"STATUS", "stage":"lifecycle_UI", "phase":"returned",
		"role":"client", "id":command_id, "method":method}))

func _failure(reason: String) -> void:
	set_process(false)
	print(JSON.stringify({"event":"ERROR", "where":"lifecycle_UI", "role":"client", "reason":reason}))
	get_tree().quit(1)
