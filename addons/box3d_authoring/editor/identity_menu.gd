@tool
class_name Box3DIdentityContextMenu
extends EditorContextMenuPlugin

var controller: EditorPlugin

func _init(owner: EditorPlugin = null) -> void:
	controller = owner

func _popup_menu(paths: PackedStringArray) -> void:
	for path in paths:
		var node := controller.get_node_or_null(NodePath(path))
		if node == null: continue
		for child in Box3DEditorIdentity._nodes(node):
			if not Box3DEditorIdentity.kind(child).is_empty():
				add_context_menu_item("Duplicate Box3D selection", _duplicate)
				return

func _duplicate(nodes: Array) -> void:
	if not is_instance_valid(controller): return
	var selected: Array[Node] = []
	selected.assign(nodes)
	var result: Dictionary = controller.duplicate_nodes(selected)
	if not result.get("ok", false): push_warning(String(result.error))
