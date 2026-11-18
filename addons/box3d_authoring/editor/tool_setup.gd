@tool
class_name Box3DToolSetup
extends RefCounted

const SOURCE := "res://addons/box3d_authoring/tool_module"
const DESTINATION := "res://modules/box3d_authoring_tools"
const RECEIPT := ".box3d-tools.json"

static func _hashes(directory: String) -> Dictionary:
	var result: Dictionary = {}
	if not DirAccess.dir_exists_absolute(directory): return result
	var folder := DirAccess.open(directory)
	if folder == null: return result
	folder.include_hidden = true
	for name in folder.get_files():
		if name.ends_with(".odin") and not name.ends_with(".gen.odin"):
			result[name] = FileAccess.get_sha256(directory.path_join(name))
	return result

static func inspect(source: String = SOURCE, destination: String = DESTINATION) -> Dictionary:
	var wanted := _hashes(source)
	if wanted.is_empty(): return {"state": "missing_package", "message": "Box3D tool sources are missing. Reinstall the Box3D addon from the SDK.", "conflicts": []}
	var current := _hashes(destination)
	var previous: Dictionary = {}
	var receipt_path := destination.path_join(RECEIPT)
	if FileAccess.file_exists(receipt_path):
		var parser := JSON.new()
		var parsed := parser.parse(FileAccess.get_file_as_string(receipt_path))
		var receipt: Variant = parser.data
		if parsed != OK or not receipt is Dictionary or receipt.get("version") != 1 or not receipt.get("files") is Dictionary:
			return {"state": "conflict", "message": "The tool installation record is invalid. Review the module before updating.", "conflicts": [receipt_path]}
		previous = receipt.files
		for name in previous:
			if not name is String or name.get_file() != name or not name.ends_with(".odin") or not previous[name] is String:
				return {"state": "conflict", "message": "The tool installation record is invalid. Review the module before updating.", "conflicts": [receipt_path]}
	var conflicts: Array[String] = []
	for name in current:
		if current[name] != wanted.get(name, "") and current[name] != previous.get(name, ""):
			conflicts.append(destination.path_join(name))
	for name in previous:
		if not current.has(name): conflicts.append(destination.path_join(name) + " (deleted locally)")
	if not conflicts.is_empty():
		return {"state": "conflict", "message": "Tool sources have local changes. Merge them with the packaged sources before updating; your files are preserved.", "conflicts": conflicts}
	var state := "current" if current == wanted else ("install" if current.is_empty() else "update")
	return {"state": state, "message": "", "conflicts": [], "wanted": wanted, "current": current, "previous": previous, "tracked": FileAccess.file_exists(receipt_path)}

static func _copy_tree(source: String, destination: String) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(destination)
	if error != OK: return error
	if not DirAccess.dir_exists_absolute(source): return OK
	var folder := DirAccess.open(source)
	if folder == null: return ERR_CANT_OPEN
	folder.include_hidden = true
	for name in folder.get_files():
		if folder.is_link(name): return ERR_UNAVAILABLE
		error = DirAccess.copy_absolute(source.path_join(name), destination.path_join(name))
		if error != OK: return error
	for name in folder.get_directories():
		if folder.is_link(name): return ERR_UNAVAILABLE
		error = _copy_tree(source.path_join(name), destination.path_join(name))
		if error != OK: return error
	return OK

static func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	var folder := DirAccess.open(path)
	if folder == null: return
	folder.include_hidden = true
	for name in folder.get_files(): DirAccess.remove_absolute(path.path_join(name))
	for name in folder.get_directories():
		if folder.is_link(name): DirAccess.remove_absolute(path.path_join(name))
		else: _remove_tree(path.path_join(name))
	DirAccess.remove_absolute(path)

static func apply(source: String = SOURCE, destination: String = DESTINATION) -> Dictionary:
	var plan := inspect(source, destination)
	if plan.state in ["conflict", "missing_package"]: return {"ok": false, "error": plan.message, "conflicts": plan.conflicts}
	if plan.state == "current" and plan.tracked and plan.previous == plan.wanted: return {"ok": true, "changed": false}
	# Stage the whole module, preserving generated and auxiliary files. The
	# original is moved aside until the replacement is installed successfully.
	var temporary := "res://.godot/box3d-setup-" + str(Time.get_ticks_usec())
	var stage := temporary.path_join("module")
	var backup := temporary.path_join("original")
	var error := _copy_tree(destination, stage)
	if error == OK:
		for name in plan.previous:
			if not plan.wanted.has(name):
				error = DirAccess.remove_absolute(stage.path_join(name))
				if error != OK: break
	if error == OK:
		for name in plan.wanted:
			error = DirAccess.copy_absolute(source.path_join(name), stage.path_join(name))
			if error != OK: break
	if error == OK:
		var file := FileAccess.open(stage.path_join(RECEIPT), FileAccess.WRITE)
		if file == null: error = FileAccess.get_open_error()
		else:
			file.store_string(JSON.stringify({"version": 1, "files": plan.wanted}, "  ") + "\n")
			file.flush()
			error = file.get_error()
			file.close()
	if error == OK and (_hashes(source) != plan.wanted or _hashes(destination) != plan.current): error = ERR_BUSY
	if error == OK: error = DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	var had_original := DirAccess.dir_exists_absolute(destination)
	if error == OK and had_original: error = DirAccess.rename_absolute(destination, backup)
	if error == OK:
		error = DirAccess.rename_absolute(stage, destination)
		if error != OK and had_original:
			var restored := DirAccess.rename_absolute(backup, destination)
			if restored != OK:
				return {"ok": false, "error": "Installation failed; restore the preserved original from " + backup}
	_remove_tree(temporary)
	if error != OK: return {"ok": false, "error": "Cannot install tool sources (" + error_string(error) + "). Existing files were preserved."}
	return {"ok": true, "changed": plan.current != plan.wanted}
