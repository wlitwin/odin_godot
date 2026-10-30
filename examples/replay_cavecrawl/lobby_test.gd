extends SceneTree
var game:Node
var role:=""
var phase:="menu"
var started:=0
var acted:=0
var directory:=""
var closing:=false
func _initialize():
	role=OS.get_environment("REPLAY_LOBBY_ROLE");directory=OS.get_environment("REPLAY_LOBBY_DIR")
	game=load("res://cave.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
func signal_file(name:String):
	var file:=FileAccess.open(directory+"/"+name,FileAccess.WRITE);file.store_string("ready");file.close()
func has_file(name:String)->bool:return FileAccess.file_exists(directory+"/"+name)
func press(name:String):game.get_node("Lobby/Panel/Column/Buttons/"+name).pressed.emit()
func finish(code:int,why:String=""):
	if closing:return
	if why!="":print("CAVE_LOBBY_FAIL ",role," ",why)
	closing=true;game.queue_free();game=null
	await process_frame;await process_frame;quit(code)
func _process(_dt:float)->bool:
	if closing:return false
	var now:=Time.get_ticks_msec()
	if now-started>30000:finish(1,"timeout "+phase);return false
	if game.lobby_probe("profile_ready",0)!=1:return false
	var name:LineEdit=game.get_node("Lobby/Panel/Column/Name")
	var start:Button=game.get_node("Lobby/Panel/Column/Buttons/Start")
	var roster:String=game.get_node("Lobby/Panel/Column/Roster").text
	var lines:String=game.get_node("Social/Chat/Lines").text
	match phase:
		"menu":
			if not game.get_node("Lobby/Panel").visible:finish(1,"missing menu");return false
			name.text="hosty" if role=="host" else "guest"
			press("Host" if role=="host" else "Join");phase="join"
		"join":
			if not game.probe_ready() or game.probe_players()!=2:return false
			if not roster.contains("hosty") or not roster.contains("guest"):return false
			game.on_start();acted=now;phase="waiting"
		"waiting":
			if now-acted<1200:return false
			if game.lobby_probe("phase",0)!=0 or game.campaign_probe("mobs",1)!=0:finish(1,"started before ready");return false
			if game.campaign_probe("rejected",1)<1:finish(1,"early/nonleader Start not rejected");return false
			if start.visible!=(role=="host") or (role=="host" and not start.disabled):finish(1,"Start availability");return false
			game.on_chat("found a torch" if role=="host" else "on my way");press("Ready");phase="ready"
		"ready":
			if game.lobby_probe("ready",0)!=3:return false
			if not lines.contains("hosty: found a torch") or not lines.contains("guest: on my way"):return false
			if role=="client":name.text="Guest Scout";press("Ready")
			phase="rename"
		"rename":
			if not roster.contains("Guest Scout") or game.lobby_probe("ready",0)!=1:return false
			if role=="host":
				if not start.disabled:finish(1,"unready rename did not block start");return false
				signal_file("rename_seen")
			phase="ready_again"
		"ready_again":
			if not has_file("rename_seen"):return false
			if role=="client":press("Ready")
			phase="start"
		"start":
			if game.lobby_probe("ready",0)!=3:return false
			if role=="host":press("Start")
			phase="playing"
		"playing":
			if game.lobby_probe("phase",0)!=1:return false
			if game.get_node("Lobby/Panel").visible or not game.get_node("Stage").visible:finish(1,"play transition");return false
			if role=="client":game.walk_to(300,180);game.on_chat("ready to descend")
			phase="walk"
		"walk":
			if role=="client":
				if not game.probe_near(300,180):return false
				game.loot(0)
			phase="loot"
		"loot":
			if game.campaign_probe("bag_gems",2)!=3:return false
			if not lines.contains("guest: on my way") or not lines.contains("Guest Scout: ready to descend"):finish(1,"chat attribution after rename");return false
			game.show_score(true);acted=now;phase="score"
		"score":
			if now-acted<100:return false
			if game.get_node("Social/Scoreboard/Column/Grid/Row1_0").text!="Guest Scout" or game.get_node("Social/Scoreboard/Column/Grid/Row1_5").text!="3":finish(1,"named scoreboard");return false
			if game.lobby_probe("profile_pending",0)!=0:return false
			signal_file("done-"+role);acted=now;phase="linger"
		"linger":
			if not has_file("done-host") or not has_file("done-client"):return false
			if now-acted<(1500 if role=="host" else 500):return false
			print("REPLAY_CAVE_LOBBY_OK role=",role," names=hosty/Guest_Scout start_guarded=true rename_retained=true loot=3")
			if role=="host":
				press("Leave")
				if game.probe_ready() or not game.get_node("Lobby/Panel/Column/Buttons/Solo").visible:finish(1,"leave did not return to menu");return false
				press("Solo");phase="repeat_ready"
			else:finish(0)
		"repeat_ready":
			if not game.probe_ready() or game.probe_players()!=1 or not roster.contains("hosty"):return false
			press("Ready");phase="repeat_start"
		"repeat_start":
			if game.lobby_probe("ready",0)!=1:return false
			press("Start");phase="repeat_playing"
		"repeat_playing":
			if game.lobby_probe("phase",0)!=1:return false
			press("Leave");print("REPLAY_CAVE_LOBBY_REOPEN_OK");finish(0)
	return false
