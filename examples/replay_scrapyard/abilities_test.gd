extends "res://combat_test.gd"

var zone_seen_on_join := false
var screenshot_done := false
var zone_captured := false
var storm := false
var surge_seen := false
var doused := false

func _initialize() -> void:
	super._initialize()
	mode = OS.get_environment("RSY_NAME")
	participants = ["host", "client", "support", "observer"]
	storm = OS.get_environment("RSY_STORM") == "1"

func pair_for(player: int) -> Vector2i:
	if storm:
		if player == 1: return Vector2i(1, 3)
		if player == 2: return Vector2i(6, 2)
	if player == 1: return Vector2i(1, 2)
	if player == 2: return Vector2i(3, 6)
	return Vector2i(4, 5)

# The scenario must not consume a transient status before every process has
# observed it. Receipts coordinate test actions; they never change game state.
func witnessed(label: String, condition: bool) -> bool:
	if condition and read(label + "-" + mode).is_empty(): write(label + "-" + mode, {"tick": p("head")})
	for participant in participants:
		if read(label + "-" + participant).is_empty(): return false
	return true

func _process(dt: float) -> bool:
	if phase == "hash" or phase == "finish": return super._process(dt)
	var now := Time.get_ticks_msec()
	if now - started > (80000 if storm else 50000): return fail("ability timeout")
	if phase != "join" and not p("ready"): return false
	if p("ready") and p("fx_mask", 3) & (1 << 8): surge_seen = true
	match phase:
		"join":
			if p("ready"):
				seat = p("seat")
				if seat == 0:
					if p("zones") == 0 or p("zone_left") <= 0: return fail("late observer missed active zone")
					zone_seen_on_join = true
					print("RSY_ABILITY_LATE_ZONE left=", p("zone_left"))
					write("observer-zone", {"tick": p("head"), "left": p("zone_left")})
					phase = "slime_wait"
				else:
					var pair := pair_for(seat)
					game.dev_abilities(pair.x, pair.y)
					phase = "loadout"
		"loadout":
			var pair := pair_for(seat)
			if p("ability0", seat) == pair.x and p("ability1", seat) == pair.y:
				game.on_ready()
				phase = "ready"
		"ready":
			if p("players") == 3 and p("marked_ready", 1) and p("marked_ready", 2) and p("marked_ready", 3):
				if mode == "host": game.on_start()
				phase = "world"
		"world":
			if p("stage") == 1 and p("in_yard", 1) and p("in_yard", 2) and p("in_yard", 3):
				game.dev_drive(0, 0, false)
				if seat == 3:
					if not game.dev_cast(0, 0.0, 0.0, false): return fail("queue buff")
					if not game.dev_cast(1, 620.0, 660.0, true): return fail("queue zone")
				phase = "zone"
		"zone":
			if p("zones") == 1 and p("casts", 3) == 2:
				if not zone_captured and OS.get_environment("RSY_SCREENSHOT") != "":
					zone_captured = true
					capture_scene(OS.get_environment("RSY_SCREENSHOT") + "-zone.png")
				if mode == "host": write("zone-open", {"tick": p("head")})
				if not read("observer-zone").is_empty():
					if seat == 1 and not game.dev_cast(0, 800.0, 800.0, true): return fail("queue slime")
					phase = "slime_wait"
		"slime_wait":
			if witnessed("slime-first", p("mob_fx", 1) & (1 << 1) and p("mob_fx", 2) & (1 << 1)):
				if seat == (1 if storm else 2) and not game.dev_cast(1 if storm else 0, 0.0, 0.0, false): return fail("queue nova")
				phase = "frozen"
		"frozen":
			if witnessed("frozen", p("mob_fx", 1) & (1 << 7) and p("mob_fx", 2) & (1 << 7)):
				if seat == (2 if storm else 1) and not game.dev_cast(1, 0.0 if storm else 1.0, 1.0 if storm else 0.0, false): return fail("queue cone")
				phase = "shatter"
		"shatter":
			if witnessed("shatter", p("damage", 2 if storm else 1) == 102 and p("reactions") >= 4):
				if p("hp", 1) == 0 or p("hp", 2) == 0: return fail("unexpected reaction range")
				print("RSY_SHATTER_CREDIT role=", mode, " seat=", 2 if storm else 1, " damage=102")
				phase = "douse_ready" if storm else "cooldown"
		"douse_ready":
			if p("cd1", 1) == 0 and p("cd1", 2) == 0:
				if seat == 2 and not game.dev_cast(1, 0.0, 1.0, false): return fail("second burn")
				phase = "burn"
		"burn":
			if witnessed("burn", p("mob_fx", 1) & (1 << 2) and p("mob_fx", 2) & (1 << 2)):
				if seat == 1 and not game.dev_cast(1, 0.0, 0.0, false): return fail("douse nova")
				phase = "doused"
		"doused":
			if witnessed("doused", p("casts", 1) == 3 and (p("mob_fx", 1) & ((1 << 2) | (1 << 3))) == 0 and (p("mob_fx", 2) & ((1 << 2) | (1 << 3))) == 0):
				doused = true
				print("RSY_DOUSE_SEEN role=", mode, " reactions=", p("reactions"))
				phase = "cooldown"
		"cooldown":
			if p("cd0", 1) == 0:
				if seat == 1 and not game.dev_cast(0, 800.0, 800.0, true): return fail("queue second slime")
				phase = "reprime"
		"reprime":
			if witnessed("slime-second", p("landed") >= 2 and p("mob_fx", 1) & (1 << 1) and p("mob_fx", 2) & (1 << 1)):
				if seat == 2 and not game.dev_cast(0 if storm else 1, 800.0, 800.0, true): return fail("queue spark")
				phase = "spread"
		"spread":
			if witnessed("spread", p("landed") == 3 and p("mob_fx", 1) & (1 << 6) and p("mob_fx", 2) & (1 << 6)):
				if not screenshot_done and OS.get_environment("RSY_SCREENSHOT") != "":
					screenshot_done = true
					capture_scene(OS.get_environment("RSY_SCREENSHOT"))
				acted = now
				phase = "settle"
		"settle":
			if now - acted >= 3000:
				if p("casts", 1) != (4 if storm else 3) or p("casts", 2) != (3 if storm else 2) or p("casts", 3) != 2: return fail("cast counts")
				if p("hp", 3) != 10 or p("zone_pulses") != 11 or p("zones") != 0: return fail("zone regen/expiry")
				if not surge_seen: return fail("friendly surge not observed")
				if storm:
					if not doused or p("damage", 1) != 0 or p("damage", 2) < 102 or p("reactions") < 9: return fail("storm reaction/credit totals")
				elif p("damage", 1) != 102 or p("damage", 2) <= 0 or p("reactions") < 7: return fail("reaction/credit totals")
				print("RSY_ABILITY_RESULT role=", mode, " casts=", p("casts", 1) + p("casts", 2) + p("casts", 3), " landed=", p("landed"),
					" zones=", p("zones_spawned"), " pulses=", p("zone_pulses"), " reactions=", p("reactions"), " damage1=", p("damage", 1),
					" damage2=", p("damage", 2), " hp3=", p("hp", 3), " late_zone=", int(zone_seen_on_join), " surge=", int(surge_seen), " doused=", int(doused))
				write("stopped-" + mode, {"ready": true})
				phase = "hash"
	return false
