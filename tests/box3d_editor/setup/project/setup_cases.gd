extends RefCounted

static func write(path: String, value: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()
static func run() -> String:
	var source := "res://.godot/setup-cases/source"
	var destination := "res://.godot/setup-cases/installed"
	write(source.path_join("tools.odin"), "first")
	write(source.path_join(".gdignore"), "")
	if Box3DToolSetup.inspect(source, destination).state != "install": return "fresh install status"
	if not Box3DToolSetup.apply(source, destination).get("ok", false): return "fresh install"
	if FileAccess.file_exists(destination.path_join(".gdignore")): return "installed module hidden"
	if Box3DToolSetup.apply(source, destination).get("changed", true): return "idempotence"
	write(destination.path_join(".notes"), "preserve hidden")
	write(destination.path_join("user.txt"), "preserve user")
	write(destination.path_join("generated.gen.odin"), "preserve generated")
	write(source.path_join("tools.odin"), "second")
	write(source.path_join("helper.odin"), "helper")
	if Box3DToolSetup.inspect(source, destination).state != "update": return "clean update status"
	if not Box3DToolSetup.apply(source, destination).get("ok", false): return "clean update"
	for entry in [[".notes", "preserve hidden"], ["user.txt", "preserve user"], ["generated.gen.odin", "preserve generated"]]:
		if FileAccess.get_file_as_string(destination.path_join(entry[0])) != entry[1]: return "preserved " + entry[0]
	DirAccess.remove_absolute(source.path_join("helper.odin"))
	if not Box3DToolSetup.apply(source, destination).get("ok", false) or FileAccess.file_exists(destination.path_join("helper.odin")): return "upstream deletion"
	write(destination.path_join("tools.odin"), "local change")
	write(source.path_join("tools.odin"), "third")
	if Box3DToolSetup.inspect(source, destination).state != "conflict": return "local edit status"
	if Box3DToolSetup.apply(source, destination).get("ok", true) or FileAccess.get_file_as_string(destination.path_join("tools.odin")) != "local change": return "local edit protection"
	write(destination.path_join("tools.odin"), "third")
	if not Box3DToolSetup.apply(source, destination).get("ok", false): return "explicit merge adoption"
	write(source.path_join("tools.odin"), "fourth")
	if Box3DToolSetup.inspect(source, destination).state != "update": return "merged version baseline not adopted"
	if not Box3DToolSetup.apply(source, destination).get("ok", false): return "update after manual merge"
	write(source.path_join("tools.odin"), "third")
	if not Box3DToolSetup.apply(source, destination).get("ok", false): return "clean source downgrade"
	DirAccess.remove_absolute(destination.path_join("tools.odin"))
	if Box3DToolSetup.inspect(source, destination).state != "conflict": return "local deletion protection"
	write(destination.path_join("tools.odin"), "third")
	write(destination.path_join(Box3DToolSetup.RECEIPT), "invalid")
	if Box3DToolSetup.apply(source, destination).get("ok", true): return "invalid receipt protection"
	DirAccess.remove_absolute(destination.path_join(Box3DToolSetup.RECEIPT))
	if not Box3DToolSetup.apply(source, destination).get("ok", false): return "identical untracked adoption"
	DirAccess.remove_absolute(destination.path_join(Box3DToolSetup.RECEIPT))
	write(destination.path_join("tools.odin"), "unknown old version")
	if Box3DToolSetup.apply(source, destination).get("ok", true): return "unknown version protection"
	print("BOX3D_SETUP_SOURCE_CASES_OK")
	return ""
