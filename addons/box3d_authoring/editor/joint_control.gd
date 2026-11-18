@tool
class_name Box3DJointControl
extends VBoxContainer

var controller: EditorPlugin
var target: WeakRef
var modes := OptionButton.new()
var message := Label.new()

func _init(owner: EditorPlugin = null, joint: Box3DJoint3D = null) -> void:
	controller = owner
	target = weakref(joint)
	modes.add_item("Viewport anchors", Box3DJoint3D.FrameMode.VIEWPORT)
	modes.add_item("Body-local frames (advanced)", Box3DJoint3D.FrameMode.BODY_LOCAL)
	if joint.frame_mode in [0, 1]: modes.select(joint.frame_mode)
	else:
		modes.add_item("Unknown anchor mode")
		modes.set_item_disabled(2, true)
		modes.select(2)
	modes.disabled = not Box3DEditorIdentity.editable(joint, owner.get_editor_interface().get_edited_scene_root())
	add_child(modes)
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = "Move or rotate this node for anchor A. Drag the B handle for a separate endpoint; Anchor B Offset also preserves its relative orientation." if joint.frame_mode == Box3DJoint3D.FrameMode.VIEWPORT else "A/B handles and local frame fields edit body-local anchors. The node transform is an editor marker in this mode."
	add_child(help)
	if joint.frame_mode == Box3DJoint3D.FrameMode.VIEWPORT:
		var origins := Button.new()
		origins.text = "Place anchors at body origins"
		origins.tooltip_text = "Place A and B at their body origins. Distance/rest-length settings are left as authored."
		add_child(origins)
		origins.pressed.connect(func():
			var current: Box3DJoint3D = target.get_ref()
			if current == null or not is_instance_valid(controller): return
			var result := Box3DEditorIdentity.apply_plan(Box3DEditorJoints.plan_body_origins(current, controller.get_editor_interface().get_edited_scene_root()), controller.get_undo_redo())
			message.text = String(result.get("error", "")); message.visible = not result.get("ok", false))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.hide()
	add_child(message)
	modes.item_selected.connect(_selected)

func _selected(index: int) -> void:
	var joint: Box3DJoint3D = target.get_ref()
	if joint == null or not is_instance_valid(controller): return
	var plan := Box3DEditorJoints.plan_mode(joint, modes.get_item_id(index), controller.get_editor_interface().get_edited_scene_root())
	var result := Box3DEditorIdentity.apply_plan(plan, controller.get_undo_redo())
	message.text = String(result.get("error", ""))
	message.visible = not result.get("ok", false)
	modes.select(joint.frame_mode)
