extends "res://combat_test.gd"

var prompt_checked := false
var camera_borrowed := false
var wound_seen := false

func camera_matches(wanted: int) -> bool:
	var camera := game.get_node("Camera") as Camera2D
	var runner := game.get_node("World/Runner" + str(wanted)) as Node2D
	return p("camera_seat") == wanted and camera.global_position.distance_to(runner.global_position) < 0.1 and camera.position_smoothing_enabled and camera.zoom == Vector2(2, 2) and camera.limit_right == 1920 and camera.limit_bottom == 1088

func _process(dt: float) -> bool:
	if phase == "hash" or phase == "finish": return super._process(dt)
	var now := Time.get_ticks_msec()
	if now - started > timeout_ms: return fail("revive timeout")
	if phase != "join" and not p("ready"): return false
	if seat == 0 and game.feedback_probe("wounds") != 0: return fail("spectator received personal wound direction")
	if seat > 0 and game.feedback_probe("wounds") > 0: wound_seen = true
	match phase:
		"join":
			if p("ready"):
				seat = p("seat")
				if seat > 0: game.on_ready()
				phase = "ready"
		"ready":
			if p("players") == 2 and p("marked_ready", 1) and p("marked_ready", 2):
				if seat == 1: game.on_start()
				phase = "world"
		"world":
			if p("stage") == 1 and p("in_yard", 1) and p("in_yard", 2):
				if seat == 0 and (game.get_node("UI/CombatHUD/Vitals").visible or game.get_node("UI/CombatHUD/Ammo").visible): return fail("observer has personal HUD")
				if seat > 0: game.dev_drive(0, 0, false)
				phase = "down"
		"down":
			if p("hp", 2) == 0:
				if seat == 1: game.dev_revive(true)
				phase = "partial"
		"partial":
			if seat == 2 and p("revive_progress", 1) >= 30 and not camera_borrowed:
				var own := game.get_node("World/Runner2")
				if abs(own.get_node("Body").rotation - 1.4) > 0.01 or own.get_node("Gun").visible or not own.get_node("Beacon").visible: return fail("downed runner pose absent")
				if not camera_matches(1) or not game.get_node("UI/Following").visible or game.get_node("UI/CombatHUD/Vitals/Text").text != "0/10": return fail("downed camera did not borrow teammate while preserving personal HUD")
				camera_borrowed = true; print("RSY_CAMERA_BORROWED target=1 own_hp=0")
				if OS.get_environment("RSY_SCREENSHOT") != "": capture_scene(OS.get_environment("RSY_SCREENSHOT"))
			if seat == 1 and p("revive_progress", 1) >= 60:
				var prompt := game.get_node("UI/CombatHUD/Prompt") as Label
				if not prompt.visible or not "Reviving" in prompt.text: return fail("revive HUD progress absent")
				prompt_checked = true
				print("RSY_REVIVE_HUD role=", mode, " progress=true")
				game.dev_revive(false)
				write("release-request", {"tick": p("head")})
			if not read("release-request").is_empty():
				phase = "released"
		"released":
			if p("head") > int(read("release-request").tick) and p("revive_progress", 1) == 0:
				if p("hp", 2) != 0: return fail("partial hold revived")
				write("released-" + mode, {"tick": p("head")})
				phase = "release_barrier"
		"release_barrier":
			for role in participants:
				if read("released-" + role).is_empty(): return false
			if seat == 1: game.dev_revive(true)
			phase = "complete"
		"complete":
			if p("revives", 1) == 1:
				if p("hp", 2) == 0: return fail("revived player still down")
				if seat > 0: game.dev_revive(false); game.dev_combat(true)
				phase = "finish_enemy"
		"finish_enemy":
			if p("mobs") == 0:
				if seat > 0: game.dev_combat(false)
				acted = now; phase = "settle"
		"settle":
			if now - acted > 1500:
				if seat == 2:
					if not wound_seen: return fail("victim never saw wound direction")
					print("RSY_WOUND_NETWORK role=", mode, " seen=true missing_history=", game.feedback_probe("wound_missing"))
					var own := game.get_node("World/Runner2")
					if own.get_node("Body").rotation != 0 or not own.get_node("Gun").visible or own.get_node("Beacon").visible: return fail("revived runner pose stale")
					if not camera_borrowed or not camera_matches(2) or game.get_node("UI/Following").visible: return fail("revived camera did not return home")
					print("RSY_CAMERA_RETURNED target=2")
					if OS.get_environment("RSY_SCREENSHOT") != "": capture_scene(OS.get_environment("RSY_SCREENSHOT").get_basename() + "-revived.png")
				if game.get_node("UI/CombatHUD/Prompt").visible: return fail("revive HUD remained after completion")
				if seat == 1 and not prompt_checked: return fail("revive HUD never checked")
				print("RSY_REVIVE_RESULT role=", mode, " revives=", p("revives", 1), " hp1=", p("hp", 1), " hp2=", p("hp", 2))
				write("stopped-" + mode, {"ready": true}); phase = "hash"
	return false
