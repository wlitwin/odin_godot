@tool
extends EditorPlugin

var services: Box3DEditorServices
var inspector: Box3DAuthoringInspectorPlugin
var gizmos: Box3DAuthoringGizmoPlugin
var importer: Box3DAuthoringArtifactImporter
var identity_menu: Box3DIdentityContextMenu
var _preview_history: UndoRedo
var _setup_elapsed: float = 0.0
var _tools_ready: bool = false
func _enter_tree() -> void:
	services=Box3DEditorServices.new(self)
	inspector=Box3DAuthoringInspectorPlugin.new(self);gizmos=Box3DAuthoringGizmoPlugin.new(services,self);importer=Box3DAuthoringArtifactImporter.new(services)
	add_inspector_plugin(inspector);add_node_3d_gizmo_plugin(gizmos);add_import_plugin(importer)
	identity_menu=Box3DIdentityContextMenu.new(self)
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE,identity_menu)
	add_tool_menu_item("Box3D: setup and status",_install)
	add_tool_menu_item("Box3D: duplicate selection",_duplicate_selection)
	add_to_group("box3d_authoring_editor_plugin")
	get_editor_interface().get_inspector().property_edited.connect(_property_edited)
	get_undo_redo().version_changed.connect(_refresh_previews)
	get_tree().tree_changed.connect(_invalidate_previews)
	scene_changed.connect(_preview_scene_changed)
	call_deferred("_refresh_previews")
func _exit_tree() -> void:
	get_editor_interface().get_inspector().property_edited.disconnect(_property_edited)
	get_undo_redo().version_changed.disconnect(_refresh_previews)
	get_tree().tree_changed.disconnect(_invalidate_previews)
	scene_changed.disconnect(_preview_scene_changed)
	if is_instance_valid(_preview_history) and _preview_history.version_changed.is_connected(_refresh_previews):
		_preview_history.version_changed.disconnect(_refresh_previews)
	_preview_history=null
	remove_tool_menu_item("Box3D: setup and status")
	remove_tool_menu_item("Box3D: duplicate selection")
	remove_context_menu_plugin(identity_menu)
	identity_menu=null
	remove_import_plugin(importer);remove_node_3d_gizmo_plugin(gizmos);remove_inspector_plugin(inspector)
	if services!=null:services.dispose()
	importer=null;gizmos=null;inspector=null;services=null
	remove_from_group("box3d_authoring_editor_plugin")
func _process(delta: float) -> void:
	_setup_elapsed += delta
	if _setup_elapsed < 1.0 or services == null: return
	_setup_elapsed = 0.0
	var ready := services.available()
	if ready != _tools_ready:
		_tools_ready = ready
		_refresh_previews()
	if ready and not services.pending_imports.is_empty():
		var paths := services.pending_imports.duplicate()
		services.pending_imports.clear()
		get_editor_interface().get_resource_filesystem().call_deferred("reimport_files", paths)
func _install() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Box3D setup"
	dialog.add_child(Box3DSetupControl.new(self))
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(540, 220))

func rekey_object(object: Object, key: String) -> Dictionary:
	var plan := Box3DEditorIdentity.plan_rekey(object, key, get_editor_interface().get_edited_scene_root())
	return Box3DEditorIdentity.apply_plan(plan, get_undo_redo())

func duplicate_selection() -> Dictionary:
	return duplicate_nodes(get_editor_interface().get_selection().get_selected_nodes())

func duplicate_nodes(nodes: Array) -> Dictionary:
	var selected: Array[Node] = []
	for node in nodes:
		if not node is Node or not is_instance_valid(node):
			return {"ok": false, "error": "Select live nodes from the edited scene."}
		selected.append(node)
	var selection := get_editor_interface().get_selection()
	var plan := Box3DEditorIdentity.plan_duplicate(selected, get_editor_interface().get_edited_scene_root())
	var result := Box3DEditorIdentity.apply_plan(plan, get_undo_redo())
	if result.get("ok", false) and result.get("changed", false):
		selection.clear()
		for node in result.nodes: selection.add_node(node)
	return result

