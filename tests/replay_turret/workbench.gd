extends SceneTree
var bench:Node
var elapsed:float=0
var phase:int=0
func _initialize():start.call_deferred()
func start():
	bench=load("res://dev/turret_workbench.tscn").instantiate();root.add_child(bench)
	assert(bench.ability.id==7)
	bench.start_encounter()
func _process(dt:float)->bool:
	elapsed+=dt
	if elapsed>25:printerr("REPLAY_TURRET_WORKBENCH_FAIL deadline");quit(1);return false
	if phase==2 or bench==null or bench.encounter==null or not bench.encounter.is_staged():return false
	var game:Node=bench.encounter.game_node()
	if phase==0:
		if game.turret_probe("count",1)!=1 or game.turret_probe("views",1)!=1:return false
		assert(game.turret_probe("ammo",1)==24)
		var definition:Resource=load("res://data/deployables/shared_turret.tres")
		var before:int=game.editor_catalog_hash()
		assert(before!=-1)
		definition.ammo=0;assert(game.editor_catalog_hash()==-1)
		definition.ammo=24;assert(game.editor_catalog_hash()==before)
		assert(game.dev_turret_use());phase=1
	elif phase==1 and game.turret_probe("mounted",1)==1:
		assert(game.turret_probe("ammo",1)==24)
		print("REPLAY_TURRET_WORKBENCH_OK authored=true validation=true deployed=true scene=true mounted=true")
		phase=2;finish.call_deferred()
	return false
func finish():
	bench.queue_free();bench=null
	await process_frame;await process_frame;await create_timer(.2).timeout
	quit(0)
