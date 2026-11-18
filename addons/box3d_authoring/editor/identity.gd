@tool
class_name Box3DEditorIdentity
extends RefCounted

static func kind(object: Object) -> String:
	if object is Box3DWorld3D: return "world"
	if object is Box3DBody3D: return "body"
	if object is Box3DJoint3D: return "joint"
	if object is Box3DCharacterMover3D: return "character"
	if object is Box3DShape3D: return "shape"
	return ""

static func world_of(node: Node) -> Box3DWorld3D:
	while node != null:
		if node is Box3DWorld3D: return node
		node = node.get_parent()
	return null

static func editable(node: Node, root: Node) -> bool:
	if root == null or not (node == root or root.is_ancestor_of(node)): return false
	if node == root: return true
	var owner := node.owner
	while owner != null and owner != root:
		if not root.is_editable_instance(owner): return false
		owner = owner.owner
	return owner == root

static func _nodes(root: Node, stop_at_worlds := false) -> Array[Node]:
	var result: Array[Node] = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if stop_at_worlds and node != root and node is Box3DWorld3D: continue
		result.append(node)
		if result.size() > 4096: return []
		var children := node.get_children()
		for i in range(children.size() - 1, -1, -1): pending.append(children[i])
	return result

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func _plan(label: String, root: Node, context: Object = null) -> Dictionary:
	return {"ok": true, "label": label, "root": root, "context": root if context == null else context, "changes": [], "additions": []}

static func _change(plan: Dictionary, object: Object, property: StringName, value: Variant) -> void:
	if object.get(property) != value:
		var old: Variant = object.get(property)
		if old is Array: old = old.duplicate()
		plan.changes.append({"object": object, "property": property, "old": old, "new": value})

static func plan_rekey(target: Object, requested: String, root: Node) -> Dictionary:
	var target_kind := kind(target)
	if target_kind.is_empty(): return _fail("Select a Box3D World, body, joint, character, or shape.")
	var errors: Array = []
	Box3DAuthoringData.key(requested, "stable_key", errors)
	if not errors.is_empty(): return _fail(errors[0].message)
	if target is Node and not editable(target, root):
		return _fail("Edit this object's source scene or enable Editable Children on its instance first.")
	var old: String = target.stable_key
	var plan := _plan("Change Box3D ID", root, target if target is Resource else root)
	if requested == old: return plan
	var scope: Array[Node] = []
	if target is Box3DWorld3D or target is Box3DShape3D:
		if root != null: scope = _nodes(root)
	else:
		var world := world_of(target)
		# A reusable body/group scene may be authored before it is placed in
		# a World. Its local references still form a valid editing scope.
		scope = _nodes(world if world != null else root, true)
	if root != null and scope.is_empty(): return _fail("The authoring scene exceeds 4096 nodes.")
	var old_matches := 0
	for node in scope:
		if target is Box3DShape3D:
			if node is Box3DBody3D:
				for shape in node.shapes:
					if shape != null and shape != target and shape.stable_key == requested:
						return _fail("That shape ID is already in use. Share its Resource instead of giving a different Resource the same ID.")
		elif kind(node) == target_kind:
			if node != target and node.stable_key == requested: return _fail("That ID is already in use by another " + target_kind + ".")
			if node.stable_key == old: old_matches += 1
	if target is Box3DBody3D and not old.is_empty() and old_matches != 1:
		return _fail("Multiple bodies have the existing ID, so references are ambiguous. Undo the accidental copy and use Duplicate Box3D selection.")
	_change(plan, target, &"stable_key", requested)
	if target is Box3DBody3D and not old.is_empty():
		for node in scope:
			var fields: Array[StringName] = []
			if node is Box3DJoint3D: fields = [&"body_a", &"body_b"]
			elif node is Box3DCharacterMover3D: fields = [&"exclude_body"]
			for field in fields:
				if node.get(field) == old:
					if not editable(node, root): return _fail("An incoming reference belongs to an uneditable scene instance. Edit its source or enable Editable Children first.")
					_change(plan, node, field, requested)
	return plan

