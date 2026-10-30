extends SceneTree
var game:Node
var role:=""
var phase:="join"
var started:=0
var acted:=0
var before_x:=0.0
var closing:=false
var directory:=""
func _initialize():
	role=OS.get_environment("REPLAY_CAVE_ROLE");directory=OS.get_environment("REPLAY_SOCIAL_DIR")
	game=load("res://cave.tscn").instantiate()
	if role=="host":
		var resource:Resource=game.floor1_def.duplicate(true)
		resource.wave_counts=PackedInt32Array([0]);resource.wave_rests=PackedInt32Array([0]);game.floor1_def=resource
	root.add_child(game);started=Time.get_ticks_msec()
func signal_file(name:String):
	var file:=FileAccess.open(directory+"/"+name,FileAccess.WRITE);file.store_string("ready");file.close()
func has_file(name:String)->bool:return FileAccess.file_exists(directory+"/"+name)
func finish(code:int,why:String=""):
	if closing:return
	if why!="":print("CAVE_SOCIAL_FAIL ",role," ",why)
	Input.action_release("rc_right");Input.action_release("rc_throw")
	closing=true;game.queue_free();game=null
	await process_frame;await process_frame;quit(code)
func _process(_dt:float)->bool:
	if closing:return false
	var now:=Time.get_ticks_msec()
	if now-started>26000:finish(1,"timeout "+phase);return false
	if not game.probe_ready() or game.social_probe("ready")!=1:return false
	var chat:LineEdit=game.get_node("Social/Chat/Input")
	var lines:String=game.get_node("Social/Chat/Lines").text
	match phase:
		"join":
			if game.probe_players()!=2:return false
			if role=="observer":
				if not lines.contains("Seat 1: found a torch") or not lines.contains("Seat 2: on my way"):return false
				if game.social_probe("marks")!=0:finish(1,"old ping replayed to late join");return false
				print("REPLAY_CAVE_SOCIAL_LATE_JOIN_OK lines=2 old_marks=0");signal_file("observer_ready");phase="new_marker"
			else:
				chat.grab_focus();chat.text="found a torch" if role=="host" else "on my way"
				before_x=game.probe_x();Input.action_press("rc_right");Input.action_press("rc_throw");acted=now;phase="typing"
		"typing":
			if now-acted<600:return false
			if abs(game.probe_x()-before_x)>0.1 or game.campaign_probe("rocks",1)!=0:finish(1,"typing moved or fired");return false
			Input.action_release("rc_right");Input.action_release("rc_throw")
			chat.text_submitted.emit(chat.text)
			if chat.text!="" or chat.has_focus():finish(1,"submit did not clear/release");return false
			phase="chat"
		"chat":
			if not lines.contains("Seat 1: found a torch") or not lines.contains("Seat 2: on my way"):return false
			if game.social_probe("lines")!=2:finish(1,"duplicate lines");return false
			if role=="client":game.mark()
			phase="marker"
		"marker":
			if game.social_probe("marks")!=1:return false
			if role=="host":signal_file("late_join")
			phase="observer"
		"observer":
			if not has_file("observer_ready"):return false
			if role=="client":game.mark()
			phase="new_marker"
		"new_marker":
			if game.social_probe("marks")!=(1 if role=="observer" else 2):return false
			if role=="client":game.walk_to(300,180)
			phase="walk"
		"walk":
			if role=="client":
				if not game.probe_near(300,180):return false
				game.loot(0)
			phase="score"
		"score":
			if game.campaign_probe("bag_gems",2)!=3:return false
			game.show_score(true);acted=now;phase="score_check"
		"score_check":
			if now-acted<100:return false
			var board:Control=game.get_node("Social/Scoreboard")
			if not board.visible or game.get_node("Social/Scoreboard/Column/Grid/Row1_5").text!="3":finish(1,"scoreboard loot");return false
			if game.get_node("Social/Scoreboard/Column/Grid/Row1_6").text!="100":finish(1,"scoreboard hp");return false
			if game.social_probe("active_marks")!=0:return false
			game.show_score(false);signal_file("done-"+role);acted=now;phase="linger"
		"linger":
			for peer in ["host","client","observer"]:
				if not has_file("done-"+peer):return false
			if now-acted<(1500 if role=="host" else 500):return false
			print("REPLAY_CAVE_SOCIAL_OK role=",role," lines=2 marks=",game.social_probe("marks")," expired=true typing_blocked=true scoreboard_gems=3")
			finish(0)
	return false
