@tool
extends SceneTree

# ----------------------------------------------------------------------------
# Editor-tooling driver (runs in EDITOR context: --editor --headless --script).
#
# Verifies, headless and gating:
#   (1) Custom class ICONS — the global class registry entry for IconNode carries the
#       `//gd:icon` path (res://icon.svg). This is the registered icon path the editor uses
#       for the Scene dock / Create Node dialog. (Icon PIXELS are visual-only, not asserted.)
#   (2) @tool + gd.is_editor() — a //gd:tool node's _ready runs in the editor and its
#       gd.is_editor() branch fires (it wrote a ProjectSetting we read back after one frame).
#   (4, stretch) EditorInspectorPlugin — the Odin inspector's _can_handle/_parse_begin
#       virtuals DISPATCH into Odin when invoked (best-effort, reported not gated).
#
# (3) EditorPlugin _enter_tree is proven separately by run.sh grepping the editor log.
#
# _ready for the tool node fires one frame AFTER add_child, so the @tool assertion runs in
# _process (the next loop iteration), not _initialize.
# ----------------------------------------------------------------------------

var _scene: Node = null
var _done := false

func _fail(msg: String) -> void:
	print("EDITORTOOLS_FAIL: ", msg)
	quit(1)

func _initialize() -> void:
	if not Engine.is_editor_hint():
		_fail("expected editor context (is_editor_hint false)"); return

	# ---- (1) Custom class icons (GATING) ----
	# The editor's filesystem scan called OdinLanguage._get_global_class_name(path), which
	# threaded the `//gd:icon` marker into the global class registry's icon_path. Assert the
	# IconNode entry in the global class list carries res://icon.svg.
	var icon_script: Script = load("res://addons/odinplugin/icon_node.odin")
	if icon_script == null:
		_fail("could not load icon_node.odin"); return
	if String(icon_script.get_global_name()) != "IconNode":
		_fail("IconNode.get_global_name() got '%s'" % String(icon_script.get_global_name())); return
	var found_icon := false
	var gc_icon := ""
	for entry in ProjectSettings.get_global_class_list():
		if String(entry.get("class", "")) == "IconNode":
			found_icon = true
			gc_icon = String(entry.get("icon", ""))
	if not found_icon:
		_fail("IconNode not in ProjectSettings.get_global_class_list() (scan did not register it)"); return
	if gc_icon != "res://icon.svg":
		_fail("IconNode global-class icon got '%s' want 'res://icon.svg'" % gc_icon); return
	print("  ok  IconNode registered in global class list with icon res://icon.svg")
	print("EDITORTOOLS_ICON_REGISTERED")

	# Instantiate the scene now; the //gd:tool ToolWidget._ready fires on the NEXT frame.
	_scene = load("res://main.tscn").instantiate()
	get_root().add_child(_scene)

# Runs after _initialize, once _ready has had a frame to fire. Return true ends the loop.
func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	# ---- (2) @tool _ready ran in editor + gd.is_editor() (GATING) ----
	var sentinel := int(ProjectSettings.get_setting("odin/tool_widget_editor_ran", 0))
	if sentinel != 4242:
		_fail("ToolWidget._ready did not run in editor / gd.is_editor() false (setting=%d want 4242)" % sentinel)
		return true
	print("  ok  //gd:tool ToolWidget._ready ran in editor; gd.is_editor() == true (setting=4242)")

	# ---- (4) Find-in-Files searches .odin: the Odin EditorPlugin._enter_tree appended
	# "odin" to the hardcoded search_in_file_extensions list (which Godot builds without
	# any hook for GDExtension languages). Assert the setting now contains it. ----
	var exts = ProjectSettings.get_setting("editor/script/search_in_file_extensions", PackedStringArray())
	if not ("odin" in exts):
		_fail("search_in_file_extensions is missing 'odin' (Find-in-Files won't search .odin): %s" % str(exts))
		return true
	print("  ok  Find-in-Files search extensions include 'odin' (%s)" % str(exts))

	# ---- (5, STRETCH) EditorInspectorPlugin virtual dispatch (reported, not gated) ----
	_try_inspector(_scene)

	print("EDITORTOOLS_DRIVER_OK")
	quit(0)
	return true

func _try_inspector(probe: Node) -> void:
	var insp_script: Script = load("res://addons/odinplugin/odin_inspector_plugin.odin")
	if insp_script == null:
		print("  NOTE(stretch): could not load odin_inspector_plugin.odin"); return
	var insp = ClassDB.instantiate("EditorInspectorPlugin")
	if insp == null:
		print("  NOTE(stretch): EditorInspectorPlugin not ClassDB-instantiable headless"); return
	insp.set_script(insp_script)
	if not insp.has_method("_can_handle"):
		print("  NOTE(stretch): inspector instance does not expose _can_handle (virtual dispatch unproven)"); return
	var handled = insp.call("_can_handle", probe)
	if typeof(handled) != TYPE_BOOL or not handled:
		print("  NOTE(stretch): _can_handle did not dispatch true (got %s)" % str(handled)); return
	insp.call("_parse_begin", probe)   # prints EDITORTOOLS_INSPECTOR_PARSE_BEGIN if it runs
	print("  ok(stretch)  Odin EditorInspectorPlugin _can_handle/_parse_begin DISPATCHED into Odin")
	print("EDITORTOOLS_INSPECTOR_DISPATCH_OK")
