extends SceneTree
var game:Node
var member:=0
var phase:="ready"
var started:=0
var directory:=""
var sent:=false
var durable:=-1
var closing:=false
func _initialize():
	member=int(OS.get_environment("REPLAY_CAVE_MEMBER"));directory=OS.get_environment("REPLAY_MIGRATION_DIR")
	game=load("res://cave.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
func signal_file(name:String):
	var file:=FileAccess.open(directory+"/"+name,FileAccess.WRITE);file.store_string("ready");file.close()
func finish(code:int,why:String=""):
	if closing:return
	if why!="":print("REPLAY_MIGRATION_FAIL waiting_lobby member=",member," ",why)
	closing=true;game.queue_free();game=null;await process_frame;await process_frame;quit(code)
func _process(_dt:float)->bool:
	if closing:return false
	if Time.get_ticks_msec()-started>38000:finish(1,"timeout "+phase);return false
	if not game.probe_ready() or not game.probe_steady():return false
	match phase:
		"ready":
			if game.probe_players()!=3:return false
			for id in [1,2,3]:
				if game.lobby_name(id)!="Party %d"%id:return false
			if not sent:game.on_ready_button();sent=true
			if game.lobby_probe("ready",0)!=7:return false
			if game.lobby_probe("phase",0)!=0 or game.campaign_probe("mobs",1)!=0:finish(1,"world advanced in lobby");return false
			if member==1:
				if durable<0:durable=game.probe_head()
				if game.probe_backup_tick()<durable or game.probe_prepared_tick()<durable:return false
				print("REPLAY_LOBBY_DURABLE tick=",durable);signal_file("kill_owner")
			phase="migration";sent=false
		"migration":
			if game.probe_epoch()!=2 or game.probe_players()!=2:return false
			if game.lobby_probe("phase",0)!=0 or game.lobby_probe("leader",0)!=2:finish(1,"leader or phase after crash");return false
			for id in [2,3]:
				if game.lobby_name(id)!="Party %d"%id:finish(1,"lost name");return false
			if not sent and game.lobby_probe("ready",0)&(1<<(member-1))==0:game.on_ready_button();sent=true
			if game.lobby_probe("ready",0)!=6:return false
			if member==2:game.on_start()
			phase="playing"
		"playing":
			if game.lobby_probe("phase",0)!=1:return false
			print("REPLAY_LOBBY_RECOVERED_START_OK member=",member," leader=2")
			if member==3:game.walk_to(300,180)
			phase="walk"
		"walk":
			if member==3:
				if not game.probe_near(300,180):return false
				game.loot(0)
			phase="loot"
		"loot":
			if game.probe_chest(0)!=0 or game.probe_gems()!=3 or game.campaign_probe("bag_gems",3)!=3:return false
			if member==3:
				if game.probe_bag()!=3:return false
				signal_file("guest_done");print("REPLAY_MIGRATION_GUEST_OK waiting_lobby epoch=2");finish(0)
			elif FileAccess.file_exists(directory+"/guest_done"):
				print("REPLAY_MIGRATION_MEMBER_OK member=2 waiting_lobby epoch=2");finish(0)
	return false
