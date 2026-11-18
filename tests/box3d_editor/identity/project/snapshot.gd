extends RefCounted

static func read(root: Node) -> Dictionary:
	var result: Dictionary = {}
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		var kind := Box3DEditorIdentity.kind(node)
		if not kind.is_empty():
			var value := {"kind": kind, "key": node.stable_key}
			if node is Box3DBody3D:
				value["shapes"] = node.shapes.map(func(shape): return {"key": shape.stable_key, "friction": shape.friction, "local": shape.resource_local_to_scene})
			if node is Box3DJoint3D:
				value["a"] = node.body_a
				value["b"] = node.body_b
			if node is Box3DCharacterMover3D: value["exclude"] = node.exclude_body
			result[String(root.get_path_to(node))] = value
		for child in node.get_children(): pending.append(child)
	return result
