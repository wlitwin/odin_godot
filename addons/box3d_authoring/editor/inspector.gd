@tool
class_name Box3DAuthoringInspectorPlugin
extends EditorInspectorPlugin

var controller: EditorPlugin
var panel_count: int=0
func _init(owner: EditorPlugin=null) -> void:controller=owner
func _can_handle(object: Object) -> bool:
	return object is Box3DWorld3D or object is Box3DBody3D or object is Box3DShape3D or object is Box3DCharacterMover3D or object is Box3DCharacterConfig3D or object is Box3DJoint3D or object is Box3DJointSettings3D or object is MeshInstance3D or object is Box3DBakeArtifact
func _parse_property(object: Object, _type: Variant.Type, name: String, _hint: PropertyHint, _hint_string: String, _usage: int, _wide: bool) -> bool:
	if (object is Box3DJoint3D and name in ["body_a", "body_b"]) or (object is Box3DCharacterMover3D and name == "exclude_body"):
		add_property_editor(name, Box3DBodyPicker.new(controller))
		return true
	return false
func _parse_begin(object: Object) -> void:
	panel_count+=1
	var panel:=VBoxContainer.new();panel.name="Box3DAuthoringActions"
	var title:=Label.new();title.text="Box3D authoring";panel.add_child(title)
	if object is Node3D:
		var legend:=Label.new();legend.text="Red: authoring error · Amber: preview unavailable or limited";legend.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;panel.add_child(legend)
	if not Box3DEditorIdentity.kind(object).is_empty():
		# Identity is stored, but is not a copyable/resettable native parameter.
		# Every UI edit must update its references in the same history action.
		panel.add_child(Box3DIdentityControl.new(controller, object))
	if object is Box3DJoint3D: panel.add_child(Box3DJointControl.new(controller, object))
	panel.add_child(Box3DSetupControl.new(controller))
	var output:=Box3DResultView.new();panel.add_child(output)
	if object is Node and not Box3DEditorIdentity.kind(object).is_empty():
		var duplicate := Button.new();duplicate.text="Duplicate Box3D selection";panel.add_child(duplicate)
		duplicate.tooltip_text="Duplicate the selected nodes with new identities and matching internal references. Shared shape Resources stay shared."
		duplicate.pressed.connect(func():
			var result: Dictionary = controller.duplicate_selection()
			output.show_result(result, "Duplicated selection."))
	if object is Box3DBody3D and not object.shapes.is_empty():
		var row := HBoxContainer.new();panel.add_child(row)
		var slots := OptionButton.new();slots.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(slots)
		for i in range(object.shapes.size()): slots.add_item("Shape %d" % (i + 1), i)
		var duplicate_shape := Button.new();duplicate_shape.text="Duplicate shape";row.add_child(duplicate_shape)
		duplicate_shape.tooltip_text="Copy this shape slot with its own ID, preserving the original shared Resource."
		duplicate_shape.pressed.connect(func():
			if not is_instance_valid(object): return
			var result: Dictionary = controller.duplicate_shape(object, slots.get_selected_id())
			output.show_result(result, "Duplicated shape."))
	var validate:=Button.new();validate.text="Validate physics";panel.add_child(validate)
	validate.pressed.connect(func():
		if is_instance_valid(object):output.show_result(controller.inspect_object(object)))
	if object is Box3DWorld3D:
		var bake_options := CheckButton.new();bake_options.text="Bake options";panel.add_child(bake_options)
		var revision:=LineEdit.new();revision.placeholder_text="Source revision (optional)";revision.tooltip_text="Optional version label stored with the baked world.";revision.visible=false;panel.add_child(revision)
		bake_options.toggled.connect(func(expanded: bool):revision.visible=expanded)
		var bake:=Button.new();bake.text="Bake physics world…";panel.add_child(bake)
		bake.pressed.connect(func():
			if is_instance_valid(object):controller.save_world_artifact(object,revision.text,output))
	if object is MeshInstance3D:
		var shape_options := CheckButton.new();shape_options.text="Shape ID (advanced)";panel.add_child(shape_options)
		var key:=LineEdit.new();key.text=Box3DIdentityKey.fresh("shape");key.tooltip_text="Saved collision shape ID. Keep the generated ID or enter your own.";key.visible=false;panel.add_child(key)
		shape_options.toggled.connect(func(expanded: bool):key.visible=expanded)
		var bake_mesh:=Button.new();bake_mesh.text="Create collision shape…";panel.add_child(bake_mesh)
		bake_mesh.pressed.connect(func():
			if is_instance_valid(object):controller.save_mesh_resource(object,key.text,output))
	add_custom_control(panel)
	# Default Inspector retains real exported-property editors; no shadow model.
