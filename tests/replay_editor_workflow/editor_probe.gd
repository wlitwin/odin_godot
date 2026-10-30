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
	while plugin.pid>0 and Time.get_ticks_msec()<deadline:await get_tree().create_timer(.1).timeout
	assert(plugin.pid<0,"editor job deadline")
	return plugin.last_report
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
	source.radius=-1
	plugin._start("validate")
	var invalid:=await wait_job()
	assert(not invalid.ok and invalid.issues.size()>0)
	var matching:int=-1
	for i in range(invalid.issues.size()):
		if invalid.issues[i].source=="res://data/abilities/salvefield.tres" and "radius" in invalid.issues[i].path:matching=i
	assert(matching>=0,"field diagnostic names the edited Resource")
	plugin._open_issue(matching)
	assert(get_editor_interface().get_inspector().get_edited_object().resource_path==source.resource_path,"click opens Resource")
	source.radius=original;assert(ResourceSaver.save(source)==OK)
	plugin._start("validate")
	var valid:=await wait_job();assert(valid.ok)
	plugin._start("bake")
	var baked:=await wait_job();assert(baked.ok and not baked.stale)
	print("REPLAY_WORKFLOW_EDITOR_OK validate=true clickable=true recovery=true bake=true")
	get_tree().quit()
