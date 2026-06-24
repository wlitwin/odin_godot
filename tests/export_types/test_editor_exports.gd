@tool
extends SceneTree

# Editor-context (PlaceHolderScriptInstance) breadth test for @export types + hints.
#
# In the EDITOR a non-tool Odin script is NOT really instantiated — the engine builds a
# placeholder whose visible properties come ONLY from placeholder_script_instance_update,
# which the core fills from make_property_info (type + hint + hint_string). This is the
# historically-buggy path that headless runtime tests miss, so we assert it directly here.
#
# Run:  $GODOT --editor --headless --path tests/export_types --script test_editor_exports.gd

func _fail(msg: String) -> void:
	print("EXPORT_TYPES_EDITOR_FAIL: ", msg)
	quit(1)

func _prop(node: Object, pname: String) -> Dictionary:
	for p in node.get_property_list():
		if p.get("name", "") == pname:
			return p
	return {}

func _check(node: Object, pname: String, want_type: int, want_hint: int, want_hs: String) -> bool:
	var p = _prop(node, pname)
	if p.is_empty():
		_fail("Inspector missing @export '%s'" % pname); return false
	if int(p.get("type", -1)) != want_type:
		_fail("%s: type got %d want %d" % [pname, int(p.get("type", -1)), want_type]); return false
	if int(p.get("hint", -1)) != want_hint:
		_fail("%s: hint got %d want %d" % [pname, int(p.get("hint", -1)), want_hint]); return false
	if String(p.get("hint_string", "")) != want_hs:
		_fail("%s: hint_string got '%s' want '%s'" % [pname, String(p.get("hint_string", "")), want_hs]); return false
	print("  ok  %-12s type=%d hint=%d hint_string='%s'" % [pname, want_type, want_hint, want_hs])
	return true

func _initialize() -> void:
	if not Engine.is_editor_hint():
		_fail("not running in editor context (is_editor_hint false)"); return

	var scene = load("res://export_types.tscn").instantiate()
	get_root().add_child(scene)
	var n = scene.get_node("Probe")

	if not _check(n, "health",      TYPE_INT,                 PROPERTY_HINT_RANGE,          "0,100,5"): return
	if not _check(n, "mode",        TYPE_INT,                 PROPERTY_HINT_ENUM,           "Idle,Walk,Run"): return
	if not _check(n, "description", TYPE_STRING,              PROPERTY_HINT_MULTILINE_TEXT, ""): return
	if not _check(n, "velocity",    TYPE_VECTOR3,             PROPERTY_HINT_NONE,           ""): return
	if not _check(n, "tint",        TYPE_COLOR,               PROPERTY_HINT_NONE,           ""): return
	if not _check(n, "grid",        TYPE_VECTOR2I,            PROPERTY_HINT_NONE,           ""): return
	if not _check(n, "scores",      TYPE_PACKED_INT32_ARRAY,  PROPERTY_HINT_NONE,           ""): return
	if not _check(n, "target",      TYPE_NODE_PATH,           PROPERTY_HINT_NONE,           ""): return
	if not _check(n, "texture",     TYPE_OBJECT,              PROPERTY_HINT_RESOURCE_TYPE,  "Texture2D"): return

	print("EXPORT_TYPES_EDITOR_OK")
	quit(0)
