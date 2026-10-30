extends "res://combat_test.gd"
const ViewProbe = preload("res://view_probe.gd")

var member := 0
var migration_mode := ""
var result_written := false
var next_trace := 0
var freeze_started := 0
var frozen_ms := 0
var aim_x := 800.0
var lobby_migration := false
var require_spray := false
var dependency_waited := false
var follower_asset_wait:=0
var follower_assets_released:=false
var recovery_view_seen := false
var grenade_case := false
var grenade_started := false
var grenade_ids := []
var camera_case := false
var camera_prepared := false
var chat_case := false
var chat_before_sent := false
var chat_before_done := false
var chat_after_sent := false
var chat_after_done := false
var spray_stamped := false
var backup_reported := false

func _initialize() -> void:
	super._initialize()
	member = int(OS.get_environment("RSY_MEMBER"))
	migration_mode = OS.get_environment("REPLAY_MIGRATION_MODE")
	grenade_case = OS.get_environment("RSY_GRENADE_MIGRATION") == "1"
	camera_case = OS.get_environment("RSY_CAMERA_MIGRATION") == "1" and migration_mode == "crash"
	chat_case = OS.get_environment("RSY_CHAT_MIGRATION") == "1"
	directory = OS.get_environment("REPLAY_MIGRATION_DIR")
	mode = "host" if member == 2 else "client" if member == 3 else "observer"
	participants = ["host", "client", "observer"]
	if migration_mode == "crash": participants = ["host", "client"]
	timeout_ms = 65000
	if OS.get_environment("RSY_SLOW_BACKUP") == "1": aim_x = 1100.0
	lobby_migration = OS.get_environment("RSY_MIGRATION_STAGE") == "lobby"
	require_spray = OS.get_environment("RSY_MIGRATION_SPRAYS") == "1"
	if require_spray and member==3:game.dev_asset_pause(true)

