extends "res://migration_test.gd"
var lobby_started:=false
var lobby_ready_sent:=false
var lobby_handoff:=false
var lobby_start_sent:=false
func _process(dt:float)->bool:
	if Time.get_ticks_msec()-started>38000:return fail("lobby migration timeout")
	if not lobby_started:
		if not game.probe_ready() or game.lobby_probe("profile_ready",0)!=1:return false
		var roster:String=game.get_node("Lobby/Panel/Column/Roster").text
		for id in [1,2,3]:
			if not roster.contains("Party %d"%id):return false
		if not lobby_ready_sent:game.on_ready_button();lobby_ready_sent=true
		if game.lobby_probe("ready",0)!=7:return false
		if not lobby_start_sent and member==1:game.on_start();lobby_start_sent=true
		if game.lobby_probe("phase",0)!=1:return false
		lobby_started=true
	if game.probe_epoch()==2 and game.probe_steady() and not lobby_handoff:
		var roster:String=game.get_node("Lobby/Panel/Column/Roster").text
		for id in [2,3]:
			if game.lobby_name(id)!="Party %d"%id:return fail("profile lost after migration")
		print("REPLAY_CAVE_LOBBY_MIGRATION_OK member=",member," leader=",game.lobby_probe("leader",0)," run=",game.lobby_probe("run",0))
		lobby_handoff=true
	return super._process(dt)
