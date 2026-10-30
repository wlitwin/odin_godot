extends SceneTree
var game:Node
var role:=""
var phase:="menu"
var work:=""
var started:=0
var closing:=false
var asset_wait:=false
func _initialize():
	role=OS.get_environment("RSY_ONLINE_ROLE");work=OS.get_environment("RSY_ONLINE_WORK")
	game=load("res://main.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
func p(key:String,seat:int=1)->int:return game.probe(key,seat)
func press(path:String):game.get_node("UI/Lobby/Scroll/Layout/"+path).pressed.emit()
func exists(name:String)->bool:return FileAccess.file_exists(work+"/"+name)
func write(name:String,value:String="done"):
	var f:=FileAccess.open(work+"/"+name,FileAccess.WRITE);f.store_string(value);f.close()
func finish(code:int,why:String=""):
	if closing:return
	if why!="":print("RSY_ONLINE_FAIL role=",role," phase=",phase," ",why)
	closing=true;game.queue_free();game=null;await process_frame;await process_frame;quit(code)
func _process(_dt:float)->bool:
	if closing:return false
	if Time.get_ticks_msec()-started>65000:finish(1,"timeout");return false
	if game.party_probe("failed"):finish(1,game.get_node("UI/Lobby/Scroll/Layout/Party/Notice").text);return false
	if p("profile_error"):finish(1,"progression profile");return false
	if not game.party_probe("recent"):return false
	match phase:
		"menu":
			if role=="host":
				press("Doors/Host");game.on_solo()
				if p("ready"):finish(1,"competing solo opened during enrollment");return false
				phase="invite"
			elif role=="returned":press("Doors/Rejoin");phase="returned"
			elif exists("invite"):
				game.get_node("UI/Lobby/Scroll/Layout/Party/Code").text=FileAccess.get_file_as_string(work+"/invite");press("Doors/Join");phase="joined"
		"invite":
			if not game.party_probe("invited") or not p("ready"):return false
			write("invite",game.get_node("UI/Lobby/Scroll/Layout/Party/Code").text);phase="joined"
		"joined":
			if not p("ready") or p("players")!=2:return false
			var seat:=1 if role=="host" else 2
			if p("cores",seat)!=7 or p("parts",seat)!=2 or p("ability0",seat)!=(5 if role=="host" else 4):return false
			if not game.party_probe("identity_separate"):finish(1,"network identity replaced profile identity");return false
			game.dev_drive(0,0,false)
			if role=="guest":game.dev_asset_pause(true)
			press("Actions/Ready");phase="ready"
		"ready":
			if not p("marked_ready",1) or not p("marked_ready",2):return false
			if role=="host":press("Actions/Start")
			phase="yard"
		"yard":
			if p("stage")!=1 or not p("in_yard",1) or not p("in_yard",2):return false
			if role=="host":
				if p("spray_bytes",1)==0:return false
				if not game.stamp():finish(1,"initial spray");return false
				phase="asset-sync";return false
			phase="backup"
		"asset-sync":
			if not exists("assets-ready"):return false
			if not game.dev_cast(0,500,1040,true) or not game.dev_cast(1,800,1040,true):finish(1,"initial combat");return false
			phase="backup"
		"backup":
			if role=="guest":
				if not asset_wait and p("asset_prepare_wait"):
					if p("backup_spray"):finish(1,"prepared unavailable spray");return false
					asset_wait=true;game.dev_asset_pause(false);print("RSY_ONLINE_ASSET_BARRIER_OK")
				if asset_wait and p("spray_cached",1):write("assets-ready")
				if asset_wait and p("active_backup") and p("backup_spray"):write("prepared")
			elif exists("prepared") and p("lobs")>0 and p("zones")>0:
				print("RSY_ONLINE_HANDOFF_BEGIN tick=",p("head")," lobs=",p("lobs")," zones=",p("zones")," mobs=",p("mobs"))
				if not game.handoff():return false
				phase="migration"
			if p("epoch")==2:phase="migration"
		"migration":
			if p("epoch")!=2 or not p("recovery_ready"):return false
			if p("lost_ticks")!=0 or p("cores",2)!=7 or p("parts",2)!=2:finish(1,"recovery changed state");return false
			if role=="host":
				if not p("profile_loaded"):finish(1,"profile not retained");return false
				print("RSY_ONLINE_HANDOFF_OK epoch=2 lost=0");finish(0)
			else:
				if not p("restored_exact") or not p("restored_active") or not p("spray_cached",1):finish(1,"complete asset-aware restore");return false
				phase="wait-return"
		"wait-return":
			if not exists("returned-done"):return false
			if p("shots",1)<1:return false
			if p("cores",2)!=7 or p("parts",2)!=2:finish(1,"progression changed");return false
			print("RSY_ONLINE_GUEST_OK profile_preserved=true spray_recovered=true returned_action=true");finish(0)
		"returned":
			if not p("ready") or p("epoch")!=2 or not game.party_probe("steady") or p("players")!=2:return false
			if p("seat")!=1 or game.party_probe("incarnation")<3:return false
			if p("look",1)!=2 or p("iron",1)!=1 or p("parts",1)!=2 or p("cores",1)!=7 or not p("profile_loaded"):finish(1,"saved profile changed");return false
			if game.get_node("UI/Lobby/Scroll/Layout/Party/Code").text!=FileAccess.get_file_as_string(work+"/invite"):finish(1,"invite changed");return false
			if not game.party_probe("identity_separate"):finish(1,"profile identity changed");return false
			game.dev_aim(1,0,true);phase="fire"
		"fire":
			if p("shots",1)<1:return false
			game.dev_aim(1,0,false);write("returned-done");print("RSY_ONLINE_REJOIN_OK incarnation=",game.party_probe("incarnation")," loadout_preserved=true invite_stable=true");phase="linger"
		"linger":
			if exists("guest-done"):finish(0)
	return false