func _duplicate_selection() -> void:
	var result := duplicate_selection()
	if not result.get("ok", false): push_warning(String(result.error))

func duplicate_shape(body: Box3DBody3D, index: int) -> Dictionary:
	var plan := Box3DEditorIdentity.plan_duplicate_shape(body, index, get_editor_interface().get_edited_scene_root())
	return Box3DEditorIdentity.apply_plan(plan, get_undo_redo())

func _property_edited(_property: StringName) -> void:
	_refresh_previews()
func _invalidate_previews() -> void:
	if gizmos!=null:gizmos.invalidate()
func _preview_scene_changed(_root: Node) -> void:
	_refresh_previews()
func _refresh_previews() -> void:
	_invalidate_previews()
	var root:=get_editor_interface().get_edited_scene_root()
	if root==null:
		if is_instance_valid(_preview_history) and _preview_history.version_changed.is_connected(_refresh_previews):
			_preview_history.version_changed.disconnect(_refresh_previews)
		_preview_history=null
		return
	var history:=get_undo_redo().get_history_undo_redo(get_undo_redo().get_object_history_id(root))
	if history!=_preview_history:
		if is_instance_valid(_preview_history) and _preview_history.version_changed.is_connected(_refresh_previews):
			_preview_history.version_changed.disconnect(_refresh_previews)
		_preview_history=history
		if history!=null:history.version_changed.connect(_refresh_previews)
	for node in Box3DEditorIdentity._nodes(root):
		if node is Box3DWorld3D or node is Box3DBody3D or node is Box3DJoint3D or node is Box3DCharacterMover3D:
			node.update_configuration_warnings()
			node.update_gizmos()
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
func save_world_artifact(world: Box3DWorld3D,revision: String,output: Box3DResultView) -> void:
	var errors: Array=world.box3d_diagnostics()
	if not errors.is_empty():output.show_result({"ok":false,"diagnostics":errors});return
	var uri: String=world.scene_file_path if not world.scene_file_path.is_empty() else "unsaved://"+world.stable_key
	var result: Dictionary=services.bake_definition(world.box3d_definition(),uri,revision)
	output.show_result(result,"Physics world baked. Choose where to save it.")
	if not result.get("ok",false):return
	_dialog("*.b3authoring ; Box3D physics world",func(path: String):
		var file:=FileAccess.open(path,FileAccess.WRITE)
		if file==null:
			if is_instance_valid(output):output.message("Cannot write the physics world.")
			return
		file.store_buffer(Marshalls.base64_to_raw(result.artifact_base64));file.close();get_editor_interface().get_resource_filesystem().scan()
		if is_instance_valid(output):output.message("Saved physics world to " + path))
func save_mesh_resource(instance: MeshInstance3D,key: String,output: Box3DResultView) -> void:
	var body: Box3DBody3D=null;var current: Node=instance.get_parent()
	while current!=null:
		if current is Box3DBody3D:body=current;break
		current=current.get_parent()
	if body==null or body.body_type!=0 or body._sensor_body():output.message("Place the mesh below a Static Box3D body that is not a sensor.");return
	var transform: Transform3D=Transform3D.IDENTITY;current=instance
	while current!=body:
		if current is Node3D:
			if current.top_level:output.message("Turn off Top Level on the mesh source so it follows its body.");return
			transform=current.transform*transform
		current=current.get_parent()
	var result: Dictionary=Box3DEditorMeshBaker.bake_mesh(instance.mesh,key,transform,null,instance.scene_file_path,"1")
	if not result.get("ok",false):output.show_result(result);return
	_dialog("*.tres ; Box3D collision shape",func(path: String):
		var error := ResourceSaver.save(result.resource,path)
		if is_instance_valid(output):output.message("Saved collision shape to " + path if error == OK else "Cannot save collision shape: " + error_string(error)))
func editor_status() -> Dictionary:
	return {"inspector":inspector!=null,"gizmo":gizmos!=null,"importer":importer!=null,"tools_available":services!=null and services.available(),"inspector_panels":inspector.panel_count if inspector!=null else 0,"gizmo_redraws":gizmos.redraw_count if gizmos!=null else 0}
