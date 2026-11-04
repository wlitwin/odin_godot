@tool
extends EditorPlugin

var services: Box3DEditorServices
var inspector: Box3DAuthoringInspectorPlugin
var gizmos: Box3DAuthoringGizmoPlugin
var importer: Box3DAuthoringArtifactImporter
func _enter_tree() -> void:
	services=Box3DEditorServices.new(self)
	inspector=Box3DAuthoringInspectorPlugin.new(self);gizmos=Box3DAuthoringGizmoPlugin.new(services);importer=Box3DAuthoringArtifactImporter.new(services)
	add_inspector_plugin(inspector);add_node_3d_gizmo_plugin(gizmos);add_import_plugin(importer)
	add_tool_menu_item("Box3D: install shared authoring tools",_install)
	add_to_group("box3d_authoring_editor_plugin")
	get_editor_interface().get_inspector().property_edited.connect(_property_edited)
func _exit_tree() -> void:
	get_editor_interface().get_inspector().property_edited.disconnect(_property_edited)
	remove_tool_menu_item("Box3D: install shared authoring tools")
	remove_import_plugin(importer);remove_node_3d_gizmo_plugin(gizmos);remove_inspector_plugin(inspector)
	if services!=null:services.dispose()
	importer=null;gizmos=null;inspector=null;services=null
	remove_from_group("box3d_authoring_editor_plugin")
func _install() -> void:
	var result: Dictionary=services.install_once()
	print("BOX3D_EDITOR_INSTALL ",JSON.stringify(result))
	if not result.get("ok",false):push_warning(String(result.get("error","install failed")))
func _property_edited(_property: StringName) -> void:
	var edited: Object=get_editor_interface().get_inspector().get_edited_object()
	if edited is Node:edited.update_configuration_warnings()
	if edited is Node3D:edited.update_gizmos()
func world_of(object: Object) -> Box3DWorld3D:
	var current: Node=object as Node
	while current!=null:
		if current is Box3DWorld3D:return current
		current=current.get_parent()
	return null
func inspect_object(object: Object) -> Dictionary:
	if object is Box3DBakeArtifact:return object.inspect_with(services)
	var world: Box3DWorld3D=world_of(object)
	if world!=null:
		var errors: Array=world.box3d_diagnostics()
		if not errors.is_empty():return {"ok":false,"diagnostics":errors}
		return services.inspect_definition(world.box3d_definition())
	if object is Box3DShape3D:
		var temporary:=Box3DWorld3D.new();temporary.stable_key="resource.preview"
		var body:=Box3DBody3D.new();body.stable_key="preview.body";body.shapes.append(object);temporary.add_child(body)
		var errors: Array=temporary.box3d_diagnostics();var definition: Dictionary=temporary.box3d_definition();temporary.free()
		return {"ok":false,"diagnostics":errors} if not errors.is_empty() else services.inspect_definition(definition)
	if object is Box3DCharacterConfig3D:
		var errors: Array=[];var config: Dictionary=object.box3d_character_config("config",errors);return {"ok":errors.is_empty(),"diagnostics":errors,"configuration":config}
	if object is Box3DJointSettings3D:
		for kind in ["pin","hinge","slider","spherical","distance","motor","weld","wheel"]:
			if object.accepts_kind(kind):
				var errors: Array=[];var settings: Dictionary=object.definition(kind,"settings",errors);return {"ok":errors.is_empty(),"diagnostics":errors,"settings":settings}
	return {"ok":false,"diagnostic":{"error":"Select an authoring object or containing World."}}
func _dialog(filter: String,callback: Callable) -> void:
	var dialog:=EditorFileDialog.new();dialog.access=EditorFileDialog.ACCESS_RESOURCES;dialog.file_mode=EditorFileDialog.FILE_MODE_SAVE_FILE;dialog.add_filter(filter)
	get_editor_interface().get_base_control().add_child(dialog);dialog.file_selected.connect(callback);dialog.file_selected.connect(func(_path: String):dialog.queue_free());dialog.canceled.connect(func():dialog.queue_free());dialog.popup_centered_ratio(0.6)
func save_world_artifact(world: Box3DWorld3D,revision: String,output: RichTextLabel) -> void:
	var errors: Array=world.box3d_diagnostics()
	if not errors.is_empty():output.text=JSON.stringify(errors);return
	var uri: String=world.scene_file_path if not world.scene_file_path.is_empty() else "unsaved://"+world.stable_key
	var result: Dictionary=services.bake_definition(world.box3d_definition(),uri,revision)
	output.text=JSON.stringify(result.get("metadata",result),"  ")
	if not result.get("ok",false):return
	_dialog("*.b3authoring ; Box3D owning definition",func(path: String):
		var file:=FileAccess.open(path,FileAccess.WRITE)
		if file==null:output.text="Cannot write artifact.";return
		file.store_buffer(Marshalls.base64_to_raw(result.artifact_base64));file.close();get_editor_interface().get_resource_filesystem().scan())
func save_mesh_resource(instance: MeshInstance3D,key: String,output: RichTextLabel) -> void:
	var body: Box3DBody3D=null;var current: Node=instance.get_parent()
	while current!=null:
		if current is Box3DBody3D:body=current;break
		current=current.get_parent()
	if body==null or body.body_type!=0 or body._sensor_body():output.text="Mesh baking requires a Static non-sensor authoring body parent.";return
	var transform: Transform3D=Transform3D.IDENTITY;current=instance
	while current!=body:
		if current is Node3D:
			if current.top_level:output.text="Top-level mesh source cannot inherit the target body frame.";return
			transform=current.transform*transform
		current=current.get_parent()
	var result: Dictionary=Box3DEditorMeshBaker.bake_mesh(instance.mesh,key,transform,null,instance.scene_file_path,"1")
	if not result.get("ok",false):output.text=JSON.stringify(result);return
	_dialog("*.tres ; Box3D Mesh shape",func(path: String):output.text="Resource save status: "+str(ResourceSaver.save(result.resource,path)))
func editor_status() -> Dictionary:
	return {"inspector":inspector!=null,"gizmo":gizmos!=null,"importer":importer!=null,"tools_available":services!=null and services.available(),"inspector_panels":inspector.panel_count if inspector!=null else 0,"gizmo_redraws":gizmos.redraw_count if gizmos!=null else 0}
