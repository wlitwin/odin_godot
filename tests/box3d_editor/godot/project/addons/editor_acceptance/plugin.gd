@tool
extends EditorPlugin
func _enter_tree() -> void:
	if OS.get_environment("BOX3D_EDITOR_CHECK")=="1":call_deferred("_check")
func fail(message: String) -> void:
	push_error("BOX3D_EDITOR_CHECK_FAIL: "+message);get_tree().quit(1)
func _check() -> void:
	for _i in range(4):await get_tree().process_frame
	var nodes: Array=get_tree().get_nodes_in_group("box3d_authoring_editor_plugin")
	if nodes.size()!=1:fail("real plugin registration");return
	var addon: EditorPlugin=nodes[0]
	var status: Dictionary=addon.editor_status()
	if not status.inspector or not status.gizmo or not status.importer or not status.tools_available:fail("registered Inspector/Gizmo/importer/tools: "+JSON.stringify(status));return
	var installed: Dictionary=addon.services.install_once()
	if not installed.get("ok",false) or installed.get("copied",-1)!=0:fail("install-once standard module");return
	var world:=Box3DEditorFixture.make_world();var packed:=PackedScene.new()
	if packed.pack(world)!=OK or ResourceSaver.save(packed,"res://editor-world.tscn")!=OK:world.free();fail("scene fixture");return
	world.free();packed=null
	get_editor_interface().open_scene_from_path("res://editor-world.tscn")
	for _i in range(6):await get_tree().process_frame
	var edited: Node=get_editor_interface().get_edited_scene_root()
	if not edited is Box3DWorld3D:fail("actual edited World");return
	get_editor_interface().set_main_screen_editor("3D");get_editor_interface().edit_node(edited)
	edited.update_gizmos()
	for _i in range(6):await get_tree().process_frame
	var inspected: Dictionary=addon.inspect_object(edited)
	var geometry: Dictionary=addon.gizmos.geometry_for(edited)
	if not inspected.get("ok",false) or not geometry.get("ok",false) or geometry.lines<=0 or geometry.points.size()!=geometry.lines*2:fail("shared shape +authored joint/character gizmo geometry: "+JSON.stringify(geometry));return
	if addon.inspector.panel_count<=0 or addon.gizmos.redraw_count<=0:fail("actual registered Inspector/Gizmo callbacks not observed");return
	var body: Box3DBody3D=edited.get_children()[0]
	var shape: Box3DShape3D=body.shapes[0]
	var panels_before: int=addon.inspector.panel_count
	get_editor_interface().get_inspector().edit(shape)
	for _i in range(3):await get_tree().process_frame
	if get_editor_interface().get_inspector().get_edited_object()!=shape or addon.inspector.panel_count<=panels_before:fail("actual Resource Inspector edit/callback");return
	var old: float=shape.friction;shape.set("friction",0.625)
	if shape.get("friction")!=0.625:fail("real exported property editing");return
	shape.friction=old
	body.scale=Vector3(2,1,1)
	if addon.inspect_object(edited).get("ok",true) or addon.gizmos.geometry_for(edited).get("ok",true):fail("invalid transform diagnostics/preview");return
	body.scale=Vector3.ONE
	var baked: Dictionary=addon.services.bake_definition(edited.box3d_definition(),"res://editor-world.tscn","editor1")
	if not baked.get("ok",false):fail("editor shared artifact: "+JSON.stringify(baked));return
	var filesystem: EditorFileSystem=get_editor_interface().get_resource_filesystem()
	var completion: Dictionary={"target_reimported":false}
	var completed: Callable=func(paths: PackedStringArray):
		if paths.has("res://editor.b3authoring"):completion["target_reimported"]=true
	filesystem.resources_reimported.connect(completed)
	var file:=FileAccess.open("res://editor.b3authoring",FileAccess.WRITE)
	if file==null:
		filesystem.resources_reimported.disconnect(completed);fail("artifact source write");return
	file.store_buffer(Marshalls.base64_to_raw(baked.artifact_base64));file.close()
	filesystem.scan()
	for _i in range(120):
		await get_tree().process_frame
		if completion.target_reimported:break
	filesystem.resources_reimported.disconnect(completed)
	if not completion.target_reimported:fail("actual target resources_reimported completion unavailable");return
	var imported: Resource=ResourceLoader.load("res://editor.b3authoring","",ResourceLoader.CACHE_MODE_IGNORE)
	if not imported is Box3DBakeArtifact or not imported.inspect_with(addon.services).get("ok",false):fail("actual registered artifact importer");return
	var panels: int=addon.inspector.panel_count;var redraws: int=addon.gizmos.redraw_count;var line_count: int=geometry.lines
	get_editor_interface().set_plugin_enabled("box3d_authoring",false)
	for _i in range(4):await get_tree().process_frame
	if not get_tree().get_nodes_in_group("box3d_authoring_editor_plugin").is_empty():fail("disable/unregister");return
	get_editor_interface().set_plugin_enabled("box3d_authoring",true)
	for _i in range(4):await get_tree().process_frame
	nodes=get_tree().get_nodes_in_group("box3d_authoring_editor_plugin")
	if nodes.size()!=1 or not nodes[0].editor_status().tools_available:fail("clean reenable");return
	print("BOX3D_EDITOR_CHECK_OK inspector_panels=",panels," gizmo_callbacks=",redraws," lines=",line_count," importer=true enable_disable=true no_manual_pixel_claim=true")
	get_tree().quit(0)
