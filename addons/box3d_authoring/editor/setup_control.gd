@tool
class_name Box3DSetupControl
extends VBoxContainer

var controller: EditorPlugin
var status_label := Label.new()
var action := Button.new()
var detail := Label.new()
var _elapsed: float = 0.0
var _state: String = ""
var _source_state: String = ""
func _init(owner: EditorPlugin = null) -> void:
	controller = owner
	name = "Box3DSetup"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label); add_child(action); add_child(detail)
	action.pressed.connect(_act)
func _ready() -> void: refresh()
func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 1.0:
		_elapsed = 0.0
		refresh()
func refresh() -> void:
	if not is_instance_valid(controller) or controller.services == null: return
	var status: Dictionary = controller.services.setup_status()
	_state = status.state
	_source_state = status.get("source_state", _state)
	status_label.text = status.get("message", "")
	action.disabled = _state in ["building", "missing_package"]
	match _state:
		"install":
			status_label.text = "Install the Box3D tools to enable shape previews, validation and baking."
			action.text = "Install tools and build"
		"update":
			status_label.text = "A tool source update is available. Your installed sources are unchanged."
			action.text = "Update tools and build"
		"conflict": action.text = "Build project tools"
		"missing_package": action.text = "Reinstall Box3D addon"
		"building": action.text = "Building…"
		"ready": action.text = "Rebuild tools"
		_: action.text = "Build Odin Scripts"
	if _state != "building" and _source_state in ["install", "update"]:
		action.text = "Install tools and build" if _source_state == "install" else "Update tools and build"
	if status.has("conflicts") and not status.conflicts.is_empty():
		detail.text = "\n".join(status.conflicts) + "\nPackaged sources: " + Box3DToolSetup.SOURCE
func _act() -> void:
	detail.text = ""
	if _source_state in ["install", "update"]:
		var installed: Dictionary = controller.services.install_tools()
		if not installed.get("ok", false): detail.text = installed.error; refresh(); return
		controller.get_editor_interface().get_resource_filesystem().scan()
	var built: Dictionary = controller.services.request_build()
	if not built.get("ok", false): detail.text = built.error
	controller._refresh_previews()
	refresh()
