@tool
class_name Box3DAuthoringGizmoPlugin
extends EditorNode3DGizmoPlugin

var services: Box3DEditorServices
var controller: EditorPlugin
var redraw_count := 0
var last_status: Dictionary = {}
var _frame := -1
var _contexts: Dictionary = {}

func _init(value: Box3DEditorServices = null, owner: EditorPlugin = null) -> void:
	services = value
	controller = owner
	create_handle_material("box3d_anchor_handles")
func _get_gizmo_name() -> String: return "Box3D authoring"
func _has_gizmo(node: Node3D) -> bool: return node is Box3DWorld3D or node is Box3DBody3D or node is Box3DJoint3D or node is Box3DCharacterMover3D
func _get_priority() -> int: return 1
func world_of(node: Node) -> Box3DWorld3D: return Box3DEditorPreview.world_of(node)

func invalidate() -> void:
	_contexts.clear()
	_frame = -1

# Direct callers get current state, including several edits in the same frame.
func geometry_for(node: Node3D, max_lines := Box3DAuthoringData.MAX_LINES) -> Dictionary:
	var world := world_of(node)
	if world == null: return {"ok": false, "error": "MissingWorld"}
	return Box3DEditorPreview.geometry(Box3DEditorPreview.context_for(world, services), node, services, clampi(max_lines, 0, Box3DAuthoringData.MAX_LINES))

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	redraw_count += 1
	var node := gizmo.get_node_3d()
	var world := world_of(node)
	if world == null:
		last_status = {"ok": false, "error": "MissingWorld"}
		return
	var frame := Engine.get_process_frames()
	if frame != _frame:
		_contexts.clear()
		_frame = frame
	var key := world.get_instance_id()
	if not _contexts.has(key): _contexts[key] = Box3DEditorPreview.context_for(world, services)
	last_status = Box3DEditorPreview.geometry(_contexts[key], node, services, Box3DAuthoringData.MAX_LINES)
	if not last_status.get("ok", false) or last_status.points.is_empty(): return
	var points: PackedVector3Array = last_status.points
	var colors: PackedColorArray = last_status.colors
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(points.size()):
		mesh.surface_set_color(colors[i >> 1])
		mesh.surface_add_vertex(points[i])
	mesh.surface_end()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	gizmo.add_mesh(mesh, material)
	gizmo.add_collision_segments(points)
	if node is Box3DJoint3D and is_instance_valid(controller):
		var root := controller.get_editor_interface().get_edited_scene_root()
		if not Box3DEditorIdentity.editable(node, root): return
		var anchors := Box3DEditorJoints.handle_positions(node, root)
		if anchors.is_empty(): return
		var handles := PackedVector3Array([anchors.b])
		var ids := PackedInt32Array([1])
		if node.frame_mode == Box3DJoint3D.FrameMode.BODY_LOCAL:
			handles.insert(0, anchors.a); ids.insert(0, 0)
		gizmo.add_handles(handles, get_material("box3d_anchor_handles", gizmo), ids)

func _get_handle_name(_gizmo: EditorNode3DGizmo, id: int, _secondary: bool) -> String:
	return "Anchor A" if id == 0 else "Anchor B"

func _get_handle_value(gizmo: EditorNode3DGizmo, id: int, _secondary: bool) -> Variant:
	var joint := gizmo.get_node_3d() as Box3DJoint3D
	if joint == null: return null
	var property := Box3DEditorJoints.handle_property(joint, id)
	if property.is_empty(): return null
	return {"mode": joint.frame_mode, "property": property, "value": joint.get(property)}

func _set_handle(gizmo: EditorNode3DGizmo, id: int, _secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var joint := gizmo.get_node_3d() as Box3DJoint3D
	if joint == null or not is_instance_valid(controller): return
	var root := controller.get_editor_interface().get_edited_scene_root()
	if not Box3DEditorIdentity.editable(joint, root): return
	var change := Box3DEditorJoints.drag_value(joint, id, camera, screen_pos, root)
	if change.is_empty(): return
	joint.set(change.property, change.value)
	_refresh_anchor(joint)

func _refresh_anchor(joint: Box3DJoint3D) -> void:
	invalidate()
	joint.update_gizmos()
	var world := world_of(joint)
	if world != null: world.update_gizmos()

func _commit_handle(gizmo: EditorNode3DGizmo, _id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var joint := gizmo.get_node_3d() as Box3DJoint3D
	if joint == null or not restore is Dictionary or not is_instance_valid(controller): return
	if joint.frame_mode != restore.mode: return
	if cancel:
		joint.set(restore.property, restore.value)
	else:
		var value: Transform3D = joint.get(restore.property)
		if value == restore.value: return
		var history := controller.get_undo_redo()
		history.create_action("Move Box3D joint anchor", UndoRedo.MERGE_DISABLE, joint)
		history.add_do_property(joint, restore.property, value)
		history.add_undo_property(joint, restore.property, restore.value)
		history.add_do_method(joint, "notify_property_list_changed")
		history.add_undo_method(joint, "notify_property_list_changed")
		history.commit_action(false)
	_refresh_anchor(joint)
