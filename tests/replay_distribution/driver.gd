extends SceneTree
var game:Node
var phase:="wait"
var started:=0
var role:=""
var directory:=""
var closing:=false
func _initialize():
	role=OS.get_environment("REPLAY_STARTER_ROLE");directory=OS.get_environment("REPLAY_STARTER_TEST_DIR")
	game=load("res://main.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
func finish(code:int,reason:String=""):
	if closing:return
	if reason!="":print("REPLAY_PACKAGE_FAIL ",role," ",reason)
	closing=true;game.queue_free();game=null;await process_frame;await process_frame;quit(code)
func _process(_dt:float)->bool:
	if closing:return false
	if Time.get_ticks_msec()-started>20000:finish(1,"timeout "+phase);return false
	if game.probe("ready")!=1:return false
	match phase:
		"wait":
			if role=="solo":game.move(1);phase="move"
			elif role=="client":game.move(-1);phase="move"
			else:phase="observe"
		"move":
			if abs(game.probe("x")-320)>18:return false
			game.move(0);game.take();phase="observe"
		"observe":
			var expected_bag:=1 if role=="solo" else 2
			if game.probe("bag"+str(expected_bag))!=1 or game.probe("coin")!=0:return false
			if game.probe("bag1")+game.probe("bag2")!=1:finish(1,"coin duplication");return false
			if role=="solo":print("REPLAY_PACKAGE_SOLO_OK");finish(0)
			else:
				var f:=FileAccess.open(directory+"/"+role+".done",FileAccess.WRITE);f.store_string("done");f.close();phase="done"
		"done":
			for who in ["host","client","observer"]:
				if not FileAccess.file_exists(directory+"/"+who+".done"):return false
			print("REPLAY_PACKAGE_NETWORK_OK role=",role," coin=0 bag2=1");finish(0)
	return false
