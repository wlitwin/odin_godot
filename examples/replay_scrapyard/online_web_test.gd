extends Node
var game:Node
var last_command:=0
func _ready():
	if not OS.has_feature("web") or not bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('online_test')",true)):
		set_process(false);return
	game=get_parent()
func p(key:String,seat:int=1)->int:return game.probe(key,seat)
func _process(_dt:float):
	var q=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(globalThis.partyCommand||null)",true)))
	if q is Dictionary and int(q.id)!=last_command:
		last_command=int(q.id)
		match str(q.kind):
			"press":game.get_node("UI/Lobby/Scroll/Layout/"+str(q.value)).pressed.emit()
			"invite":game.get_node("UI/Lobby/Scroll/Layout/Party/Code").text=str(q.value)
			"drive":game.dev_drive(0,0,false)
			"pause_assets":game.dev_asset_pause(bool(q.value))
			"stamp":game.stamp()
			"cast":game.dev_cast(int(q.slot),float(q.x),float(q.y),true)
			"aim":game.dev_aim(1,0,bool(q.value))
			"handoff":game.handoff()
			"save":game.save_run()
	var state={"command":last_command,"failed":game.party_probe("failed"),"recent":game.party_probe("recent"),"invited":game.party_probe("invited"),
		"relay_revision":game.party_probe("relay_revision"),
		"steady":game.party_probe("steady"),"incarnation":game.party_probe("incarnation"),"separate":game.party_probe("identity_separate"),
		"invite":game.get_node("UI/Lobby/Scroll/Layout/Party/Code").text,"notice":game.get_node("UI/Lobby/Scroll/Layout/Party/Notice").text}
	for key in ["save_completed","save_revision","save_tick","save_error","save_phase","room_phase","lease_remaining","restore_error","restore_tick","restore_publication","asset_bytes"]:state[key]=game.party_probe(key)
	state["spray_id"]=game.spray_id(1)
	for key in ["ready","players","stage","seat","epoch","recovery_ready","lost_ticks","active_backup","asset_prepare_wait","backup_spray","restored_exact","restored_active","lobs","zones","profile_loaded","profile_error","profile_writing"]:state[key]=p(key)
	for seat in [1,2]:
		for key in ["look","iron","ability0","ability1","cores","parts","marked_ready","shots","spray_bytes","spray_cached","spray_stamp"]:state[key+str(seat)]=p(key,seat)
	JavaScriptBridge.eval("globalThis.partyStatus="+JSON.stringify(state),true)
