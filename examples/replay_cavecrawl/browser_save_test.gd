extends Node
var game:Node
var mode:=""
var phase:="boot"
var started:=0
var last_receipt:=0
var ready_sent:=false
var start_sent:=false
func param(key:String)->String:return str(JavaScriptBridge.eval("new URLSearchParams(location.search).get("+JSON.stringify(key)+") || ''",true))
func _ready():
	if not OS.has_feature("web"):set_process(false);return
	mode=param("save_test");if mode.is_empty():set_process(false);return
	game=get_parent();started=Time.get_ticks_msec()
func fail(why:String):
	print("CAVE_BROWSER_SAVE_FAIL ",why," phase=",phase," id_error=",game.browser_probe("identity_error")," save_error=",game.browser_probe("save_error")," store_error=",game.browser_probe("store_error"))
	set_process(false)
func result(event:String):
	var value:={"event":event,"runner_ready":game.probe_ready(),"slot":game.browser_slot(),"tick":str(game.probe_saved_tick()),"hash":str(game.probe_saved_hash()),"restored_tick":str(game.probe_restored_tick()),"restored_hash":str(game.probe_restored_hash()),"revision":str(game.browser_probe("revision")),"epoch":game.probe_epoch(),"name":game.lobby_name(1),"slot_phase":game.browser_probe("save_phase"),"slot_error":game.browser_probe("save_error"),"store_error":game.browser_probe("store_error"),"identity_error":game.browser_probe("identity_error")}
	JavaScriptBridge.eval("globalThis.caveSaveResult="+JSON.stringify(value),true);print("CAVE_BROWSER_SAVE_EVENT ",JSON.stringify(value))
func _process(_dt:float):
	if phase!="observe" and Time.get_ticks_msec()-started>45000:fail("timeout");return
	var command:=str(JavaScriptBridge.eval("globalThis.caveSaveCommand || ''",true))
	if command!="":
		JavaScriptBridge.eval("globalThis.caveSaveCommand=''",true)
		if command=="save":
			last_receipt=game.browser_probe("receipt")
			if not game.save():result("submit_refused")
			else:phase="manual_save"
		elif command=="solo":game.on_solo()
		elif command=="status":result("status")
	match phase:
		"boot":
			if mode=="bad_identity":
				if game.browser_probe("identity_error")>0:result("identity_failed");phase="observe"
				return
			if game.lobby_probe("profile_ready",0)!=1 or game.browser_probe("ready")!=1:return
			if mode=="identity":result("identity_ready");phase="observe";return
			if mode=="bad_archive":
				if game.browser_probe("save_error")==0:fail("corrupt archive accepted");return
				result("archive_failed");phase="observe";return
			if mode=="create":game.on_solo();phase="staging"
			else:
				if game.browser_probe("has_save")!=1:fail("save missing");return
				game.get_node("Lobby/Panel/Column/Buttons/Resume").pressed.emit();phase="resume"
		"staging":
			if not game.probe_ready() or game.lobby_name(1)!="Vault Runner":return
			if not ready_sent:game.get_node("Lobby/Panel/Column/Buttons/Ready").pressed.emit();ready_sent=true
			if game.lobby_probe("ready",0)!=1:return
			if not start_sent:game.get_node("Lobby/Panel/Column/Buttons/Start").pressed.emit();start_sent=true
			if game.lobby_probe("phase",0)!=1:return
			game.walk_to(300,180);phase="chest"
		"chest":
			if game.probe_near(300,180):game.loot(0);phase="loot"
		"loot":
			if game.campaign_probe("bag_gems",1)!=3:return
			game.walk_to(560,180);phase="door"
		"door":
			if game.probe_near(560,180):game.door();phase="opened"
		"opened":
			if not game.probe_door():return
			game.throw(1,0);phase="rock"
		"rock":
			if game.campaign_probe("rocks",1)<1:return
			last_receipt=game.browser_probe("receipt")
			game.get_node("Lobby/Panel/Column/Buttons/Save").pressed.emit();phase="saved"
		"saved":
			if game.browser_probe("receipt")==last_receipt:return
			if game.browser_probe("save_ok")!=1:fail("initial write failed");return
			result("saved");phase="observe"
		"resume":
			if not game.probe_ready():return
			if param("expected_hash")!="" and str(game.probe_restored_hash())!=param("expected_hash"):fail("restored frame hash");return
			if param("expected_tick")!="" and str(game.probe_restored_tick())!=param("expected_tick"):fail("restored tick");return
			if game.probe_bag()!=3 or (mode!="idle" and not game.probe_door()) or game.lobby_name(1)!="Vault Runner":fail("restored gameplay/profile");return
			if mode=="idle":result("resumed");phase="observe";return
			game.door();phase="continued"
		"continued":
			if game.probe_door() or game.probe_accepted()<1:return
			last_receipt=game.browser_probe("receipt");game.save();phase="manual_save"
		"manual_save":
			if game.browser_probe("receipt")==last_receipt:return
			result("saved" if game.browser_probe("save_ok")==1 else "write_failed");phase="observe"
		"observe":pass
