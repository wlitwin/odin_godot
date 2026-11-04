@tool
class_name Box3DEditorServices
extends RefCounted

const MODULE_DIR := "res://modules/box3d_authoring_tools"
const MODULE_SCRIPT := MODULE_DIR+"/tools.odin"
var _owner: Node
var _tools: Node
var last_error: String=""
func _init(owner: Node=null) -> void:_owner=owner
func dispose() -> void:
	if is_instance_valid(_tools):_tools.free()
	_tools=null
func install_once() -> Dictionary:
	var source: String="res://addons/box3d_authoring/tool_module"
	var names: PackedStringArray=DirAccess.get_files_at(source)
	if names.is_empty():return {"ok":false,"error":"Packaged tool module source is missing."}
	for name in names:
		if not name.ends_with(".odin"):continue
		if FileAccess.file_exists(MODULE_DIR+"/"+name) and FileAccess.get_sha256(MODULE_DIR+"/"+name)!=FileAccess.get_sha256(source+"/"+name):
			return {"ok":false,"error":"Existing tool module differs; explicit project update required, never overwritten."}
	if DirAccess.make_dir_recursive_absolute(MODULE_DIR)!=OK:return {"ok":false,"error":"Cannot create ordinary module directory."}
	var copied: int=0
	for name in names:
		if not name.ends_with(".odin") or FileAccess.file_exists(MODULE_DIR+"/"+name):continue
		if DirAccess.copy_absolute(source+"/"+name,MODULE_DIR+"/"+name)!=OK:return {"ok":false,"error":"Module source copy failed."}
		copied+=1
	return {"ok":true,"copied":copied,"path":MODULE_DIR,"next":"Use ordinary Build Odin Scripts, then enable tools; no Core bypass."}
func available() -> bool:
	if is_instance_valid(_tools):return true
	if not FileAccess.file_exists(MODULE_SCRIPT):last_error="Install the shared tool module once, then Build Odin Scripts.";return false
	var compiled: bool=false
	for name in DirAccess.get_files_at("res://bin"):
		if name.begins_with("libodinscripts_box3d_authoring_tools") and name.get_extension() in ["dylib","so","dll"]:compiled=true
	if not compiled:last_error="Shared tool module source is installed but its ordinary module build is unavailable.";return false
	var script: Script=load(MODULE_SCRIPT)
	if script==null or not script.can_instantiate():last_error="Shared tool module could not load through the ordinary script loader.";return false
	_tools=Node.new();_tools.set_script(script)
	if _owner!=null:_owner.add_child(_tools)
	for method in ["inspect_definition_json","bake_definition_json","inspect_artifact_base64"]:
		if not _tools.has_method(method):dispose();last_error="Tool module API mismatch: "+method;return false
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
func bake_definition(definition: Dictionary,source_uri: String,source_revision: String) -> Dictionary:
	return invoke("bake_definition_json",[JSON.stringify(definition,"",true,true),source_uri,source_revision])
func inspect_artifact(value: String) -> Dictionary:
	return invoke("inspect_artifact_base64",[value])
