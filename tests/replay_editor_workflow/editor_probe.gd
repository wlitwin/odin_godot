@tool
extends EditorPlugin
var plugin:Node
func _enter_tree():run.call_deferred()
func find_plugin(node:Node)->Node:
	if node.get_script()!=null and node.get_script().resource_path=="res://addons/replay_authoring/plugin.gd":return node
	for child in node.get_children():
		var found:=find_plugin(child)
		if found!=null:return found
	return null
func wait_job()->Dictionary:
	var deadline:=Time.get_ticks_msec()+240000
	# Actions may wait for the editor's filesystem import before saving inputs.
	await get_tree().process_frame
	while (plugin.pid>0 or not plugin.pending_request.is_empty()) and Time.get_ticks_msec()<deadline:await get_tree().create_timer(.1).timeout
	assert(plugin.pid<0 and plugin.pending_request.is_empty(),"editor job deadline")
	return plugin.last_report
func edit_resource_property(resource:Resource,property:StringName,value:Variant):
	var history:=get_undo_redo()
	history.create_action("Edit "+property,UndoRedo.MERGE_DISABLE,resource)
	history.add_do_property(resource,property,value)
	history.add_undo_property(resource,property,resource.get(property))
	history.commit_action()
	assert(get_editor_interface().is_object_edited(resource),"Odin Resource edits use native dirty tracking")
func run():
	await get_tree().create_timer(1).timeout
	plugin=find_plugin(get_tree().root)
	assert(plugin!=null,"Replay authoring plugin loaded in the editor")
	assert(plugin.dock is ScrollContainer,"all actions remain reachable in a narrow dock")
	await wait_job()
	# Prevent background status refresh from replacing the operation under test.
	plugin.status_clock=-100000
	var source:Resource=load("res://data/abilities/salvefield.tres")
	var original:float=source.radius
	get_editor_interface().edit_resource(source)
	edit_resource_property(source,"radius",-1.0)
	plugin._start("validate")
	var invalid:=await wait_job()
	assert(not invalid.ok and invalid.issues.size()>0)
	var matching:int=-1
	for i in range(invalid.issues.size()):
		if invalid.issues[i].source=="res://data/abilities/salvefield.tres" and "radius" in invalid.issues[i].path:matching=i
	if matching < 0:
		var plan:Dictionary=plugin.saved_data.collect(get_editor_interface(),true)
		for issue in invalid.issues:
			var id:=int(issue.get("object_id",0))
			if id!=0 and is_instance_id_valid(id):
				var object:=instance_from_id(id)
				var entry:Dictionary=plan.entries.get(id,{})
				print("SAVE_OWNER_DIAGNOSTIC class=",object.get_class()," path=",object.resource_path," owners=",entry.get("owners",{}))
		get_tree().quit(1)
		return
	assert(matching>=0,"field diagnostic names the edited Resource: "+str(invalid))
	plugin._open_issue(matching)
	assert(get_editor_interface().get_inspector().get_edited_object().resource_path==source.resource_path,"click opens Resource")
	edit_resource_property(source,"radius",original)
	plugin._start("validate")
	var valid:=await wait_job();assert(valid.ok)
	# Stable-ID conflicts share game admission's loader and remain clickable.
	var duplicate:Resource=load("res://data/abilities/ignite.tres")
	var original_id:int=duplicate.id
	get_editor_interface().edit_resource(duplicate)
	edit_resource_property(duplicate,"id",source.id)
	plugin._start("validate")
	var collision:=await wait_job()
	assert(not collision.ok)
	var collision_index:int=-1
	for i in range(collision.issues.size()):
		var issue:Dictionary=collision.issues[i]
		if issue.source==source.resource_path and "duplicate ID" in issue.message:
			assert("salvefield.tres" in issue.message and "ignite.tres" in issue.message)
			collision_index=i
	assert(collision_index>=0,"duplicate ID identifies both files")
	plugin._open_issue(collision_index)
	assert(get_editor_interface().get_inspector().get_edited_object().resource_path==source.resource_path)
	get_editor_interface().edit_resource(duplicate)
	edit_resource_property(duplicate,"id",original_id)
	plugin._start("bake")
	var baked:=await wait_job();assert(baked.ok and not baked.stale)
	print("REPLAY_WORKFLOW_EDITOR_OK validate=true clickable=true recovery=true bake=true")
	get_tree().quit()
