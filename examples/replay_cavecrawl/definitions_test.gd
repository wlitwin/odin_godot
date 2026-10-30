extends SceneTree
var game:Node
var phase:="boot"
var started:=0
var changed:Resource
var closing:=false
func _initialize():
	game=load("res://cave.tscn").instantiate()
	changed=game.floor1_def.duplicate(true)
	changed.gems=7;changed.torches=9;changed.wave_counts=PackedInt32Array([0,0,0]);changed.wave_rests=PackedInt32Array([0,0,0])
	var scene:Node=changed.scene.instantiate();scene.get_node("ChestSpawn").position=Vector2(330,210)
	var packed:=PackedScene.new();assert(packed.pack(scene)==OK);scene.free();changed.scene=packed
	game.floor1_def=changed
	root.add_child(game);started=Time.get_ticks_msec()
func finish(code:int,why:String=""):
	if closing:return
	if why!="":print("CAVE_DEFINITION_TEST_FAIL ",why)
	closing=true;game.queue_free();game=null;changed=null;await process_frame;await process_frame;quit(code)
func _process(_dt:float)->bool:
	if closing:return false
	if Time.get_ticks_msec()-started>18000:finish(1,"timeout "+phase);return false
	if not game.probe_ready():return false
	match phase:
		"boot":
			if game.probe_chest(0)!=7 or game.campaign_probe("torch_total",1)!=9:finish(1,"resource stock");return false
			changed.gems=99;changed.wave_counts=PackedInt32Array([200])
			game.walk_to(330,210);phase="walk"
		"walk":
			if game.probe_near(330,210):game.loot(0);phase="loot"
		"loot":
			if game.probe_bag()==7 and game.campaign_probe("done",1)==1:
				if game.campaign_probe("wave",1)!=3:finish(1,"authored wave plan");return false
				if not game.save():finish(1,"save definitions");return false
				print("REPLAY_CAVE_DEFINITIONS_OK gems=7 torches=9 waves=3 marker=330,210 live_resource_mutation_ignored=true")
				finish(0)
	return false
