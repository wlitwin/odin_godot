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

	if err == OK and on_disk:
		print("SAVE_TEST_OK")
	else:
		print("SAVE_TEST_FAIL: err=%d on_disk=%s" % [err, on_disk])
	quit(0 if (err == OK and on_disk) else 1)
