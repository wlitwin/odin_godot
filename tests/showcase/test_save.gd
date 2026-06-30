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

	var ok = err == OK and on_disk and scene_rejected
	if ok:
		print("SAVE_TEST_OK")
	else:
		print("SAVE_TEST_FAIL: err=%d on_disk=%s scene_err=%d (scene must be rejected)" % [err, on_disk, scene_err])
	quit(0 if ok else 1)
