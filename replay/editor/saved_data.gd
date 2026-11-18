@tool
extends RefCounted

# Use the editor's authoritative edited flags, not a second serialized model.
# Weak references cover unnamed Inspector drafts without retaining them forever.
var observed: Dictionary = {}

func observe(object: Object) -> void:
	if object is Resource:
		observed[object.get_instance_id()] = weakref(object)

func _issue(plan: Dictionary, source: String, message: String, object: Object = null) -> void:
	var issue := {"source": source, "path": "$save", "message": message}
	if object != null:
		issue["object_id"] = object.get_instance_id()
	plan.issues.append(issue)

func _files(directory: EditorFileSystemDirectory, plan: Dictionary) -> void:
	if directory == null:
		return
	for index in directory.get_file_count():
		var path := directory.get_file_path(index)
		var resource := ResourceLoader.get_cached_ref(path)
		if resource != null:
			_walk_resource(resource, "", plan, [])
	for index in directory.get_subdir_count():
		_files(directory.get_subdir(index), plan)

func _walk_value(value: Variant, owner_path: String, plan: Dictionary, containers: Array, parent_id: int) -> void:
	if value is Resource:
		plan.edges[parent_id][value.get_instance_id()] = value
		_walk_resource(value, owner_path, plan, containers)
	elif value is Array or value is Dictionary:
		for seen in containers:
			if is_same(seen, value):
				return
		containers.append(value)
		if value is Array:
			for item in value:
				_walk_value(item, owner_path, plan, containers, parent_id)
		else:
			for key in value:
				_walk_value(key, owner_path, plan, containers, parent_id)
				_walk_value(value[key], owner_path, plan, containers, parent_id)
		containers.pop_back()

func _walk_properties(object: Object, owner_path: String, plan: Dictionary, containers: Array) -> void:
	var id := object.get_instance_id()
	if not plan.edges.has(id):plan.edges[id] = {}
	for property in object.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE == 0:
			continue
		if int(property.type) in [TYPE_OBJECT, TYPE_ARRAY, TYPE_DICTIONARY]:
			_walk_value(object.get(property.name), owner_path, plan, containers, id)

func _walk_resource(resource: Resource, inherited_path: String, plan: Dictionary, containers: Array) -> void:
	var path := resource.resource_path
	var owner_path := inherited_path
	if not path.is_empty() and not "::" in path:
		owner_path = path
		plan.roots[path] = resource
	elif "::" in path:
		var original_owner := path.get_slice("::", 0)
		if owner_path.is_empty():
			owner_path = original_owner
		elif owner_path != original_owner:
			_walk_resource(resource, original_owner, plan, [])
	var id := resource.get_instance_id()
	var visit := str(id) + "@" + owner_path
	if plan.visited.has(visit):
		return
	plan.visited[visit] = true
	if not plan.entries.has(id):
		plan.entries[id] = {"resource": resource, "owners": {}}
	plan.entries[id].owners[owner_path] = true
	observe(resource)
	_walk_properties(resource, owner_path, plan, containers)

func _walk_scene(node: Node, path: String, plan: Dictionary, root: bool = true) -> void:
	# Tool-created preview children are not authored scene inputs. An inspected
	# draft is still discovered separately, and external Resources via the cache.
	if not root and node.owner == null:return
	_walk_properties(node, path, plan, [])
	for child in node.get_children():
		_walk_scene(child, path, plan, false)

func _scene_contents(plan: Dictionary, path: String) -> PackedScene:
	if not plan.packed.has(path):
		# Let Godot decide ownership, inherited nodes and property overrides. A
		# reachable live Node is not proof that its Resources will be serialized.
		var packed := PackedScene.new()
		var error := packed.pack(plan.scene_roots[path])
		if error != OK:
			_issue(plan, path, "Could not pack scene for saving: " + error_string(error))
			plan.packed[path] = null
		else:
			plan.packed[path] = packed
			_walk_resource(packed, path, plan, [])
	return plan.packed[path]

func _contains(plan: Dictionary, owner: Object, resource: Resource) -> bool:
	# A scene can retain older SceneStates with identical subresource paths.
	# Only clear an edit if this exact object is embedded in what we will save.
	var pending: Array[Object] = [owner]
	var seen: Dictionary = {}
	while not pending.is_empty():
		var current: Object = pending.pop_back()
		if current == resource:return true
		var id := current.get_instance_id()
		if seen.has(id):continue
		seen[id] = true
		for child: Resource in plan.edges.get(id, {}).values():
			if child.resource_path.is_empty() or "::" in child.resource_path:
				pending.append(child)
	return false

