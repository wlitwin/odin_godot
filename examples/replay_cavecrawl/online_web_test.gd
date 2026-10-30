extends Node
var game:Node
var last_command:=0
var hold_restore:=false
var held_restore:=false
func _ready():
	if not OS.has_feature("web") or not bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('online_test')",true)):
		set_process(false);return
	game=get_parent()
	hold_restore=bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('contention_hold')",true))
func _process(_dt:float):
	var request=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(globalThis.onlineCommand||null)",true)))
	if request is Dictionary and int(request.id)!=last_command:
		last_command=int(request.id)
		match str(request.kind):
			"press":game.get_node("Lobby/Panel/Column/Buttons/"+str(request.value)).pressed.emit()
			"name":game.get_node("Lobby/Panel/Column/Name").text=str(request.value)
			"invite":game.get_node("Lobby/Panel/Column/PartyCode").text=str(request.value)
			"walk":game.walk_to(float(request.x),float(request.y))
			"loot":game.loot(int(request.value))
			"handoff":game.handoff()
			"save":game.save()
			"pause_control":hold_restore=false;held_restore=false;game.pause_control(bool(request.value))
	if hold_restore and game.online_probe("restore_phase")==3:
		hold_restore=false;held_restore=true;game.pause_control(true)
	var ready:bool=game.probe_ready()
	var state={"command":last_command,"failed":game.online_probe("failed"),"recent":game.online_probe("recent"),"profile_ready":game.lobby_probe("profile_ready",0),
		"relay_revision":game.online_probe("relay_revision"),"relay_error":game.online_probe("relay_error"),
		"save_completed":game.online_probe("save_completed"),"save_revision":game.online_probe("save_revision"),"save_epoch":game.online_probe("save_epoch"),
		"save_error":game.online_probe("save_error"),"save_uncertain":game.online_probe("save_uncertain"),"save_tick":game.online_probe("save_tick"),
		"restore_phase":game.online_probe("restore_phase"),"restore_error":game.online_probe("restore_error"),"restore_publication":game.online_probe("restore_publication"),"restore_tick":game.online_probe("restore_tick"),
		"authority":game.online_probe("authority"),"restore_candidate_tick":game.online_probe("restore_candidate_tick"),"restore_held":held_restore,
		"ready":ready,"players":game.probe_players() if ready else 0,"phase":game.lobby_probe("phase",0),"readiness":game.lobby_probe("ready",0),
		"epoch":game.probe_epoch() if ready else 0,"steady":game.probe_steady() if ready else false,"prepared":game.probe_prepared_tick(),
		"lost":game.probe_lost_ticks(),"incarnation":game.probe_incarnation(),"invited":game.online_probe("invited"),
		"near":game.probe_near(300,180) if ready else false,"gems":game.campaign_probe("bag_gems",2) if ready else 0,
		"host_gems":game.campaign_probe("bag_gems",1) if ready else 0,
		"safe":game.probe_near(120,330) if ready else false,
		"guest_torches":game.campaign_probe("bag_torches",2) if ready else 0,
		"rtc_id":game.probe_signaling(2),"rtc_resumes":game.probe_signaling(0),
		"torches":game.campaign_probe("bag_torches",1) if ready else 0,"invite":game.get_node("Lobby/Panel/Column/PartyCode").text,
		"notice":game.get_node("Lobby/Panel/Column/Status").text,"name1":game.lobby_name(1),"name2":game.lobby_name(2)}
	JavaScriptBridge.eval("globalThis.onlineStatus="+JSON.stringify(state),true)
