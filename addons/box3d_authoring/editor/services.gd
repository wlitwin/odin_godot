@tool
class_name Box3DEditorServices
extends RefCounted

const MODULE_DIR := "res://modules/box3d_authoring_tools"
const MODULE_SCRIPT := MODULE_DIR+"/tools.odin"
var _owner: Node
var _tools: Node
var last_error: String=""
var pending_imports: PackedStringArray = []
func _init(owner: Node=null) -> void:_owner=owner
func dispose() -> void:
	if is_instance_valid(_tools):_tools.free()
	_tools=null
func install_tools() -> Dictionary:
	var result := Box3DToolSetup.apply()
	if result.get("ok", false) and result.get("changed", false): dispose()
	return result
func build_coordinator() -> Node:
	if not is_instance_valid(_owner) or not _owner.is_inside_tree(): return null
	for node in _owner.get_tree().get_nodes_in_group("odin_editor"):
		if node.has_method("request_build") and node.has_method("get_build_state"): return node
	return null
func request_build() -> Dictionary:
	var coordinator := build_coordinator()
	if coordinator == null: return {"ok": false, "error": "Install or update odin_godot, reopen Godot, then use Build Odin Scripts."}
	dispose()
	coordinator.call("request_build")
	return {"ok": true}
func setup_status() -> Dictionary:
	var source := Box3DToolSetup.inspect()
	var coordinator := build_coordinator()
	if coordinator != null:
		var progress: Dictionary = {}
		match int(coordinator.call("get_build_state")):
			1: progress = {"state": "building", "message": "Building Odin scripts… Progress is in the Output panel."}
			2: progress = {"state": "failed", "message": "The Odin build failed. Fix the error in Output, then build again."}
			3: progress = {"state": "compiler_missing", "message": "Set odin_godot/odin_bin in Project Settings to your Odin compiler, then build."}
		if not progress.is_empty():
			progress["conflicts"] = source.get("conflicts", [])
			progress["source_state"] = source.state
			return progress
	if source.state in ["install", "update", "missing_package"]: return source
	var ready := available()
	if source.state == "conflict":
		source.message += "\nProject tools are ready." if ready else "\n" + last_error
		return source
	if ready: return {"state": "ready", "message": "Box3D previews and baking are ready."}
	return {"state": "build", "message": last_error}
func available() -> bool:
	var coordinator := build_coordinator()
	if coordinator != null and int(coordinator.call("get_build_state")) == 1:
		last_error = "Building Odin scripts…"
		return false
	if not FileAccess.file_exists(MODULE_SCRIPT): last_error="Install the Box3D tools to enable previews and baking."; return false
	var extension: String = {"macOS": "dylib", "Linux": "so", "Windows": "dll"}.get(OS.get_name(), "")
	if extension.is_empty() or not FileAccess.file_exists("res://bin/libodinscripts_box3d_authoring_tools." + extension):
		last_error="Tool sources are installed. Build Odin Scripts to enable previews and baking."; return false
	if not is_instance_valid(_tools):
		var script: Script=load(MODULE_SCRIPT)
		if script==null or not script.can_instantiate():last_error="Tool module cannot load. Build Odin Scripts and check Output for errors.";return false
		_tools=Node.new();_tools.set_script(script)
		if _owner!=null:_owner.add_child(_tools)
	for method in ["source_hash","inspect_definition_json","validate_definition_json","preview_shapes_json","bake_definition_json","inspect_artifact_base64"]:
		if not _tools.has_method(method):dispose();last_error="The loaded tools are outdated. Build Odin Scripts to update them.";return false
	if String(_tools.call("source_hash")) != FileAccess.get_sha256(MODULE_SCRIPT):
		dispose();last_error="Tool sources changed since the loaded build. Build Odin Scripts to use them.";return false
	last_error="";return true
func invoke(method: String,args: Array) -> Dictionary:
	if not available():return {"version":1,"ok":false,"diagnostic":{"error":"ToolsUnavailable","field":MODULE_SCRIPT,"message":last_error}}
	var raw: Variant=_tools.callv(method,args)
	if not raw is String:return {"ok":false,"diagnostic":{"error":"ToolReturn","field":method}}
	var result: Variant=JSON.parse_string(raw)
	if not result is Dictionary or result.get("version",0)!=1:return {"ok":false,"diagnostic":{"error":"ToolVersion","field":method}}
	return result
func inspect_definition(definition: Dictionary) -> Dictionary:
	return invoke("inspect_definition_json",[JSON.stringify(definition,"",true,true)])
func preview_shapes(items: Array, max_lines: int) -> Dictionary:
	return invoke("preview_shapes_json",[JSON.stringify({"version":1,"max_lines":max_lines,"items":items},"",true,true)])
func validate_definition(definition: Dictionary) -> Dictionary:
	return invoke("validate_definition_json",[JSON.stringify(definition,"",true,true)])
func bake_definition(definition: Dictionary,source_uri: String,source_revision: String) -> Dictionary:
	return invoke("bake_definition_json",[JSON.stringify(definition,"",true,true),source_uri,source_revision])
func inspect_artifact(value: String) -> Dictionary:
	return invoke("inspect_artifact_base64",[value])
