@tool
extends RefCounted

# ----------------------------------------------------------------------------
# Editor-context custom-resource check (gotcha #4). Run with `--editor --headless`.
#
# A Resource is editable in the editor: attaching the Odin script via set_script() routes
# straight through `_instance_create` (NOT gated by `_can_instantiate`, unlike a scene
# node), so the editor gets a REAL, live instance whose @export values are settable and
# SERIALIZE on save. This asserts: editor_hint is true, the @export vars are visible in the
# property list (so the Inspector shows them), and an edit-then-save-then-reload round-trip
# persists the values — all WITHOUT a crash / missing-virtual error.
#
# Run: RESOURCES_EDITOR_CHECK=1 $GODOT --editor --headless --path tests/resources
# ----------------------------------------------------------------------------

func _fail(msg: String) -> void:
	print("RESOURCES_EDITOR_FAIL: ", msg)
	tree.quit(1)

var tree: SceneTree
func run(editor_tree: SceneTree) -> void:
	tree = editor_tree
	if not Engine.is_editor_hint():
		_fail("expected editor context"); return

	var script: Script = load("res://scripts/item_data.odin")
	if script == null:
		_fail("could not load item_data.odin"); return

	var item := Resource.new()
	item.set_script(script)

	# @export vars must be visible in the editor property list (drives the Inspector).
	var visible := {}
	for p in item.get_property_list():
		var nm = String(p.get("name", ""))
		if nm in ["name", "value", "icon"] and (int(p.get("usage", 0)) & PROPERTY_USAGE_EDITOR) != 0:
			visible[nm] = true
	for want in ["name", "value", "icon"]:
		if not visible.has(want):
			_fail("@export '%s' not visible in editor property list" % want); return
	print("  ok  @export vars visible in the editor Inspector")

	# Edit in the editor, save, reload from disk -> values persist (real instance, serialized).
	item.set("name", "EdSword")
	item.set("value", 7)
	var err := ResourceSaver.save(item, "res://editor_item.tres")
	if err != OK:
		_fail("editor-context save failed: %d" % err); return
	var loaded := ResourceLoader.load("res://editor_item.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or String(loaded.get("name")) != "EdSword" or int(loaded.get("value")) != 7:
		_fail("editor-edited values did not persist through save/load"); return
	print("  ok  editor edit -> save -> reload persists @export values")

	print("RESOURCES_EDITOR_OK")
	tree.quit(0)
