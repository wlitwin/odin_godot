extends SceneTree
var game:Node
var role:=""
var phase:="menu"
var work:=""
var started:=0
var closing:=false
var saved_shots:=0
var last_frame:=0
var last_trace:=0
func _initialize():
	role=OS.get_environment("RSY_ASSET_RESTORE_ROLE");work=OS.get_environment("RSY_ASSET_RESTORE_WORK")
	game=load("res://main.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
func p(key:String,seat:int=1)->int:return game.probe(key,seat)
func press(path:String):game.get_node("UI/Lobby/Scroll/Layout/"+path).pressed.emit()
func write(name:String,value:String):
	var file:=FileAccess.open(work+"/"+name,FileAccess.WRITE);file.store_string(value);file.close()
func finish(code:int,why:String=""):
	if closing:return
	if why!="":print("RSY_ASSET_RESTORE_FAIL role=",role," phase=",phase," ",why)
	closing=true;game.queue_free();game=null;await process_frame;await process_frame;quit(code)
func _process(_dt:float)->bool:
	if closing:return false
	var now:=Time.get_ticks_msec()
	if last_frame>0 and now-last_frame>100:print("RSY_ASSET_FRAME_GAP phase=",phase," ms=",now-last_frame," lease=",game.party_probe("lease_remaining"))
	last_frame=now
	if role=="restored" and phase=="restored" and now-last_trace>1000:
		last_trace=now
		print("RSY_RESTORE_TRACE phase=",game.party_probe("restore_phase")," lease=",game.party_probe("lease_remaining")," rpc_pending=",game.party_probe("rpc_pending")," lease_pending=",game.party_probe("lease_pending")," verb=",game.party_probe("rpc_verb")," result=",game.party_probe("rpc_result")," sequence=",game.party_probe("rpc_sequence")," after=",game.party_probe("restore_refresh_after")," renewed=",game.party_probe("restore_renewed"))
	if Time.get_ticks_msec()-started>65000:finish(1,"timeout");return false
	if game.party_probe("failed") or game.party_probe("restore_error") or game.party_probe("save_error"):finish(1,"party=%d restore=%d save=%d cache=%d save_phase=%d room_phase=%d control=%d epoch=%d" %[game.party_probe("failed"),game.party_probe("restore_error"),game.party_probe("save_error"),game.party_probe("asset_bytes"),game.party_probe("save_phase"),game.party_probe("room_phase"),game.party_probe("control_error"),p("epoch")]);return false
	if not game.party_probe("recent"):return false
	match phase:
		"menu":
			if game.party_probe("asset_bytes")!=0:finish(1,"cache was not empty before join");return false
			if role=="source":press("Doors/Host");phase="joined"
			else:print("RSY_ASSET_RESTORE_EMPTY_CACHE_OK");press("Doors/Rejoin");phase="restored"
		"joined":
			if not p("ready") or p("cores",1)!=7 or p("parts",1)!=2:return false
			game.dev_drive(0,0,false);press("Actions/Ready");phase="ready"
		"ready":
			if not p("marked_ready",1):return false
			press("Actions/Start");phase="yard"
		"yard":
			if p("stage")!=1 or not p("in_yard",1) or p("spray_bytes",1)==0:return false
			if not game.stamp():return false
			phase="stamp"
		"stamp":
			if p("spray_stamp",1)==0:return false
			if not game.save_run():return false
			phase="save"
		"save":
			if game.party_probe("save_completed")<1:return false
			write("saved.json",JSON.stringify({"tick":game.party_probe("save_tick"),"spray":game.spray_id(1),"bytes":p("spray_bytes",1),"stamp":p("spray_stamp",1),"incarnation":game.party_probe("incarnation")}))
			print("RSY_ASSET_RESTORE_SOURCE_OK tick=",game.party_probe("save_tick")," asset_bytes=",p("spray_bytes",1)," stamp=",p("spray_stamp",1));finish(0)
		"restored":
			if not p("ready") or not game.party_probe("steady") or p("epoch")!=2:return false
			var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(work+"/saved.json"))
			if not game.party_probe("restore_publication") or game.party_probe("restore_tick")!=int(saved.tick) or game.party_probe("incarnation")<=int(saved.incarnation):finish(1,"wrong restored authority");return false
			if game.spray_id(1)!=str(saved.spray) or p("spray_stamp",1)!=int(saved.stamp) or not p("spray_cached",1):finish(1,"spray did not survive");return false
			if p("cores",1)!=7 or p("parts",1)!=2 or not game.party_probe("identity_separate"):finish(1,"profile or identity changed");return false
			print("RSY_ASSET_RESTORE_RESUMED_OK epoch=2 incarnation=",game.party_probe("incarnation")," tick=",game.party_probe("restore_tick")," asset_bytes=",game.party_probe("asset_bytes")," stamp=",p("spray_stamp",1))
			game.dev_drive(0,0,false);saved_shots=p("shots",1);game.dev_aim(1,0,true);phase="fire"
		"fire":
			if p("shots",1)<=saved_shots:return false
			game.dev_aim(1,0,false)
			if not game.save_run():return false
			print("RSY_ASSET_SAVE_AGAIN_BEGIN lease=",game.party_probe("lease_remaining")," ms=",Time.get_ticks_msec()-started)
			phase="saved_again"
		"saved_again":
			if game.party_probe("save_completed")<1 or game.party_probe("save_revision")<2:return false
			print("RSY_ASSET_RESTORE_CONTINUED_OK epoch=2 revision=",game.party_probe("save_revision")," shots=",p("shots",1)," asset_bytes=",game.party_probe("asset_bytes"));finish(0)
	return false
