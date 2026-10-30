extends SceneTree
var game:Node
var role:=""
var phase:="menu"
var work:=""
var started:=0
var closing:=false
var save_before:=0
func _initialize():
	role=OS.get_environment("CAVE_RESTORE_ROLE");work=OS.get_environment("CAVE_RESTORE_WORK")
	game=load("res://cave.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
func press(name:String):game.get_node("Lobby/Panel/Column/Buttons/"+name).pressed.emit()
func exists(name:String)->bool:return FileAccess.file_exists(work+"/"+name)
func write(name:String,value:String="done"):
	var file:=FileAccess.open(work+"/"+name,FileAccess.WRITE);file.store_string(value);file.close()
func finish(code:int,why:String=""):
	if closing:return
	if why!="":print("CAVE_PARTY_RESTORE_FAIL role=",role," phase=",phase," ",why)
	closing=true;game.queue_free();game=null;await process_frame;await process_frame;quit(code)
func _process(_dt:float)->bool:
	if closing:return false
	if Time.get_ticks_msec()-started>60000:finish(1,"timeout");return false
	if game.online_probe("failed")!=0 or game.online_probe("restore_error")!=0:finish(1,game.get_node("Lobby/Panel/Column/Status").text);return false
	if game.lobby_probe("profile_ready",0)!=1 or game.online_probe("recent")!=1:return false
	match phase:
		"menu":
			game.get_node("Lobby/Panel/Column/Name").text="Restore Scout" if role!="guest" else "New Scout"
			if role=="source":press("Host");phase="source_joined"
			elif role=="restored":press("Rejoin");phase="restored"
			elif exists("restored-ready"):
				game.get_node("Lobby/Panel/Column/PartyCode").text=FileAccess.get_file_as_string(work+"/invite");press("Join");phase="guest_joined"
		"source_joined":
			if not game.probe_ready() or game.online_probe("invited")!=1:return false
			write("invite",game.get_node("Lobby/Panel/Column/PartyCode").text)
			press("Ready");phase="source_ready"
		"source_ready":
			if game.lobby_probe("ready",0)!=1:return false
			press("Start");phase="source_playing"
		"source_playing":
			if game.lobby_probe("phase",0)!=1:return false
			game.walk_to(300,180);phase="source_walk"
		"source_walk":
			if not game.probe_near(300,180):return false
			game.loot(0);phase="source_loot"
		"source_loot":
			if game.campaign_probe("bag_gems",1)!=3:return false
			if not game.save():return false
			phase="source_save"
		"source_save":
			if game.online_probe("save_completed")<1:return false
			var tick:int=game.online_probe("save_tick")
			write("saved.json",JSON.stringify({"tick":tick,"revision":game.online_probe("save_revision"),"incarnation":game.probe_incarnation()}))
			print("CAVE_PARTY_RESTORE_SOURCE_OK epoch=1 tick=",tick," gems=3 incarnation=",game.probe_incarnation());finish(0)
		"restored":
			if not game.probe_ready() or not game.probe_steady():return false
			var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(work+"/saved.json"))
			if game.probe_epoch()!=2 or game.probe_incarnation()<=int(saved.incarnation) or game.online_probe("restore_publication")!=1:finish(1,"fresh authority was not restored");return false
			if game.online_probe("restore_tick")!=int(saved.tick) or game.campaign_probe("bag_gems",1)!=3 or game.lobby_probe("phase",0)!=1:finish(1,"saved world did not survive");return false
			print("CAVE_PARTY_RESTORE_RESUMED_OK epoch=2 tick=",game.online_probe("restore_tick")," gems=3 incarnation=",game.probe_incarnation()," known_lost=",game.probe_lost_ticks())
			write("restored-ready");phase="host_wait"
		"guest_joined":
			if not game.probe_ready() or game.probe_epoch()!=2 or game.probe_players()!=2:return false
			if game.campaign_probe("bag_gems",1)!=3:finish(1,"guest received wrong restored world");return false
			game.walk_to(300,180);phase="guest_walk"
		"guest_walk":
			if not game.probe_near(300,180):return false
			game.loot(1);phase="guest_action"
		"guest_action":
			if game.campaign_probe("bag_torches",2)<1:return false
			print("CAVE_PARTY_RESTORE_GUEST_OK epoch=2 gems=3 new_action=true");write("guest-action");phase="guest_wait"
		"host_wait":
			if not exists("guest-action") or game.campaign_probe("bag_torches",2)<1:return false
			if game.campaign_probe("bag_gems",1)!=3:finish(1,"post-restore join changed inventory");return false
			save_before=game.online_probe("save_completed")
			if not game.save():return false
			phase="host_save"
		"host_save":
			if game.online_probe("save_completed")<=save_before:return false
			if game.online_probe("save_epoch")!=2 or game.online_probe("save_revision")<2:finish(1,"restored host could not publish");return false
			print("CAVE_PARTY_RESTORE_CONTINUED_OK epoch=2 revision=",game.online_probe("save_revision")," gems=3 torches=",game.campaign_probe("bag_torches",2));write("host-done");finish(0)
		"guest_wait":
			if exists("host-done"):finish(0)
	return false
