extends SceneTree
var ui:Node
func _initialize():run.call_deferred()
func until(predicate:Callable,seconds:float)->bool:
	var end:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end:
		if predicate.call():return true
		await process_frame
	return false
func run():
	ui=load("res://dev/ability_workbench.tscn").instantiate();root.add_child(ui)
	await process_frame;await process_frame
	assert(ui.preview!=null and ui.preview.preview_radius()==90)
	ui.start_encounter()
	assert(await until(func():return ui.encounter!=null and ui.encounter.is_staged() and ui.encounter.game_node().probe("casts",1)==1,30))
	ui.export_recording()
	assert(await until(func():return ui.encounter.recording_exports()>0,10))
	await ui.stop_encounter()
	assert(ui.preview!=null and ui.encounter==null)
	ui.run_job("correction")
	assert(await until(func():return ui.pid<0,240))
	var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ui.result_path))
	assert(report.ok and report.after_casts==0)
	print("REPLAY_WORKFLOW_UI_OK preview=true encounter=true reproduction=true correction=true")
	ui.queue_free();ui=null;await process_frame;await process_frame;await create_timer(.2).timeout
	quit()
