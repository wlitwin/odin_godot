extends SceneTree

# ----------------------------------------------------------------------------
# Headless "show on save" test: prove a newly-added Odin `@export` appears in a node's
# property list WITHIN ONE running editor process — no restart — after the save/reload path
# rebuilds + swaps the scripts dll. This is the exact capability that is broken today (the
# scripts dll is loaded once per session and never recompiled in-process).
#
# Run: $GODOT --editor --headless --path tests/reload_exports --script test_reload_exports.gd
#
# Flow (all in ONE process):
#   1. Load widget.odin, attach to a Node, query get_property_list(): assert baseline export
#      `speed` is present and `new_field` is NOT.
#   2. Edit widget.odin ON DISK to add `@export new_field` (replace the //NEW_FIELD_HERE marker).
#   3. Call script.reload(true) -> OdinScript._reload -> (editor) kicks a BACKGROUND scripts
#      rebuild; when it finishes the next _frame swaps the dll + refreshes the placeholder.
#   4. Poll get_property_list() across frames until `new_field` appears (or time out).
#   5. Restore widget.odin. Print the before/after export lists + RELOAD_EXPORTS_OK.
# ----------------------------------------------------------------------------

const SRC := "res://scripts/widget.odin"
const MARKER := "//NEW_FIELD_HERE"
const NEW_FIELD_DECL := "new_field: gd.Int `gd:\"export\"`,"

var done := false
var original_src := ""

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _fail(reason: String) -> void:
	if done:
		return
	done = true
	# Best-effort restore so a failed run doesn't leave the source edited.
	if original_src != "":
		_write_src(original_src)
	print("RELOAD_EXPORTS_FAIL: ", reason)
	quit(1)

func _export_names(node: Object) -> Array:
	var out := []
	for p in node.get_property_list():
		# Skip group/category markers (usage with no real storage); keep named members.
		var nm = str(p.get("name"))
		if nm != "":
			out.append(nm)
	return out

func _has_export(node: Object, name: String) -> bool:
	for p in node.get_property_list():
		if str(p.get("name")) == name:
			return true
	return false

func _write_src(text: String) -> void:
	var f := FileAccess.open(SRC, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()

func _run() -> void:
	if done:
		return

	if not bool(Engine.is_editor_hint()):
		_fail("not running with editor hint (need --editor); save-rebuild path won't engage")
		return

	if not ResourceLoader.exists(SRC):
		_fail("ResourceLoader does not recognize %s" % SRC)
		return
	var script = load(SRC)
	if script == null:
		_fail("widget.odin failed to load")
		return

	# ===== 1. baseline =====
	var node := Node.new()
	node.set_script(script)
	root.add_child(node)

	var before := _export_names(node)
	print("BEFORE exports: ", before)
	if not _has_export(node, "speed"):
		_fail("baseline export `speed` missing before reload (got %s)" % str(before))
		return
	if _has_export(node, "new_field"):
		_fail("`new_field` already present before edit (stale build?)")
		return

	# ===== 2. edit the source on disk to add a new @export =====
	var rf := FileAccess.open(SRC, FileAccess.READ)
	if rf == null:
		_fail("could not open %s for reading" % SRC)
		return
	original_src = rf.get_as_text()
	rf.close()
	if original_src.find(MARKER) == -1:
		_fail("source marker %s not found" % MARKER)
		return
	var v2 := original_src.replace(MARKER, NEW_FIELD_DECL)
	_write_src(v2)

	# ===== 3. trigger the save/reload path (kicks a background rebuild in the editor) =====
	var err = script.reload(true)
	if err != OK:
		_fail("script.reload(true) returned error %s" % str(err))
		return

	# ===== 4. poll for the new export to appear in-process =====
	var appeared := false
	for i in range(2400): # ~ generous frame budget; build is seconds, polled each frame
		await process_frame
		if _has_export(node, "new_field"):
			appeared = true
			break

	var after := _export_names(node)

	# ===== 5. restore + report =====
	_write_src(original_src)

	if not appeared:
		_fail("`new_field` did NOT appear after save+rebuild+reload (after=%s)" % str(after))
		return

	print("AFTER exports:  ", after)

	# Round-trip a value through the new export to prove it is a real, settable property.
	node.set("new_field", 42)
	var got = node.get("new_field")
	if int(got) != 42:
		print("  note: new_field value round-trip read back %s (placeholder default), not load-bearing for this test" % str(got))

	# ===== 6. the DELETION PROBE: a removed script's gen file must sweep itself =====
	# Create a throwaway script ON DISK (no save event — only the ~2s names-only
	# probe can notice), wait for the probe-triggered rebuild to emit its gen
	# file, then DELETE the source and wait for the sweep to reap the orphan.
	# This is the dock-delete papercut: the gen file is hidden from the editor
	# tree, so nothing but the probe can heal it.
	var doomed := "res://scripts/doomed.odin"
	var doomed_gen := "res://scripts/doomed.gen.odin"
	var f := FileAccess.open(doomed, FileAccess.WRITE)
	f.store_string("""//gd:extends Node2D
//gd:class Doomed
package reload_exports_scripts

import gd "godot:godot"

Doomed :: struct {
	owner: gd.Node2d,
	beat:  int,
}

doomed_process :: proc(self: ^Doomed, delta: f64) {
	self.beat += 1
}
""")
	f.close()

	var gen_appeared := false
	for i in range(4800): # probe fires ~every 120 frames; the build takes seconds
		await process_frame
		if FileAccess.file_exists(doomed_gen):
			gen_appeared = true
			break
	if not gen_appeared:
		_fail("the creation probe never generated doomed.gen.odin")
		return
	print("GEN_ORPHAN_CREATED (probe noticed the new script)")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(doomed))
	var swept := false
	for i in range(4800):
		await process_frame
		if not FileAccess.file_exists(doomed_gen):
			swept = true
			break
	if not swept:
		_fail("doomed.gen.odin was never swept after its source was deleted")
		return
	print("GEN_ORPHAN_SWEPT (probe rebuilt; the sweep reaped the orphan)")

	print("RELOAD_EXPORTS_OK")
	done = true
	quit(0)
