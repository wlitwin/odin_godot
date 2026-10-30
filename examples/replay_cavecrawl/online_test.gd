extends SceneTree
var game:Node
var role:=""
var phase:="menu"
var started:=0
var work:=""
var closing:=false
var checkpoint_checks:=false
var save_before:=0
func _initialize():
	role=OS.get_environment("CAVE_ONLINE_ROLE");work=OS.get_environment("CAVE_ONLINE_WORK")
	checkpoint_checks=OS.get_environment("CAVE_ONLINE_CHECKPOINTS")=="1"
	game=load("res://cave.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
func press(name:String):game.get_node("Lobby/Panel/Column/Buttons/"+name).pressed.emit()
func write(name:String,value:String="done"):
	var file:=FileAccess.open(work+"/"+name,FileAccess.WRITE);file.store_string(value);file.close()
func exists(name:String)->bool:return FileAccess.file_exists(work+"/"+name)
func finish(code:int,why:String=""):
	if closing:return
	if why!="":print("CAVE_ONLINE_FAIL role=",role," phase=",phase," ",why)
	closing=true;game.queue_free();game=null;await process_frame;await process_frame;quit(code)
func _process(_dt:float)->bool:
	if closing:return false
	if Time.get_ticks_msec()-started>60000:finish(1,"timeout");return false
	if game.online_probe("failed")!=0:finish(1,game.get_node("Lobby/Panel/Column/Status").text);return false
	if game.lobby_probe("profile_ready",0)!=1 or game.online_probe("recent")!=1:return false
	match phase:
		"menu":
			game.get_node("Lobby/Panel/Column/Name").text="Host Scout" if role!="guest" else "Guest Scout"
			if role=="host":press("Host");phase="invite"
			elif role=="returned":press("Rejoin");phase="returned"
			elif exists("invite"):
				game.get_node("Lobby/Panel/Column/PartyCode").text=FileAccess.get_file_as_string(work+"/invite");press("Join");phase="joined"
		"invite":
			if game.online_probe("invited")!=1 or not game.probe_ready():return false
			var code:String=game.get_node("Lobby/Panel/Column/PartyCode").text
			if not code.begins_with("RP1."):finish(1,"invite missing");return false
			write("invite",code);phase="joined"
		"joined":
			if not game.probe_ready() or game.probe_players()!=2:return false
			if OS.get_environment("REPLAY_CAVE_ROOM_RELAY")=="1" and game.online_probe("relay_revision")<1:finish(1,"relay credential missing");return false
			if game.lobby_name(1)!="Host Scout" or game.lobby_name(2)!="Guest Scout":return false
			press("Ready");phase="ready"
		"ready":
			if game.lobby_probe("ready",0)!=3:return false
			if role=="host":press("Start")
			phase="playing"
		"playing":
			if game.lobby_probe("phase",0)!=1:return false
			if role=="guest":game.walk_to(300,180)
			phase="loot"
		"loot":
			if role=="guest" and game.probe_near(300,180):game.loot(0);phase="collected"
			elif role=="host":phase="collected"
		"collected":
			if game.campaign_probe("bag_gems",2)!=3:return false
			if role=="host":
				if game.probe_prepared_tick()<=0:return false
				if checkpoint_checks:
					save_before=game.online_probe("save_completed")
					if not game.save():return false
					phase="save_host";return false
				if not game.handoff():return false
			phase="migration"
		"save_host":
			if game.online_probe("save_error")!=0:finish(1,"host checkpoint error");return false
			if game.online_probe("save_completed")<=save_before:return false
			if game.online_probe("save_epoch")!=1 or game.online_probe("save_tick")<=0 or game.online_probe("save_uncertain")!=0:finish(1,"host checkpoint receipt");return false
			write("host-publication",str(game.online_probe("save_revision")))
			print("CAVE_ONLINE_CHECKPOINT_HOST_OK revision=",game.online_probe("save_revision")," tick=",game.online_probe("save_tick"))
			if not game.handoff():return false
			phase="migration"
		"migration":
			if game.probe_epoch()!=2 or not game.probe_steady():return false
			if game.campaign_probe("bag_gems",2)!=3:finish(1,"loot changed");return false
			if role=="host":
				print("CAVE_ONLINE_HANDOFF_OK epoch=2 lost=",game.probe_lost_ticks());write("host-done");finish(0)
			else:phase="wait_return"
		"wait_return":
			if not exists("returned-done"):return false
			if game.campaign_probe("bag_torches",1)<1:return false
			if game.campaign_probe("bag_gems",2)!=3:finish(1,"rejoin changed guest bag");return false
			if checkpoint_checks:
				save_before=game.online_probe("save_completed")
				if not game.save():return false
				phase="save_guest";return false
			print("CAVE_ONLINE_GUEST_OK epoch=2 gems=3 returned_action=true");finish(0)
		"save_guest":
			if game.online_probe("save_error")!=0:finish(1,"successor checkpoint error");return false
			if game.online_probe("save_completed")<=save_before:return false
			if game.online_probe("save_epoch")!=2 or game.online_probe("save_revision")<=int(FileAccess.get_file_as_string(work+"/host-publication")) or game.online_probe("save_uncertain")!=0:finish(1,"successor checkpoint receipt");return false
			print("CAVE_ONLINE_CHECKPOINT_SUCCESSOR_OK revision=",game.online_probe("save_revision")," epoch=2 tick=",game.online_probe("save_tick"))
			print("CAVE_ONLINE_GUEST_OK epoch=2 gems=3 returned_action=true");finish(0)
		"returned":
			if not game.probe_ready() or game.probe_epoch()!=2 or not game.probe_steady():return false
			if game.probe_players()!=2 or game.probe_incarnation()<3:return false
			if checkpoint_checks and game.save():finish(1,"follower published as host");return false
			if game.online_probe("invited")!=1:finish(1,"invite was not recovered");return false
			if game.get_node("Lobby/Panel/Column/PartyCode").text!=FileAccess.get_file_as_string(work+"/invite"):finish(1,"invite changed");return false
			game.walk_to(300,180);phase="return_walk"
		"return_walk":
			if not game.probe_near(300,180):return false
			game.loot(1);phase="return_action"
		"return_action":
			if game.campaign_probe("bag_torches",1)<1:return false
			print("CAVE_ONLINE_REJOIN_OK epoch=2 incarnation=",game.probe_incarnation()," invite_stable=true");write("returned-done");phase="linger"
		"linger":
			if exists("guest-done"):finish(0)
	return false
