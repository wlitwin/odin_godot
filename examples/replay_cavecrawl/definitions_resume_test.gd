extends SceneTree
var game:Node
var started:=0
var closing:=false
func _initialize():
	game=load("res://cave.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
func _process(_dt:float)->bool:
	if closing:return false
	if Time.get_ticks_msec()-started>12000:print("CAVE_DEFINITION_TEST_FAIL resume timeout");quit(1);return true
	if not game.probe_ready():return false
	if game.probe_bag()!=7 or game.campaign_probe("wave",1)!=3 or game.campaign_probe("done",1)!=1 or game.campaign_probe("gem_total",1)!=7:
		print("CAVE_DEFINITION_TEST_FAIL restored definitions");quit(1);return true
	print("REPLAY_CAVE_DEFINITION_RESUME_OK gems=7 waves=3")
	closing=true;game.queue_free();game=null;await process_frame;await process_frame;quit(0);return false