func _resolve_owners(editor: EditorInterface, plan: Dictionary) -> void:
	# Godot may release a closed PackedScene while its embedded Resources remain
	# alive in Inspector/preview caches. REUSE recovers the owner while retaining
	# those exact edited objects; REPLACE would discard edits. _contains below
	# verifies the recovered owner actually embeds the object before saving it.
	var tried: Dictionary = {}
	while true:
		var paths: Dictionary = {}
		for entry in plan.entries.values():
			if not editor.is_object_edited(entry.resource):continue
			for path: String in entry.owners:
				if path.begins_with("res://") and not plan.roots.has(path) and not tried.has(path) and not path in editor.get_open_scenes():
					paths[path] = true
		if paths.is_empty():return
		for path: String in paths:
			tried[path] = true
			if not FileAccess.file_exists(path) or FileAccess.file_exists(path + ".import"):continue
			var owner := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
			if owner != null:_walk_resource(owner, "", plan, [])

func collect(editor: EditorInterface, resolve_owners: bool = false) -> Dictionary:
	var plan := {"roots": {}, "entries": {}, "visited": {}, "edges": {}, "resources": {}, "scenes": {}, "scene_roots": {}, "packed": {},
		"dirty": [], "issues": [], "scripts": editor.get_script_editor().get_unsaved_files()}
	_files(editor.get_resource_filesystem().get_filesystem(), plan)
	for root in editor.get_open_scene_roots():
		plan.scene_roots[root.scene_file_path] = root
		_walk_scene(root, root.scene_file_path, plan)
	observe(editor.get_inspector().get_edited_object())
	for id in observed.keys():
		var resource: Resource = observed[id].get_ref()
		if resource == null:
			observed.erase(id)
		else:
			_walk_resource(resource, "", plan, [])
	if resolve_owners:_resolve_owners(editor, plan)
	for path in editor.get_unsaved_scenes():
		if path.is_empty():
			_issue(plan, "", "An open scene has no file path. Save the scene before running this action.", editor.get_edited_scene_root())
		else:
			plan.scenes[path] = true
	for path: String in plan.scripts:
		if "::" in path and not path.get_slice("::", 0) in editor.get_open_scenes():
			_issue(plan, path.get_slice("::", 0), "Open the scene that owns this script buffer before saving it.")
	for entry in plan.entries.values():
		var resource: Resource = entry.resource
		if not editor.is_object_edited(resource):
			continue
		plan.dirty.append(entry)
		if not resolve_owners:continue # status needs flags, not save/packing work
		var owners: Dictionary = entry.owners.duplicate()
		if owners.size() > 1:
			owners.erase("")
		# Reachability proposes owners; only exact serialized containment proves
		# one. An instance's parent scene may reference its external PackedScene
		# without embedding any of that scene's inherited subresources itself.
		entry["save_owners"] = {}
		var candidates := {"issues": []}
		var previous_issues: int = plan.issues.size()
		for path: String in owners:
			if path.is_empty():
				_issue(candidates, "", "An edited Resource has no saved owner. Save it as a project Resource or assign it to a saved scene/Resource.", resource)
			elif path in editor.get_open_scenes():
				var packed := _scene_contents(plan, path)
				if packed == null:continue
				if _contains(plan, packed, resource):
					entry.save_owners[path] = true
					plan.scenes[path] = true
				else:
					_issue(candidates, path, "This edited Resource is no longer embedded in the open scene. Assign it to a current scene/Resource or save a separate copy.", resource)
			else:
				var owner: Resource = plan.roots.get(path, ResourceLoader.get_cached_ref(path))
				if owner == null:
					_issue(candidates, path, "Open and save the file that owns this edited subresource before running the action.", resource)
				elif not _contains(plan, owner, resource):
					_issue(candidates, path, "This edited Resource is no longer embedded in its saved owner. Assign it to a current scene/Resource or save a separate copy.", resource)
				else:
					entry.save_owners[path] = true
					if not path.begins_with("res://"):
						_issue(plan, path, "Save a project-local copy of this edited Resource before baking project content.", resource)
					elif FileAccess.file_exists(path + ".import"):
						_issue(plan, path, "Imported data cannot be saved back over its source. Save an editable Resource copy first.", resource)
					else:
						plan.resources[path] = owner
		if entry.save_owners.is_empty() and plan.issues.size() == previous_issues:
			plan.issues.append_array(candidates.issues)
	return plan

