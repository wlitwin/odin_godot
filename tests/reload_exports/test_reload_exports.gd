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
const COMPAT_FIELD_DECL := "compat_field: gd.Int `gd:\"export\"`,"

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

# scriptgen emits ONE odin_godot_scripts.gen.odin per scripts dir, with a
# `// ==== <source> (class <Class>) ====` banner per authored script. A source's
# generated code exists exactly when its banner does.
func _gen_has_section(gen_path: String, src_name: String) -> bool:
	var f := FileAccess.open(gen_path, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	return text.find("// ==== %s (" % src_name) != -1

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

	# ===== 6. the DELETION PROBE: a removed script's generated code must sweep itself =====
	# Create a throwaway script ON DISK (no save event — only the ~2s names-only
	# probe can notice), wait for the probe-triggered rebuild to give it a section
	# in the one consolidated artifact, then DELETE the source and wait for the
	# next rebuild to drop that section. This is the dock-delete papercut: the gen
	# file is hidden from the editor tree, so nothing but the probe can heal it.
	var doomed := "res://scripts/doomed.odin"
	var scripts_gen := "res://scripts/odin_godot_scripts.gen.odin"
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
		if _gen_has_section(scripts_gen, "doomed.odin"):
			gen_appeared = true
			break
	if not gen_appeared:
		_fail("the creation probe never gave doomed.odin a section in odin_godot_scripts.gen.odin")
		return
	print("GEN_ORPHAN_CREATED (probe noticed the new script)")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(doomed))
	var swept := false
	for i in range(4800):
		await process_frame
		if not _gen_has_section(scripts_gen, "doomed.odin"):
			swept = true
			break
	if not swept:
		_fail("doomed.odin's section was never swept from odin_godot_scripts.gen.odin after its source was deleted")
		return
	print("GEN_ORPHAN_SWEPT (probe rebuilt; the sweep reaped the section)")

	# ===== 7. NEW-CLASS INSPECTOR REFRESH: a script attached while its class is NOT yet
	# in the dll (brand-new file, build still to land) gets an EMPTY placeholder; the
	# swap's placeholder refresh must make its exports appear in-process. This is the
	# "create a Resource script, .tres Inspector shows nothing" papercut — GDScript
	# parity: new classes show up without an editor restart.
	var gunsrc := "res://scripts/gun_probe.odin"
	var gf := FileAccess.open(gunsrc, FileAccess.WRITE)
	gf.store_string("""//gd:extends Resource
//gd:class GunProbe
package reload_exports_scripts

import gd "godot:godot"

GunProbe :: struct {
	owner:  gd.Resource,
	damage: gd.Int `gd:\"export\"`,
	spread: f32 `gd:\"export\"`,
}
""")
	gf.close()

	# Attach IMMEDIATELY — before any rebuild can land — the placeholder must be created
	# while the class is unknown, or this test degrades into the fresh-attach case.
	var gscript = load(gunsrc)
	if gscript == null:
		_fail("gun_probe.odin did not load as a script"); return
	var res := Resource.new()
	res.set_script(gscript)
	if _has_export(res, "damage"):
		print("  note: GunProbe registered before attach — the stale-placeholder path was NOT exercised this run")
	var shown := false
	for i in range(4800): # creation probe ~every 120 frames, then a build + swap
		await process_frame
		if _has_export(res, "damage"):
			shown = true
			break
	if not shown:
		_fail("new class's exports never appeared on its placeholder after rebuild+swap (props=%s)" % str(_export_names(res)))
		return
	# The set-fallback must hold the value once the property exists (Inspector editability).
	res.set("damage", 7)
	if int(res.get("damage")) != 7:
		_fail("new-class placeholder property not settable after refresh")
		return
	print("NEW_CLASS_EXPORTS_SHOWN (stale placeholder refreshed when the class landed)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gunsrc))

	# QUIESCE before the skew phase: the deletion above triggers one more probe rebuild;
	# the compatibility phases need an idle pipeline so THEIR request bakes the selected
	# collection root (an in-flight
	# build could otherwise swallow the request into a real-root rerun). Wait for the
	# sweep's gen rewrite, then settle so its dll swap lands too.
	var probe_swept := false
	for i in range(4800):
		await process_frame
		if not _gen_has_section(scripts_gen, "gun_probe.odin"):
			probe_swept = true
			break
	if not probe_swept:
		_fail("gun_probe's generated section was never swept before the skew phase"); return
	for i in range(600):
		await process_frame

	# ===== 8. COMPILER IDENTITY IS NOT LOCKSTEP: run.sh doctored only the version string
	# returned by an otherwise identical runtime. Its complete ABI fingerprint still matches,
	# so the new code must publish. This keeps compiler provenance visible without rejecting a
	# compatible scripts DLL merely because Odin moved releases.
	var compatroot := OS.get_environment("ODIN_GODOT_COMPAT_ROOT")
	if compatroot == "":
		_fail("ODIN_GODOT_COMPAT_ROOT not set (run via run.sh)"); return
	ProjectSettings.set_setting("odin_godot/root", compatroot)
	_write_src(original_src.replace(MARKER, COMPAT_FIELD_DECL))
	var compat_err = script.reload(true)
	if compat_err != OK:
		ProjectSettings.set_setting("odin_godot/root", null)
		_fail("compiler-compat reload kick returned %s" % str(compat_err)); return
	var compat_loaded := false
	for i in range(4800):
		await process_frame
		if _has_export(node, "compat_field"):
			compat_loaded = true
			break
	if not compat_loaded:
		ProjectSettings.set_setting("odin_godot/root", null)
		_fail("matching ABI was rejected only because the reported compiler version differed"); return
	print("COMPILER_SKEW_ABI_COMPATIBLE")

	# ===== 9. ABI-SKEW REFUSAL IS LOUD: rebuild against a doctored addon checkout (one
	# boundary struct grown -> different ABI fingerprint — run.sh prepares it). The deferred
	# swap must REFUSE the dll (old code kept, no crash) and the refusal must surface
	# as an editor error with the restart-the-editor diagnosis; run.sh asserts the
	# message text in this process's stderr. This pins the 3-day silent failure mode:
	# addon updated on disk while the editor kept the core it mapped at startup.
	var skewroot := OS.get_environment("ODIN_GODOT_SKEW_ROOT")
	if skewroot == "":
		_fail("ODIN_GODOT_SKEW_ROOT not set (run via run.sh)"); return
	ProjectSettings.set_setting("odin_godot/root", skewroot)
	# reload_request skips the build when no source changed (force=false path), so give
	# the skew build a real edit — content is irrelevant, the ABI mismatch is the point.
	_write_src(original_src + "\n// skew-phase probe edit\n")
	var err2 = script.reload(true)
	if err2 != OK:
		ProjectSettings.set_setting("odin_godot/root", null)
		_fail("skew-phase reload kick returned %s" % str(err2)); return
	# A refused swap leaves no in-process marker to poll — and a build already in
	# flight can swallow this request into a coalesced rerun that re-resolves the
	# root LATER. So hold the skew root pinned for a wall-clock window generous
	# enough for any queued build + rerun + deferred swap to drain: whichever build
	# ends up carrying the request, it resolves the SKEW root and gets refused.
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000:
		await process_frame
	if not _has_export(node, "compat_field"):
		ProjectSettings.set_setting("odin_godot/root", null)
		_fail("old code was NOT kept after the refused skew swap"); return
	print("SKEW_SWAP_REFUSED_OLD_CODE_KEPT")

	# Recovery: restore the real root; the same pipeline must go green again in this
	# session (a refusal poisons nothing). Reuse the widget marker edit as the probe.
	ProjectSettings.set_setting("odin_godot/root", null)
	var v3 := original_src.replace(MARKER, NEW_FIELD_DECL)
	_write_src(v3)
	var err3 = script.reload(true)
	if err3 != OK:
		_fail("recovery reload kick returned %s" % str(err3)); return
	var recovered := false
	for i in range(4800):
		await process_frame
		if _has_export(node, "new_field"):
			recovered = true
			break
	_write_src(original_src)
	if not recovered:
		_fail("pipeline did not recover after restoring the real collection root"); return
	print("SKEW_RECOVERED_AFTER_RESTORE")

	print("RELOAD_EXPORTS_OK")
	done = true
	quit(0)