static func plan_duplicate_shape(body: Box3DBody3D, index: int, root: Node) -> Dictionary:
	if not editable(body, root): return _fail("Edit the body's source scene or enable Editable Children first.")
	if index < 0 or index >= body.shapes.size() or body.shapes[index] == null:
		return _fail("Choose an existing shape slot to duplicate.")
	var shape: Box3DShape3D = body.shapes[index].duplicate(false)
	shape.stable_key = Box3DIdentityKey.fresh("shape")
	var shapes: Array[Box3DShape3D] = body.shapes.duplicate()
	shapes.insert(index + 1, shape)
	var plan := _plan("Duplicate Box3D shape", root)
	_change(plan, body, &"shapes", shapes)
	return plan

static func discard(plan: Dictionary) -> void:
	for entry in plan.get("additions", []):
		if is_instance_valid(entry.node) and entry.node.get_parent() == null: entry.node.free()
	plan["additions"] = []

static func _duplicate_failure(plan: Dictionary, message: String) -> Dictionary:
	discard(plan)
	return _fail(message)

static func plan_duplicate(selected: Array[Node], root: Node) -> Dictionary:
	if root == null or selected.is_empty(): return _fail("Select the Box3D objects or groups to duplicate in the Scene tree.")
	var roots: Array[Node] = []
	for node in selected:
		if node == root: return _fail("The scene root cannot be duplicated. Instance this scene beneath a parent scene to duplicate the whole World.")
		if not editable(node, root): return _fail("Edit the selected object's source scene or enable Editable Children first.")
		var covered := false
		for other in selected:
			if other != node and other.is_ancestor_of(node): covered = true; break
		if not covered and not roots.has(node): roots.append(node)
	roots.sort_custom(func(a: Node, b: Node): return a.is_greater_than(b) == false)
	var plan := _plan("Duplicate Box3D selection", root)
	var pairs: Dictionary = {}
	var namespaces: Dictionary = {}
	var world_indexes: Dictionary = {}
	var body_keys: Dictionary = {}
	var local_shapes: Dictionary = {}
	var all_nodes := _nodes(root)
	if all_nodes.is_empty(): return _fail("The authoring scene exceeds 4096 nodes.")
	for node in all_nodes:
		if node is Box3DWorld3D: namespaces[node.stable_key] = true
	for source in roots:
		var clone: Node = source.duplicate()
		if clone == null: return _duplicate_failure(plan, "Godot could not duplicate the selected subtree.")
		var entry := {"node": clone, "parent": source.get_parent(), "index": source.get_index() + 1, "owners": []}
		plan.additions.append(entry)
		var originals := _nodes(source)
		for original in originals:
			var copy: Node = clone if original == source else clone.get_node_or_null(source.get_path_to(original))
			if copy == null: return _duplicate_failure(plan, "The duplicated subtree does not match its source.")
			pairs[original] = copy
		clone.name = String(source.name) + "Copy"
	var found := false
	for original in pairs:
		var copy: Node = pairs[original]
		var object_kind := kind(original)
		if object_kind.is_empty(): continue
		found = true
		if original.owner == null:
			return _duplicate_failure(plan, "An authoring child has no scene owner and would disappear on save. Make it part of the edited scene before duplicating.")
		if original is Box3DWorld3D:
			copy.stable_key = _fresh_unused("world", namespaces)
			continue
		var world := world_of(original)
		if world == null: return _duplicate_failure(plan, "Every duplicated body, joint and character must belong to a World.")
		if original is Box3DBody3D:
			# Preserve shared Resources. Local-to-scene Resources instead keep
			# a private copy, shared consistently within the cloned World graph.
			if not local_shapes.has(world): local_shapes[world] = {}
			var copies: Dictionary = local_shapes[world]
			var shapes: Array[Box3DShape3D] = []
			for i in range(original.shapes.size()):
				var shape: Box3DShape3D = original.shapes[i]
				if shape == null or not shape.resource_local_to_scene:
					shapes.append(shape)
					continue
				if not copies.has(shape):
					var private_shape: Box3DShape3D = copy.shapes[i]
					if private_shape == shape: private_shape = shape.duplicate(false)
					if not pairs.has(world): private_shape.stable_key = Box3DIdentityKey.fresh("shape")
					copies[shape] = private_shape
				shapes.append(copies[shape])
			copy.shapes = shapes
		if pairs.has(world): continue # a new namespace preserves the local graph
		if not editable(original, root): return _duplicate_failure(plan, "The selection contains authoring children whose ID overrides cannot be saved. Enable Editable Children or duplicate their whole World.")
		if not world_indexes.has(world):
			var index := _index_world(world)
			if not index.ok: return _duplicate_failure(plan, index.error)
			world_indexes[world] = index.keys
			body_keys[world] = {}
		var keys: Dictionary = world_indexes[world][object_kind]
		copy.stable_key = _fresh_unused(object_kind, keys)
		if original is Box3DBody3D: body_keys[world][original.stable_key] = copy.stable_key
	if not found: return _duplicate_failure(plan, "The selection contains no Box3D authoring objects.")
	for original in pairs:
		var copy: Node = pairs[original]
		var world := world_of(original)
		if not pairs.has(world) and body_keys.has(world):
			var remap: Dictionary = body_keys[world]
			if original is Box3DJoint3D:
				copy.body_a = remap.get(original.body_a, original.body_a)
				copy.body_b = remap.get(original.body_b, original.body_b)
			elif original is Box3DCharacterMover3D:
				copy.exclude_body = remap.get(original.exclude_body, original.exclude_body)
	for entry in plan.additions:
		for original in pairs:
			var copy: Node = pairs[original]
			if copy != entry.node and not entry.node.is_ancestor_of(copy): continue
			var owner: Node = pairs.get(original.owner, root) if original.owner != null else null
			if copy == entry.node: owner = root
			if owner != null: entry.owners.append({"node": copy, "owner": owner})
	return plan

