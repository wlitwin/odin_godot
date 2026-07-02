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

	var ok = err == OK and on_disk and scene_rejected and fmt_ok
	if ok:
		print("SAVE_TEST_OK")
	else:
		print("SAVE_TEST_FAIL: err=%d on_disk=%s scene_err=%d fmt_ok=%s" % [err, on_disk, scene_err, fmt_ok])
	quit(0 if ok else 1)
