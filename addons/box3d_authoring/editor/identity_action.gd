@tool
class_name Box3DEditorIdentityAction
extends RefCounted

# UndoRedo retains RefCounted method targets. Actions remain usable after the
# plugin is disabled; no history operation calls back into the plugin itself.
var changes: Array = []
var additions: Array = []
var scene_root: Node

func apply_nodes(backwards: bool) -> void:
	if backwards:
		for entry in additions:
			if is_instance_valid(entry.node) and entry.node.get_parent() != null:
				entry.node.get_parent().remove_child(entry.node)
	else:
		# Insert from the last original sibling toward the first, so original
		# indices remain valid. Undo/redo reuses the same objects and keys.
		for i in range(additions.size() - 1, -1, -1):
			var entry: Dictionary = additions[i]
			entry.parent.add_child(entry.node, true)
			entry.parent.move_child(entry.node, entry.index)
			for relation in entry.owners:
				relation.node.owner = relation.owner

func refresh() -> void:
	for change in changes:
		if change.object is Resource:
			change.object.emit_changed()
		change.object.notify_property_list_changed()
	if is_instance_valid(scene_root):
		_refresh(scene_root)

func _refresh(node: Node) -> void:
	if node is Box3DWorld3D or node is Box3DBody3D or node is Box3DJoint3D or node is Box3DCharacterMover3D:
		node.update_configuration_warnings()
		node.update_gizmos()
	for child in node.get_children():
		_refresh(child)