func has_pending(editor: EditorInterface) -> bool:
	var plan := collect(editor)
	return not plan.dirty.is_empty() or not plan.scenes.is_empty() or not plan.scripts.is_empty() or not plan.issues.is_empty()

func _restore_dirty(editor: EditorInterface, plan: Dictionary) -> void:
	for entry in plan.dirty:
		editor.set_object_edited(entry.resource, true)
	for resource: Resource in plan.resources.values():
		editor.set_object_edited(resource, true)

func _clear_saved(editor: EditorInterface, plan: Dictionary, saved: Dictionary) -> void:
	for entry in plan.dirty:
		var owners: Dictionary = entry.save_owners
		var complete := not owners.is_empty()
		for path in owners:
			complete = complete and saved.has(path)
		if complete:
			editor.set_object_edited(entry.resource, false)

func save(editor: EditorInterface) -> Dictionary:
	var plan := collect(editor, true)
	var report := {"ok": false, "running": false, "kind": "save", "saved": [], "issues": plan.issues,
		"message": "Action not started: save the listed inputs first."}
	if not plan.issues.is_empty():
		return report
	var saved: Dictionary = {}
	# Save external data first: Godot scene saving can clear edited flags on
	# external Resources even if a subsequent resource write fails.
	for path: String in plan.resources:
		var resource: Resource = plan.resources[path]
		if resource is Script:
			continue # apply the Script editor's live buffers before saving these
		var error := ResourceSaver.save(resource, path, ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS)
		if error != OK:
			_issue(plan, path, "Could not save Resource: " + error_string(error), resource)
			_restore_dirty(editor, plan)
			return report
		saved[path] = true
		report.saved.append(path)
	_clear_saved(editor, plan, saved)
	# A Resource edit can lack a scene UndoRedo action. Mark every owning scene's
	# native history dirty so a failed write cannot disappear when Godot clears
	# Resource flags. Neither scene_saved nor save_scene's return value reports a
	# successful write; only successful saves clear the scene history.
	var original_scene := editor.get_edited_scene_root()
	for path: String in plan.scenes:
		editor.open_scene_from_path(path)
		var scene := editor.get_edited_scene_root()
		if scene == null or scene.scene_file_path != path:
			_issue(plan, path, "Could not select the open scene for saving.")
		else:
			editor.mark_scene_as_unsaved()
	if original_scene != null:
		editor.open_scene_from_path(original_scene.scene_file_path)
	if not plan.issues.is_empty():
		_restore_dirty(editor, plan)
		return report
	var scripts := editor.get_script_editor()
	scripts.save_all_scripts()
	for path: String in plan.resources:
		var resource: Resource = plan.resources[path]
		if not resource is Script:
			continue
		var error := ResourceSaver.save(resource, path)
		if error != OK:
			_issue(plan, path, "Could not save script: " + error_string(error), resource)
		else:
			saved[path] = true
			report.saved.append(path)
	for path: String in plan.scripts:
		if "::" in path:
			continue # the owning scene is saved by save_all_scripts/save_all_scenes
		var script := ResourceLoader.get_cached_ref(path) as Script
		if script != null and script.has_source_code() and FileAccess.get_file_as_string(path) != script.source_code:
			_issue(plan, path, "The script buffer was not saved to disk. Save it before running the action.", script)
	for path in scripts.get_unsaved_files():
		_issue(plan, path, "This script still has unsaved changes.")
	if not plan.issues.is_empty():
		_restore_dirty(editor, plan)
		return report
	editor.save_all_scenes()
	for path in editor.get_unsaved_scenes():
		_issue(plan, path, "Scene saving did not complete. Save the scene before running the action.")
	if not plan.issues.is_empty():
		_restore_dirty(editor, plan)
		return report
	for path in plan.scenes:
		saved[path] = true
		report.saved.append(path)
	_clear_saved(editor, plan, saved)
	var remaining := collect(editor)
	if not remaining.dirty.is_empty() or not remaining.scenes.is_empty() or not remaining.scripts.is_empty() or not remaining.issues.is_empty():
		plan.issues.append_array(remaining.issues)
		if remaining.issues.is_empty():
			_issue(plan, "", "Edits remain unsaved after the save operation. Save them and rerun the action.")
		return report
	report.ok = true
	report.message = "Editor inputs saved."
	return report
