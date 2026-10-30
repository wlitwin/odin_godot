extends SceneTree
var game:Node
var began:=0
var done:=false
func _initialize():
	game=load("res://main.tscn").instantiate();root.add_child(game);began=Time.get_ticks_msec()
func p(key:String)->int:return int(game.probe(key,1))
func finish(code:int):
	done=true;game.queue_free();game=null;await process_frame;await process_frame
	await create_timer(0.3).timeout
	quit(code)
func _process(_dt:float)->bool:
	if done:return false
	if Time.get_ticks_msec()-began>10000:print("RSY_SETTINGS_FAIL timeout");finish(1);return false
	if not p("ready") or p("settings_pending"):return false
	var mode:=OS.get_environment("RSY_SETTINGS_TEST")
	if mode=="create":
		if p("volume")!=8 or p("settings_error"):print("RSY_SETTINGS_FAIL defaults");finish(1);return false
		for _i in 5:game.on_volume_down()
		game.on_shake()
		if p("volume")!=3 or p("shake_off")!=1 or p("settings_error"):print("RSY_SETTINGS_FAIL write");finish(1);return false
	elif mode=="reload":
		if p("volume")!=3 or p("shake_off")!=1 or p("settings_error"):print("RSY_SETTINGS_FAIL reload");finish(1);return false
	elif mode=="corrupt":
		if p("settings_error")!=1 or p("volume")!=8:print("RSY_SETTINGS_FAIL corruption");finish(1);return false
		game.on_volume_down()
		if p("volume")!=7 or p("settings_error")!=1:print("RSY_SETTINGS_FAIL session-only change");finish(1);return false
	print("REPLAY_SETTINGS_OK mode=",mode," volume=",p("volume")," shake_off=",p("shake_off")," sounds=",p("sound_plays"))
	finish(0);return false
