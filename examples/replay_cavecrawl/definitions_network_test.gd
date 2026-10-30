extends SceneTree
var game:Node
var role:=""
var phase:="join"
var started:=0
var finished_at:=0
var closing:=false
func _initialize():
	role=OS.get_environment("REPLAY_CAVE_ROLE")
	game=load("res://cave.tscn").instantiate()
	if role=="host":
		var resource:Resource=game.floor1_def.duplicate(true)
		resource.gems=7;resource.torches=9
		resource.wave_counts=PackedInt32Array([0,0,0]);resource.wave_rests=PackedInt32Array([0,0,0])
		var scene:Node=resource.scene.instantiate();scene.get_node("ChestSpawn").position=Vector2(330,210)
		var packed:=PackedScene.new();assert(packed.pack(scene)==OK);scene.free();resource.scene=packed
		game.floor1_def=resource
	else:
		assert(game.floor1_def.gems==3 and game.floor1_def.wave_counts.size()==2)
	root.add_child(game);started=Time.get_ticks_msec()
func finish(code:int,why:String=""):
	if closing:return
	if why!="":print("CAVE_DEFINITION_NETWORK_FAIL ",role," ",why)
	closing=true;game.queue_free();game=null
	await process_frame;await process_frame;quit(code)
func _process(_dt:float)->bool:
	if closing:return false
	var now:=Time.get_ticks_msec()
	if now-started>22000:finish(1,"timeout "+phase);return false
	if not game.probe_ready():return false
	match phase:
		"join":
			if game.probe_players()!=2:return false
			if game.probe_gems()!=7 or game.campaign_probe("torch_total",1)!=9:finish(1,"host stock missing");return false
			if role=="client":game.walk_to(330,210)
			phase="walk"
		"walk":
			if role=="client":
				if not game.probe_near(330,210):return false
				game.loot(0)
			phase="loot"
		"loot":
			if game.probe_chest(0)!=0 or game.campaign_probe("bag_gems",2)!=7:return false
			if game.campaign_probe("done",1)!=1 or game.campaign_probe("wave",1)!=3:finish(1,"host wave plan missing");return false
			if game.campaign_probe("scatter",1)!=976669602:finish(1,"scatter mismatch");return false
			finished_at=now;phase="linger"
		"linger":
			if now-finished_at>(2500 if role=="host" else 1000):
				if game.probe_gems()!=7:finish(1,"conservation");return false
				print("REPLAY_CAVE_DEFINITION_NETWORK_OK role=",role," gems=7 torches=9 waves=3 marker=330,210 scatter=976669602")
				finish(0)
	return false
