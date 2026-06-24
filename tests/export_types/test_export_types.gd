extends SceneTree

# Runtime (REAL script instance) breadth test for @export Variant types + hints.
#
# Headless, NON-editor: the Probe script is instantiated for real, so get_property_list()
# is served by the core's inst_get_property_list (with hint/hint_string), and set()/get()
# round-trip through the real inst_set/inst_get (including i32 width-narrowing).
#
# Run:  $GODOT --headless --path tests/export_types --script test_export_types.gd

func _fail(msg: String) -> void:
	print("EXPORT_TYPES_FAIL: ", msg)
	quit(1)

func _prop(node: Object, pname: String) -> Dictionary:
	for p in node.get_property_list():
		if p.get("name", "") == pname:
			return p
	return {}

# Assert a property's reported Variant type + hint + hint_string.
func _check(node: Object, pname: String, want_type: int, want_hint: int, want_hs: String) -> bool:
	var p = _prop(node, pname)
	if p.is_empty():
		_fail("missing @export '%s' in property list" % pname); return false
	if int(p.get("type", -1)) != want_type:
		_fail("%s: type got %d want %d" % [pname, int(p.get("type", -1)), want_type]); return false
	if int(p.get("hint", -1)) != want_hint:
		_fail("%s: hint got %d want %d" % [pname, int(p.get("hint", -1)), want_hint]); return false
	if String(p.get("hint_string", "")) != want_hs:
		_fail("%s: hint_string got '%s' want '%s'" % [pname, String(p.get("hint_string", "")), want_hs]); return false
	print("  ok  %-12s type=%d hint=%d hint_string='%s'" % [pname, want_type, want_hint, want_hs])
	return true

func _initialize() -> void:
	var scene = load("res://export_types.tscn").instantiate()
	get_root().add_child(scene)
	var n = scene.get_node("Probe")

	# --- property list: type + hint + hint_string across the breadth ---
	if not _check(n, "health",      TYPE_INT,                 PROPERTY_HINT_RANGE,          "0,100,5"): return
	if not _check(n, "mode",        TYPE_INT,                 PROPERTY_HINT_ENUM,           "Idle,Walk,Run"): return
	if not _check(n, "description", TYPE_STRING,              PROPERTY_HINT_MULTILINE_TEXT, ""): return
	if not _check(n, "velocity",    TYPE_VECTOR3,             PROPERTY_HINT_NONE,           ""): return
	if not _check(n, "tint",        TYPE_COLOR,               PROPERTY_HINT_NONE,           ""): return
	if not _check(n, "grid",        TYPE_VECTOR2I,            PROPERTY_HINT_NONE,           ""): return
	if not _check(n, "scores",      TYPE_PACKED_INT32_ARRAY,  PROPERTY_HINT_NONE,           ""): return
	if not _check(n, "target",      TYPE_NODE_PATH,           PROPERTY_HINT_NONE,           ""): return
	if not _check(n, "texture",     TYPE_OBJECT,              PROPERTY_HINT_RESOURCE_TYPE,  "Texture2D"): return

	# --- set/get round-trips through the real instance vtable ---
	n.set("health", 42) # i32 width-narrow
	if int(n.get("health")) != 42:
		_fail("health round-trip: got %s" % str(n.get("health"))); return

	n.set("mode", 2)
	if int(n.get("mode")) != 2:
		_fail("mode round-trip: got %s" % str(n.get("mode"))); return

	n.set("description", "alpha\nbeta")
	if String(n.get("description")) != "alpha\nbeta":
		_fail("description round-trip: got %s" % str(n.get("description"))); return

	n.set("velocity", Vector3(1.5, 2.5, 3.5))
	if n.get("velocity") != Vector3(1.5, 2.5, 3.5):
		_fail("velocity round-trip: got %s" % str(n.get("velocity"))); return

	n.set("tint", Color(0.1, 0.2, 0.3, 0.4))
	if n.get("tint") != Color(0.1, 0.2, 0.3, 0.4):
		_fail("tint round-trip: got %s" % str(n.get("tint"))); return

	n.set("grid", Vector2i(7, 9))
	if n.get("grid") != Vector2i(7, 9):
		_fail("grid round-trip: got %s" % str(n.get("grid"))); return

	n.set("scores", PackedInt32Array([10, 20, 30]))
	if n.get("scores") != PackedInt32Array([10, 20, 30]):
		_fail("scores round-trip: got %s" % str(n.get("scores"))); return

	n.set("target", NodePath("../Other/Thing"))
	if n.get("target") != NodePath("../Other/Thing"):
		_fail("target round-trip: got %s" % str(n.get("target"))); return

	print("EXPORT_TYPES_OK")
	quit(0)
