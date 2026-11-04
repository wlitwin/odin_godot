@tool
class_name Box3DAuthoringInspectorPlugin
extends EditorInspectorPlugin

var controller: EditorPlugin
var panel_count: int=0
func _init(owner: EditorPlugin=null) -> void:controller=owner
func _can_handle(object: Object) -> bool:
	return object is Box3DWorld3D or object is Box3DBody3D or object is Box3DShape3D or object is Box3DCharacterMover3D or object is Box3DCharacterConfig3D or object is Box3DJoint3D or object is Box3DJointSettings3D or object is MeshInstance3D or object is Box3DBakeArtifact
func _parse_begin(object: Object) -> void:
	panel_count+=1
	var panel:=VBoxContainer.new();panel.name="Box3DAuthoringActions"
	var title:=Label.new();title.text="Box3D authoring — explicit keys / detached bake";panel.add_child(title)
	var output:=RichTextLabel.new();output.fit_content=true;output.custom_minimum_size=Vector2(0,54);panel.add_child(output)
	var validate:=Button.new();validate.text="Validate / inspect shared identity";panel.add_child(validate)
	validate.pressed.connect(func():
		if is_instance_valid(object):output.text=JSON.stringify(controller.inspect_object(object),"  ",true,true))
	if object is Box3DWorld3D:
		var revision:=LineEdit.new();revision.placeholder_text="Explicit source revision";revision.text="1";panel.add_child(revision)
		var bake:=Button.new();bake.text="Bake owning definition artifact…";panel.add_child(bake)
		bake.pressed.connect(func():
			if is_instance_valid(object):controller.save_world_artifact(object,revision.text,output))
	if object is MeshInstance3D:
		var key:=LineEdit.new();key.placeholder_text="Explicit stable shape key (required)";panel.add_child(key)
		var bake_mesh:=Button.new();bake_mesh.text="Bake actual Mesh to shape Resource…";panel.add_child(bake_mesh)
		bake_mesh.pressed.connect(func():
			if is_instance_valid(object):controller.save_mesh_resource(object,key.text,output))
	var install:=Button.new();install.text="Install shared tools once (then ordinary Build Odin Scripts)";panel.add_child(install)
	install.pressed.connect(func():output.text=JSON.stringify(controller.services.install_once()))
	add_custom_control(panel)
	# Default Inspector retains real exported-property editors; no shadow model.
