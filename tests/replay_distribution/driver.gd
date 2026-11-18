extends SceneTree
var game:Node
var phase:="wait"
var started:=0
var role:=""
var directory:=""
var closing:=false
var capture:AudioEffectCapture
var mixed:=false
var flash_seen:=false
func _initialize():
	role=OS.get_environment("REPLAY_STARTER_ROLE");directory=OS.get_environment("REPLAY_STARTER_TEST_DIR")
	capture=AudioEffectCapture.new();capture.buffer_length=0.5;AudioServer.add_bus_effect(0,capture)
	game=load("res://main.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
func finish(code:int,reason:String=""):
	if closing:return
	if reason!="":print("REPLAY_PACKAGE_FAIL ",role," ",reason)
	closing=true;game.queue_free();game=null
	AudioServer.remove_bus_effect(0,0);capture=null
	await process_frame
	# AudioServer releases stopped playback references asynchronously. Two
	# unthrottled headless frames can finish before a mixer cycle has run.
	await create_timer(0.25).timeout
	await process_frame
	quit(code)
func _process(_dt:float)->bool:
	if closing:return false
	if Time.get_ticks_msec()-started>30000:finish(1,"timeout "+phase);return false
	if game.probe("ready")!=1:return false
	for sample in capture.get_buffer(mini(capture.get_frames_available(),4096)):
		if abs(sample.x)+abs(sample.y)>0.0001:mixed=true
	if game.effect_probe("live")>0:flash_seen=true
	if game.effect_probe("begun")>1 or game.effect_probe("played")>1:
		finish(1,"duplicate pickup presentation");return false
	if game.effect_probe("dropped")!=0:finish(1,"dropped pickup presentation");return false
	match phase:
		"wait":
			if game.probe("tick")<600:return false
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
			if not flash_seen or not mixed or game.effect_probe("played")!=1:return false
			if game.effect_probe("live")!=0:return false
			if role=="solo":
				if not game.effect_contract():finish(1,"effect contract");return false
				print("REPLAY_PACKAGE_SOLO_OK effects=1 sound=1 pcm=true expired=true");finish(0)
			else:
				var f:=FileAccess.open(directory+"/"+role+".done",FileAccess.WRITE);f.store_string("done");f.close();phase="done"
		"done":
			for who in ["host","client","observer"]:
				if not FileAccess.file_exists(directory+"/"+who+".done"):return false
			print("REPLAY_PACKAGE_NETWORK_OK role=",role," coin=0 bag2=1 effects=1 sound=1 pcm=true expired=true");finish(0)
	return false
