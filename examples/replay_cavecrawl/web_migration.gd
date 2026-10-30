extends Node
var lobby_enabled:=false
var lobby_ready_sent:=false
var lobby_start_sent:=false
var lobby_started:=false
var profile_check:=""
var presentation_ping_before:=-1
var social_enabled:=false
var social_before_sent:=false
var social_before_done:=false
var social_after_sent:=false
var social_after_done:=false
var game: Node
var member := 0
var mode := ""
var phase := "join"
var started := 0
var original_seat := 0
var durable_after := -1
var accepted_before := 0
var target_epoch := 2
var fenced_tick := -1
var fenced_since := 0
var fence_reported := false
var signaling_before := 0
var connection_before := 0
var signaling_pending := false
func _ready() -> void:
	if not OS.has_feature("web"): set_process(false); return
	var font: Font = get_parent().get_node("Title").get_theme_font("font")
	var fallbacks := font.fallbacks
	fallbacks.append(load("res://fonts/NotoEmoji.ttf"))
	font.fallbacks = fallbacks
	profile_check=str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('profile_check') || ''",true))
	if not profile_check.is_empty():game=get_parent();started=Time.get_ticks_msec();return
	lobby_enabled=bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('lobby') === '1'",true))
	mode = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('migration') || ''", true))
	if mode.is_empty(): set_process(false); return
	social_enabled=bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('social') === '1'",true))
	member = int(str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('member') || '0'", true)))
	game = get_parent()
	started = Time.get_ticks_msec()
	if bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('returned') === '1'", true)):
		phase = "return_join"
		original_seat = 1
func fail(message: String) -> void:
	print("RCB_FAIL member=",member," phase=",phase," ",message," room=",game.probe_room_phase()," epoch=",game.probe_epoch()," head=",game.probe_head())
	print("RCB_DIAGNOSTIC names=",game.get_node("Lobby/Panel/Column/Roster").text," profile=",game.get_node("Lobby/Panel/Column/Name").text," phase=",game.lobby_probe("phase",0)," ready=",game.lobby_probe("ready",0)," pref_pending=",game.lobby_probe("profile_pending",0)," pref_error=",game.lobby_probe("profile_error",0))
	set_process(false)
func conserved() -> bool:
	return game.probe_gems()==3 and game.probe_seat()==original_seat and (member!=3 or game.probe_bag()==3)
func guest_done() -> void:
	if not conserved(): fail("continued identity/inventory");return
	print("RCB_GUEST_OK epoch=",game.probe_epoch()," migrations=",game.probe_migrations()," checkpoint=",game.probe_recovery_tick()," lost=",game.probe_lost_ticks()," interruption_ms=",game.probe_interruption())
	phase="done"
func _process(_delta: float) -> void:
	if not profile_check.is_empty():
		if Time.get_ticks_msec()-started>15000:fail("profile reload timeout");return
		if game.lobby_probe("profile_ready",0)!=1 or game.lobby_probe("profile_pending",0)!=0:return
		if game.get_node("Lobby/Panel/Column/Name").text!=profile_check or game.lobby_probe("profile_error",0)!=0:fail("profile reload value");return
		print("RCB_PROFILE_RELOAD_OK name=",profile_check);set_process(false);return
	if phase!="done" and Time.get_ticks_msec()-started>160000: fail("timeout");return
	var command = str(JavaScriptBridge.eval("globalThis.rcbCommand || ''",true))
	if not command.is_empty():
		JavaScriptBridge.eval("globalThis.rcbCommand = ''",true)
		match command:
			"presentation_ping":
				presentation_ping_before=game.social_probe("marks");game.show_score(false);game.mark()
			"drop_signaling":
				signaling_before=game.probe_signaling(0);connection_before=game.probe_signaling(1)
				game.drop_signaling();signaling_pending=true
			"signal_action":
				target_epoch=1;game.walk_to(560.0,180.0);phase="resume_door"
			"pause_candidate":
				game.pause_control(true)
				print("RCB_CANDIDATE_PAUSED")
			"handoff":
				if not game.handoff(): fail("controlled handoff refused");return
				phase="loss_window"
			"resume_control":
				if fenced_tick<0: fail("partition did not fence owner");return
				game.pause_control(false)
				phase="migration"
			"handoff_again":
				durable_after=game.probe_head()
				phase="second_backup"
			"complete": guest_done()
	if presentation_ping_before>=0 and game.social_probe("marks")>presentation_ping_before:
		presentation_ping_before=-1;print("RCB_SOCIAL_PING_DRAWN")
	if signaling_pending and game.probe_signaling(0)>signaling_before:
		if game.probe_signaling(1)!=connection_before or game.probe_epoch()!=1 or game.probe_migrations()!=0: fail("signaling replaced gameplay");return
		signaling_pending=false
		print("RCB_SIGNAL_RESUMED member=",member," id=",game.probe_signaling(2)," resumes=",game.probe_signaling(0))
	if lobby_enabled and not lobby_barrier():return
	if social_enabled and not social_barrier():return
	match phase:
		"join":
			if game.probe_steady() and game.probe_players()==3:
				original_seat=game.probe_seat()
				if member==3: game.walk_to(300.0,180.0)
				phase="chest" if member==3 else "handoff"
		"chest":
			if game.probe_near(300.0,180.0): game.loot(0);phase="loot"
		"loot":
			if game.probe_bag()==3: game.walk_to(560.0,180.0);phase="door"
		"door":
			if game.probe_near(560.0,180.0): game.door();phase="handoff"
		"handoff":
			if not game.probe_steady() or not game.probe_door() or game.probe_gems()!=3: return
			if member==1:
				if durable_after<0: durable_after=game.probe_head()
				if game.probe_backup_tick()<durable_after or game.probe_prepared_tick()<durable_after: return
				print("RCB_DURABLE checkpoint=",game.probe_prepared_tick()," head=",game.probe_head())
				if mode in ["planned","repeat"]:
					if not game.handoff(): fail("handoff refused");return
				elif mode=="partition":
					game.pause_control(true)
					print("RCB_CONTROL_PARTITIONED")
					phase="partition_wait"
					return
			phase="wait_signal" if mode=="signaling" else "wait_loss_command" if mode=="successor_loss" and member==1 else "migration"
		"loss_window":
			if game.probe_room_phase() in [3,4]:
				print("RCB_SUCCESSOR_WINDOW phase=",game.probe_room_phase())
				phase="migration"
		"partition_wait":
			if game.probe_fenced():
				if fenced_tick<0: fenced_tick=game.probe_head();fenced_since=Time.get_ticks_msec()
				if game.probe_head()!=fenced_tick: fail("partitioned authority advanced after fencing");return
				if not fence_reported and Time.get_ticks_msec()-fenced_since>=500:
					fence_reported=true
					print("RCB_FENCED_STABLE head=",fenced_tick)
		"second_backup":
			if game.probe_backup_tick()>=durable_after and game.probe_prepared_tick()>=durable_after:
				if not game.handoff(): fail("second handoff refused");return
				target_epoch=3;phase="migration"
		"migration":
			if game.probe_epoch()==target_epoch and game.probe_steady():
				if not conserved(): fail("restored identity/inventory");return
				if target_epoch==3 and game.probe_migrations()!=2: fail("second migration count");return
				if member==3:
					game.walk_to(560.0,180.0);phase="resume_door"
				else:
					print("RCB_MEMBER_OK member=",member," epoch=",target_epoch," seat=",original_seat)
					phase="wait_second" if mode=="repeat" and target_epoch==2 else "done"
		"wait_second":
			if game.probe_epoch()==3: target_epoch=3;phase="migration"
		"resume_door":
			if game.probe_near(560.0,180.0):
				accepted_before=game.probe_accepted();game.door();phase="action"
		"action":
			if game.probe_accepted()>accepted_before:
				if not conserved(): fail("continued inventory");return
				if mode in ["repeat","return","partition"] and target_epoch==2:
					game.walk_to(560.0,40.0)
					print("RCB_GUEST_STAGE epoch=2")
					if mode=="repeat": target_epoch=3;phase="migration"
					else: phase="wait_complete"
				else: guest_done()
		"return_join":
			if game.probe_epoch()==2 and game.probe_steady() and game.probe_players()==3:
				if game.probe_incarnation()<=102 or game.probe_seat()!=1: fail("fresh incarnation/seat");return
				game.walk_to(300.0,180.0);phase="return_walk"
		"return_walk":
			if game.probe_near(300.0,180.0): game.loot(1);phase="return_action"
		"return_action":
			if game.probe_chest(1)==0 and game.probe_accepted()>0:
				if game.probe_gems()!=3: fail("return inventory");return
				print("RCB_RETURNED_OK incarnation=",game.probe_incarnation()," seat=",game.probe_seat())
				phase="done"

func social_barrier()->bool:
	if not game.probe_ready() or game.social_probe("ready")!=1:return false
	var input:LineEdit=game.get_node("Social/Chat/Input")
	var lines:String=game.get_node("Social/Chat/Lines").text
	if not social_before_done:
		if not social_before_sent:
			input.text="browser before member %d"%member;input.text_submitted.emit(input.text);social_before_sent=true
		for id in [1,2,3]:
			if not lines.contains("browser before member %d"%id):return false
		social_before_done=true
	if game.probe_epoch()==2 and game.probe_steady() and not social_after_done:
		if not social_after_sent:
			input.text="browser after member %d"%member;input.text_submitted.emit(input.text)
			if member==3:game.mark()
			social_after_sent=true
		for id in [2,3]:
			if not lines.contains("browser after member %d"%id):return false
		if member in [2,3] and game.social_probe("marks")<1:return false
		if game.social_probe("lines")<5:fail("social scrollback lost");return false
		game.show_score(true)
		print("RCB_SOCIAL_OK member=",member," epoch=2 lines=",game.social_probe("lines")," marks=",game.social_probe("marks"))
		social_after_done=true
	return true

func lobby_barrier()->bool:
	if lobby_started:return true
	if not game.probe_ready() or game.lobby_probe("profile_ready",0)!=1 or game.probe_players()!=3:return false
	var roster:String=game.get_node("Lobby/Panel/Column/Roster").text
	for id in [1,2,3]:
		if not roster.contains("Browser %d"%id):return false
	if not lobby_ready_sent:game.get_node("Lobby/Panel/Column/Buttons/Ready").pressed.emit();lobby_ready_sent=true
	if game.lobby_probe("ready",0)!=7 or game.lobby_probe("profile_pending",0)!=0:return false
	if not lobby_start_sent and member==1:game.get_node("Lobby/Panel/Column/Buttons/Start").pressed.emit();lobby_start_sent=true
	if game.lobby_probe("phase",0)!=1:return false
	print("RCB_LOBBY_STARTED member=",member," leader=",game.lobby_probe("leader",0))
	lobby_started=true;return true