static func _fresh_unused(prefix: String, used: Dictionary) -> String:
	var value := Box3DIdentityKey.fresh(prefix)
	while used.has(value): value = Box3DIdentityKey.fresh(prefix)
	used[value] = true
	return value

static func _index_world(world: Box3DWorld3D) -> Dictionary:
	var keys := {"body": {}, "joint": {}, "character": {}}
	var nodes := _nodes(world, true)
	if nodes.is_empty(): return _fail("The World exceeds 4096 nodes.")
	for node in nodes:
		var object_kind := kind(node)
		if not keys.has(object_kind): continue
		var key: String = node.stable_key
		if key.is_empty() or keys[object_kind].has(key):
			return _fail("Give each " + object_kind + " in this World a nonempty, unique ID before duplicating connected objects.")
		keys[object_kind][key] = true
	return {"ok": true, "keys": keys}

static func apply_plan(plan: Dictionary, history: EditorUndoRedoManager) -> Dictionary:
	if not plan.get("ok", false): return plan
	for change in plan.changes:
		if not is_instance_valid(change.object) or change.object.get(change.property) != change.old:
			discard(plan)
			return _fail("The object changed while this operation was being prepared. Try again.")
	if plan.changes.is_empty() and plan.additions.is_empty(): return {"ok": true, "changed": false}
	var action := Box3DEditorIdentityAction.new()
	action.changes = plan.changes
	action.additions = plan.additions
	action.scene_root = plan.root
	history.create_action(plan.label, UndoRedo.MERGE_DISABLE, plan.context)
	history.add_do_method(action, "apply_nodes", false)
	history.add_undo_method(action, "apply_nodes", true)
	# Native property operations mark external Resources edited, so normal
	# editor saves persist their IDs as well as the scene's graph changes.
	for change in plan.changes:
		history.add_do_property(change.object, change.property, change.new)
		history.add_undo_property(change.object, change.property, change.old)
	history.add_do_method(action, "refresh")
	history.add_undo_method(action, "refresh")
	for entry in plan.additions: history.add_do_reference(entry.node)
	history.commit_action()
	return {"ok": true, "changed": true, "nodes": plan.additions.map(func(entry): return entry.node)}
