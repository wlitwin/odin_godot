extends SceneTree
var game:Node
var source:=false
var slot:=0
var phase:="menu"
var folder:=""
var started:=0
var closing:=false
var winner:=false
func _initialize():
	source=OS.get_environment("CAVE_CONTENTION_PHASE")=="source";slot=int(OS.get_environment("CAVE_CONTENTION_SLOT"));folder=OS.get_environment("CAVE_CONTENTION_DIR")
	game=load("res://cave.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
func p(key:String)->int:return game.online_probe(key)
func exists(name:String)->bool:return FileAccess.file_exists(folder+"/"+name)
func write(name:String,value:String="done"):
	var file:=FileAccess.open(folder+"/"+name,FileAccess.WRITE);file.store_string(value);file.close()
func press(name:String):game.get_node("Lobby/Panel/Column/Buttons/"+name).pressed.emit()
func finish(code:int,why:String=""):
	if closing:return
	if why!="":print("CAVE_RESTORE_CONTENTION_FAIL slot=",slot," phase=",phase," ",why)
	closing=true;game.queue_free();game=null;await process_frame;await process_frame;quit(code)
func _process(_dt:float)->bool:
	if closing:return false
	if Time.get_ticks_msec()-started>90000:finish(1,"timeout");return false
	if p("failed") or p("restore_error"):finish(1,"restore error "+str(p("restore_error")));return false
	if not p("recent") or not game.lobby_probe("profile_ready",0):return false
	match phase:
		"menu":
			game.get_node("Lobby/Panel/Column/Name").text="Contender "+str(slot)
			if not source:press("Rejoin");phase="preparing"
			elif slot==1:press("Host");phase="invite"
			elif exists("invite"):
				game.get_node("Lobby/Panel/Column/PartyCode").text=FileAccess.get_file_as_string(folder+"/invite");press("Join");phase="joined"
		"invite":
			if not p("invited") or not game.probe_ready():return false
			write("invite",game.get_node("Lobby/Panel/Column/PartyCode").text);phase="joined"
		"joined":
			if not game.probe_ready() or game.probe_players()!=2:return false
			if game.lobby_name(1)!="Contender 1" or game.lobby_name(2)!="Contender 2":return false
			press("Ready");phase="ready"
		"ready":
			if game.lobby_probe("ready",0)!=3:return false
			if slot==1:press("Start")
			phase="save"
		"save":
			if game.lobby_probe("phase",0)!=1:return false
			if slot==1:
				if not game.save():return false
				phase="saved"
			else:phase="source_wait"
		"saved":
			if p("save_completed")<1:return false
			write("saved.json",JSON.stringify({"tick":p("save_tick"),"revision":p("save_revision")}));print("CAVE_RESTORE_CONTENTION_SAVED tick=",p("save_tick"));finish(0)
		"source_wait":
			if exists("saved.json"):finish(0)
		"preparing":
			if p("restore_phase")!=3:return false
			if game.probe_ready():finish(1,"runtime started before race barrier");return false
			var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/saved.json"))
			if p("restore_candidate_tick")!=int(saved.tick):finish(1,"different candidate");return false
			game.pause_control(true);write("prepared-"+str(slot));print("CAVE_RESTORE_CONTENTION_PREPARED slot=",slot," tick=",p("restore_candidate_tick"));phase="barrier"
		"barrier":
			if not exists("release") and not exists("release-"+str(slot)):return false
			game.pause_control(false);phase="racing"
		"racing":
			if game.probe_ready() and p("authority"):write("granted-"+str(slot))
			if not game.probe_ready() or not game.probe_steady() or game.probe_players()!=2:return false
			if game.probe_epoch()!=2:finish(1,"unexpected extra grant");return false
			winner=p("authority")==1
			if winner and p("restore_publication")!=1:finish(1,"winner did not restore");return false
			if not winner and p("restore_publication")!=0:finish(1,"loser installed an authority");return false
			write("ready-"+str(slot),JSON.stringify({"slot":slot,"winner":winner,"epoch":game.probe_epoch()}))
			phase="action"
		"action":
			if not exists("ready-1") or not exists("ready-2"):return false
			if not winner:game.walk_to(300,180);phase="walk"
			else:phase="confirm"
		"walk":
			if not game.probe_near(300,180):return false
			game.loot(0);phase="confirm"
		"confirm":
			var total:int=game.campaign_probe("bag_gems",1)+game.campaign_probe("bag_gems",2)
			if total!=3:return false
			if winner:
				if not game.save():return false
				phase="save_again"
			else:write("follower-action");phase="wait"
		"save_again":
			if p("save_completed")<1:return false
			if p("save_epoch")!=2 or p("save_revision")!=2:finish(1,"publication after race");return false
			write("winner-done");print("CAVE_RESTORE_CONTENTION_WINNER_OK slot=",slot," epoch=2 revision=2 gems=3");finish(0)
		"wait":
			if exists("winner-done"):print("CAVE_RESTORE_CONTENTION_FOLLOWER_OK slot=",slot," epoch=2 gems=3");finish(0)
	return false
