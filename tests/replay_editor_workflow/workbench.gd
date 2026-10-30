extends SceneTree
var bench:Node
var elapsed:float=0
var phase:int=0
var exports:int=0
func _initialize():run.call_deferred()
func run():
	bench=load("res://dev/workbench.tscn").instantiate()
	bench.ability=load("res://data/abilities/salvefield.tres");bench.cast_on_start=true;bench.hurt=true
	root.add_child(bench)
func _process(dt:float)->bool:
	elapsed+=dt
	if elapsed>30:printerr("REPLAY_WORKFLOW_WORKBENCH_FAIL deadline");quit(1);return false
	if bench==null or not bench.is_staged():return false
	var game:Node=bench.game_node()
	if phase==0:
		assert(game.probe("ability0",1)==5)
		if game.probe("casts",1)<1:return false
		assert(game.probe("zones_spawned",1)>0)
		# Refreshing a separate authored definition does not change this admitted World.
		var ability:Resource=load("res://data/abilities/salvefield.tres")
		var old:float=ability.radius;ability.radius=old+30
		assert(game.probe("casts",1)==1)
		ability.radius=old
		assert(bench.export_recording());phase=1
	elif phase==1 and bench.recording_exports()>0:
		print("REPLAY_WORKFLOW_WORKBENCH_OK profile=true admitted_cast=true zone=true reproduction=true")
		phase=2;finish.call_deferred()
	return false

func finish():
	bench.queue_free();bench=null
	await process_frame;await process_frame
	await create_timer(.2).timeout
	quit(0)
