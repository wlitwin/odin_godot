extends SceneTree

# Regression test for OdinResourceFormatSaver — saving a .odin script to disk.
# Without the saver, ResourceSaver.save() returns ERR_FILE_UNRECOGNIZED ("failed to save
# script to the filesystem") for both Ctrl+S and the Create-Script wizard. We save to a
# THROWAWAY res:// path (never touching the real scripts) and confirm it persisted.

func _initialize() -> void:
	var src = load("res://scripts/hud.odin")    # any real OdinScript provides source text
	var probe := "res://__save_probe.odin"
	var os_path := ProjectSettings.globalize_path(probe)

	var err = ResourceSaver.save(src, probe)
	var on_disk := FileAccess.file_exists(os_path) and FileAccess.get_file_as_string(os_path).length() > 0

	# Clean up the throwaway file regardless of outcome.
	if FileAccess.file_exists(os_path):
		DirAccess.remove_absolute(os_path)
	var uid := os_path + ".uid"
	if FileAccess.file_exists(uid):
		DirAccess.remove_absolute(uid)

	# Regression: saving a NON-script (a scene) to a .odin path must FAIL GRACEFULLY, not crash.
	# The editor's Save-As dialog can pick .odin by accident; the saver's _recognize must reject
	# a non-OdinScript so sv_save never calls Script.get_source_code() on it (that segfaults).
	# Reaching the assertion below at all proves "no crash"; scene_err proves the graceful error.
	var n := Node2D.new()
	var ps := PackedScene.new()
	ps.pack(n)
	var scene_probe := "res://__save_scene_probe.odin"
	var scene_err = ResourceSaver.save(ps, scene_probe)
	var scene_os := ProjectSettings.globalize_path(scene_probe)
	if FileAccess.file_exists(scene_os):
		DirAccess.remove_absolute(scene_os)
	n.free()
	var scene_rejected = scene_err != OK

	# The EDITOR'S create-a-new-script flow, distinct from the load-then-save
	# above: the Create-Script dialog mints a FRESH OdinScript (never loaded
	# from disk) and saves it. A regression here surfaces to the user as
	# "requested file format unknown: odin" when they attach a new script — so
	# pin it, and assert the saver advertises "odin" (the extension the dialog
	# validates against before it will even offer to save).
	var fresh = ClassDB.instantiate("OdinScript")
	var fresh_ok := false
	if fresh != null:
		fresh.set("source_code", "//gd:extends Node\n//gd:class Fresh\npackage showcase_scripts\n")
		var fresh_probe := "res://__save_fresh_probe.odin"
		var fresh_os := ProjectSettings.globalize_path(fresh_probe)
		var fresh_err = ResourceSaver.save(fresh, fresh_probe)
		var fresh_exts = ResourceSaver.get_recognized_extensions(fresh)
		fresh_ok = fresh_err == OK and FileAccess.file_exists(fresh_os) and fresh_exts.has("odin")
		if FileAccess.file_exists(fresh_os):
			DirAccess.remove_absolute(fresh_os)
		var fresh_uid := fresh_os + ".uid"
		if FileAccess.file_exists(fresh_uid):
			DirAccess.remove_absolute(fresh_uid)
		if not fresh_ok:
			print("SAVE_TEST_FRESH_DEBUG: err=%d exts=%s" % [fresh_err, fresh_exts])

	# TEMPLATE PACKAGE FIXUP: a fresh template declares `package scripts` (the
	# dialog can't know the destination), and saved NEXT TO siblings declaring
	# another package that's a guaranteed build break — the saver must rewrite
	# the line to match the siblings on the way to disk. (The probe above, at
	# the project root with no siblings, pins the no-op case.)
	var fixup_ok := false
	var fx = ClassDB.instantiate("OdinScript")
	if fx != null:
		fx.set("source_code", "//gd:extends Node
//gd:class FixMe
package scripts
")
		var fx_probe := "res://scripts/__fixup_probe.odin"
		var fx_os := ProjectSettings.globalize_path(fx_probe)
		var fx_err = ResourceSaver.save(fx, fx_probe)
		var fx_text := ""
		if FileAccess.file_exists(fx_os):
			fx_text = FileAccess.get_file_as_string(fx_os)
			DirAccess.remove_absolute(fx_os)
		var fx_uid := fx_os + ".uid"
		if FileAccess.file_exists(fx_uid):
			DirAccess.remove_absolute(fx_uid)
		fixup_ok = fx_err == OK and fx_text.contains("package showcase_scripts") and not fx_text.contains("package scripts
")
		if not fixup_ok:
			print("SAVE_TEST_FIXUP_DEBUG: err=%d text=<%s>" % [fx_err, fx_text])

	# Format on save (core/format.odin): with the setting EXPLICITLY on (the headless
	# override — the default only applies inside the editor) and odinfmt reachable, the
	# BYTES ON DISK must come out formatted. Gated: run.sh sets SAVE_TEST_EXPECT_FMT only
	# when odinfmt is on PATH, so environments without ols still pass.
	var fmt_ok := true
	if OS.get_environment("SAVE_TEST_EXPECT_FMT") == "1":
		ProjectSettings.set_setting("odin_godot/format_on_save", true)
		var ugly = src.duplicate()
		ugly.source_code = "package showcase_scripts\nfmt_probe::proc(){x:=1\n_=x}\n"
		var fmt_probe := "res://__save_fmt_probe.odin"
		var fmt_os := ProjectSettings.globalize_path(fmt_probe)
		var fmt_err = ResourceSaver.save(ugly, fmt_probe)
		var fmt_text := ""
		if FileAccess.file_exists(fmt_os):
			fmt_text = FileAccess.get_file_as_string(fmt_os)
			DirAccess.remove_absolute(fmt_os)
		var fmt_uid := fmt_os + ".uid"
		if FileAccess.file_exists(fmt_uid):
			DirAccess.remove_absolute(fmt_uid)
		# odinfmt normalizes `fmt_probe::proc(){` to spaced form — proof it ran.
		fmt_ok = fmt_err == OK and fmt_text.contains("fmt_probe :: proc()") and fmt_text.contains("x := 1")
		if not fmt_ok:
			print("SAVE_TEST_FMT_DEBUG: err=%d text=<%s>" % [fmt_err, fmt_text])

	var ok = err == OK and on_disk and scene_rejected and fresh_ok and fixup_ok and fmt_ok
	if ok:
		print("SAVE_TEST_OK")
	else:
		print("SAVE_TEST_FAIL: err=%d on_disk=%s scene_err=%d fresh_ok=%s fixup_ok=%s fmt_ok=%s" % [err, on_disk, scene_err, fresh_ok, fixup_ok, fmt_ok])
	quit(0 if ok else 1)