func _process(dt: float) -> bool:
	if phase == "hash" or phase == "finish": return super._process(dt)
	if chat_case and p("ready") and game.chat_probe("ready"):
		var history: String = game.get_node("UI/Chat/Lines").text
		if not chat_before_sent:
			game.on_chat("before migration member %d" % member); chat_before_sent = true
		if not chat_before_done:
			chat_before_done = true
			for id in [1, 2, 3]:
				if not ("before migration member %d" % id) in history: chat_before_done = false
			if chat_before_done: write("chat-before-" + str(member), {"ready": true})
		if p("epoch") == 2 and not chat_after_done:
			if not chat_after_sent: game.on_chat("after migration member %d" % member); chat_after_sent = true
			chat_after_done = true
			for id in ([1, 2, 3] if migration_mode == "planned" else [2, 3]):
				if not ("after migration member %d" % id) in history: chat_after_done = false
			if not "the yard has a new one" in history: chat_after_done = false
			if chat_after_done:
				for id in [1, 2, 3]:
					if history.count("before migration member %d" % id) != 1: return fail("chat history lost/duplicated at takeover")
				if history.count("the yard has a new one") != 1: return fail("keeper announcement duplicated")
				print("RSY_CHAT_MIGRATION member=", member, " history=true new_messages=true new_keeper_once=true")
	if not read("trigger").is_empty() and p("room_phase") in [3, 4, 5, 6]:
		if not game.get_node("UI/Transitions/Recovery").visible: return fail("recovery narration absent")
		if not recovery_view_seen:
			recovery_view_seen = true; print("RSY_RECOVERY_VIEW member=", member, " visible=true")
	if OS.get_environment("REPLAY_MIGRATION_TRACE") == "1" and Time.get_ticks_msec() >= next_trace:
		next_trace = Time.get_ticks_msec() + 1000
		print("RSY_MIGRATION_TRACE member=", member, " phase=", phase, " room=", p("room_phase"), " players=", p("players"), " ready=", p("marked_ready", 1), "/", p("marked_ready", 2), "/", p("marked_ready", 3), " epoch=", p("epoch"), " head=", p("head"), " backup=", p("backup_sequence"))
	if Time.get_ticks_msec() - started > timeout_ms:
		print("RSY_MIGRATION_DIAG member=", member, " room=", p("room_phase"), " control=", p("control_error"), " link=", p("link_error"), " model=", p("link_model_error"), " backup=", p("backup_sequence"))
		return fail("migration timeout")
	match phase:
		"join":
			if p("ready"):
				seat = p("seat")
				if seat != member: return fail("seat identity")
				game.dev_drive(0, 0, false)
				if require_spray and member == 2: game.dev_asset_pause(true)
				game.dev_abilities(5 if member == 1 else 4, 1 if member == 1 else 6)
				if grenade_case and member == 1: game.dev_loadout(0, 4)
				phase = "loadout"
		"loadout":
			if p("ready") and p("ability0", member) == (5 if member == 1 else 4) and p("ability1", member) == (1 if member == 1 else 6):
				if grenade_case and member == 1 and p("iron", 1) != 4: return false
				game.on_ready(); phase = "ready"
		"ready":
			if p("ready") and p("players") == 3 and p("marked_ready", 1) and p("marked_ready", 2) and p("marked_ready", 3):
				if member == 2 and p("lobby_backup"): write("roster-backed-up", {"tick": p("backup_tick")})
				if read("roster-backed-up").is_empty(): return false
				if lobby_migration: phase = "backup"
				else:
					if member == 1: game.on_start()
					phase = "world"
		"world":
			if p("ready") and p("stage") == 1 and p("in_yard", 1) and p("in_yard", 2) and p("in_yard", 3):
				phase = "asset_warm" if require_spray else "grenade_warm" if grenade_case else "cast"
		"asset_warm":
			if not p("ready"): return false
			if member == 1 and not spray_stamped:
				if p("spray_bytes", 1) == 0: return false
				if not game.stamp(): return fail("migration stamp")
				spray_stamped = true
			if member == 2 and not dependency_waited and p("asset_prepare_wait"):
				if p("backup_spray"): return fail("prepared missing image")
				dependency_waited = true; print("RSY_ASSET_PREPARE_WAIT_OBSERVED")
				game.dev_asset_pause(false)
			if member == 2 and dependency_waited and p("spray_cached", 1) and p("backup_spray"):
				write("asset-warm", {"ready": true})
			if not read("asset-warm").is_empty(): phase = "grenade_warm" if grenade_case else "cast"
		"grenade_warm":
			if not p("ready"): return false
			if member == 1 and not grenade_started:
				game.dev_aim(-1.0, 0.0, true); grenade_started = true
			if game.feedback_probe("embers") > 0:
				grenade_ids = []
				for child in game.get_node("World").get_children():
					if ViewProbe.polygon(child) and str(child.name).begins_with("Ember"): grenade_ids.append(child.get_instance_id())
				write("grenade-before-" + str(member), {"embers": grenade_ids.size(), "tick":p("head")})
			for id in [1, 2, 3]:
				if read("grenade-before-" + str(id)).is_empty(): return false
			print("RSY_GRENADE_BEFORE member=", member, " embers=", grenade_ids.size())
			phase = "cast"
		"cast":
			if p("ready"):
				if chat_case:
					for id in [1, 2, 3]:
						if read("chat-before-" + str(id)).is_empty(): return false
				if member == 1:
					if camera_case and game.dev_hurt(3, 255) <= 0: return fail("camera downed setup")
					if not game.dev_cast(0, 500.0, 1040.0, true) or not game.dev_cast(1, aim_x, 1040.0, true): return fail("initial combat cast")
					print("RSY_MIGRATION_CAST tick=", p("head"), " clock_ms=", Time.get_ticks_msec())
				phase = "backup"
		"backup":
			if member == 1 and not backup_reported and not read("active-backup").is_empty():
				backup_reported = true
				print("RSY_MIGRATION_BACKUP_RECEIPT tick=", p("head"), " lobs=", p("lobs"), " zones=", p("zones"), " checkpoint=", read("active-backup").tick, " clock_ms=", Time.get_ticks_msec())
			if camera_case and member == 3 and p("ready") and p("hp", 3) == 0 and p("camera_seat") == 1:
				if not camera_prepared:
					camera_prepared = true; write("camera-before", {"target": 1})
					print("RSY_CAMERA_HOST_FOLLOW before=1 hp=0")
			if member == 2 and p("lobby_backup" if lobby_migration else "active_backup") and (not require_spray or p("backup_spray")):
				write("active-backup", {"tick": p("backup_tick"), "sequence": p("backup_sequence")})
			if member == 1 and p("ready") and not read("active-backup").is_empty() and (lobby_migration or (p("lobs") > 0 and p("zones") > 0)):
				if chat_case:
					for id in [1, 2, 3]:
						if read("chat-before-" + str(id)).is_empty(): return false
				if camera_case and read("camera-before").is_empty(): return false
				write("trigger", {"tick": p("head")})
				if migration_mode == "planned":
					if not game.handoff(): return fail("handoff")
				else: write("kill_owner", {"tick": p("head")})
				phase = "migration"
			if p("epoch") == 2: phase = "migration"
		"migration":
			if member == 1 and p("room_phase") == 3:
				if p("authority_head") != p("frozen_tick"): return fail("frozen owner advanced")
				if freeze_started == 0: freeze_started = Time.get_ticks_msec()
				frozen_ms = Time.get_ticks_msec() - freeze_started
			if p("ready") and p("epoch") == 2 and p("recovery_ready"):
				if p("seat") != member: return fail("recovered seat")
				if grenade_case:
					game.dev_aim(-1.0, 0.0, false)
					if grenade_ids.is_empty(): return fail("grenade trail never observed before recovery")
					for id in grenade_ids:
						if is_instance_id_valid(id): return fail("old grenade ember survived recovery")
					if game.feedback_probe("wrong_epoch") != 0 or game.feedback_probe("dropped") != 0: return fail("grenade recovery scope/capacity")
					print("RSY_GRENADE_RECOVERED member=", member, " old_embers=0")
				if member == 1 and OS.get_environment("RSY_SLOW_BACKUP") == "1" and frozen_ms < 2000: return fail("slow transfer did not exceed lease duration")
				if p("recovery_kind") != (1 if migration_mode == "planned" else 2): return fail("recovery kind")
				if member == 2:
					if not p("authority") or not p("restored_exact") or (not lobby_migration and not p("restored_active")): return fail("complete restore")
					if not lobby_migration:
						var lobs := []
						for child in game.get_node("World").get_children():
							if ViewProbe.polygon(child) and child.visible and str(child.name).begins_with("Lob"): lobs.append(child)
						if lobs.is_empty(): return false
						for lob in lobs:
							if ViewProbe.vertices(lob).size() != 10 or lob.z_index != 6: return fail("restored lob glyph")
						print("RSY_GLOB_RECOVERED member=2 epoch=2 discs=",lobs.size())
						var zones := []
						for child in game.get_node("World").get_children():
							if ViewProbe.polygon(child) and child.visible and str(child.name).begins_with("Zone"): zones.append(child)
						if zones.size() != p("zones"): return false
						for zone in zones:
							if ViewProbe.vertices(zone).size() != 24 or zone.z_index != 2 or not is_equal_approx(ViewProbe.tint(zone).a,0.22): return fail("restored standing fill")
						print("RSY_AREA_RECOVERED member=2 epoch=2 zones=",zones.size())
					write("resumed", {"checkpoint": p("recovery_tick")})
				elif p("authority"): return fail("obsolete authority")
				phase = "lobby_rejoin" if lobby_migration else "land"
		"lobby_rejoin":
			if p("ready") and p("players") == participants.size() and not read("resumed").is_empty():
				if p("stage") != 0 or p("leader") != 2: return fail("lobby leader recovery")
				if p("ability0", member) != (5 if member == 1 else 4): return fail("loadout recovery")
				if not p("marked_ready", member): game.on_ready()
				phase = "lobby_ready"
		"lobby_ready":
			if p("ready") and p("marked_ready", 2) and p("marked_ready", 3) and (migration_mode == "crash" or p("marked_ready", 1)):
				if member == 2: game.on_start()
				phase = "lobby_started"
		"lobby_started":
			if p("ready") and p("stage") == 1 and p("in_yard", 2) and p("in_yard", 3) and (migration_mode == "crash" or p("in_yard", 1)):
				if p("leader") != 2: return fail("returned host preempted leader")
				print("RSY_LOBBY_MIGRATION_RESULT member=", member, " epoch=", p("epoch"), " checkpoint=", p("recovery_tick"), " leader=", p("leader"), " players=", p("players"), " lost=", p("lost_ticks"))
				write("stopped-" + mode, {"ready": true})
				phase = "hash"
		"land":
			if p("ready") and p("landed") >= 1 and not read("resumed").is_empty():
				if game.get_node("UI/Transitions/Recovery").visible: return fail("recovery narration remained after restore")
				if member == 2 and not recovery_view_seen: return fail("successor recovery narration never observed")
				if member == 2:
					if not game.dev_cast(0, 0.0, 0.0, false) or not game.dev_cast(1, aim_x, 1040.0, true): return fail("successor casts")
				phase = "continued"
		"continued":
			if p("ready") and p("casts", 2) >= 2 and p("landed") >= 2 and p("reactions") >= 2 and p("zones") == 1:
				if game.feedback_probe("wrong_epoch") != 0: return fail("old feedback survived authority replacement")
				print("RSY_FEEDBACK_RECOVERY member=", member, " old_epoch_effects=0")
				if chat_case and not chat_after_done: return false
				if camera_case:
					if member == 3:
						if p("hp", 3) != 0 or not camera_prepared: return fail("downed camera state lost")
						if p("camera_seat") != 2: return false
						var camera := game.get_node("Camera") as Camera2D
						var runner := game.get_node("World/Runner2") as Node2D
						if camera.global_position.distance_to(runner.global_position) > 0.1 or not game.get_node("UI/Following").visible: return fail("camera did not follow surviving teammate")
						var downed := game.get_node("World/Runner3")
						if abs(downed.get_node("Body").rotation - 1.4) > 0.01 or downed.get_node("Gun").visible or not downed.get_node("Beacon").visible: return fail("downed pose lost during recovery")
						var ghost := game.get_node("World/Runner1") as Node2D
						if p("hp", 1) > 0 and (abs(ghost.modulate.r - 0.55) > 0.01 or abs(ghost.modulate.a - 0.45) > 0.01): return fail("disconnected runner ghost tint")
						write("camera-after", {"target": 2}); print("RSY_CAMERA_HOST_FOLLOW after=2 hp=0")
					elif read("camera-after").is_empty(): return false
				if OS.get_environment("RSY_MIGRATION_MODS") == "1":
					if game.gun_name(0) != "junkcannon" or p("gun_damage", 0) != 9 or p("catalog_mob_hp", 1) != 30: return fail("migrated mod catalog")
					print("RSY_MIGRATION_MOD member=", member, " damage=9 mob_hp=30")
				if require_spray:
					if member==3 and not follower_assets_released:
						if p("spray_cached",1):return fail("follower pause did not withhold image")
						follower_assets_released=true;game.dev_asset_pause(false)
					if member == 2 and not dependency_waited: return fail("dependency barrier untested")
					if not p("spray_cached",1) or not p("spray_visible",1) or p("spray_stamp",1)!=1:
						if member==2:return fail("successor spray recovery dependency")
						if follower_asset_wait==0:follower_asset_wait=Time.get_ticks_msec()
						if Time.get_ticks_msec()-follower_asset_wait>5000:
							print("RSY_ASSET_DIAG member=",member," requested=",p("asset_requested")," received=",p("asset_received")," installed=",p("asset_installed")," rejected=",p("asset_rejected")," stamp=",p("spray_stamp",1))
							return fail("follower spray recovery deadline")
						return false
					if follower_asset_wait!=0:print("RSY_FOLLOWER_ASSET_READY member=",member," wait_ms=",Time.get_ticks_msec()-follower_asset_wait)
					if game.spray_id(1) != OS.get_environment("RSY_SPRAY_EXPECTED"): return fail("spray recovery identity")
					print("RSY_MIGRATION_SPRAY member=", member, " bytes=", p("spray_bytes", 1), " cached=1 visible=1")
				if p("ping_epoch") != 2 or not p("ping_known", 2) or not p("ping_known", 3): return false
				if p("ping_ms", 2) != 0 or p("ping_ms", 3) <= 0: return fail("round-trip measurements did not follow new authority")
				print("RSY_TELEMETRY_MIGRATION member=", member, " epoch=2 authority_ms=", p("ping_ms",2), " guest_ms=", p("ping_ms",3))
				print("RSY_MIGRATION_RESULT member=", member, " epoch=", p("epoch"), " checkpoint=", p("recovery_tick"), " lost=", p("lost_ticks"),
					" interruption=", p("interruption"), " casts2=", p("casts", 2), " landed=", p("landed"), " zones=", p("zones"), " reactions=", p("reactions"), " frozen_ms=", frozen_ms)
				write("stopped-" + mode, {"ready": true})
				phase = "hash"
	return false
