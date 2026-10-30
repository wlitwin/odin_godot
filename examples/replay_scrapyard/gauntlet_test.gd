extends "res://combat_test.gd"

var wave_seen := 0
var rests: Dictionary = {}
var stopped_for_rest := false
var shots_before := 0
var booms_before := 0
var denied := false

func _initialize() -> void:
	super._initialize()
	timeout_ms = 170000

func _process(dt: float) -> bool:
	if phase == "hash" or phase == "finish": return super._process(dt)
	if Time.get_ticks_msec() - started > timeout_ms: return fail("gauntlet timeout")
	if not p("ready"): return false
	match phase:
		"join":
			seat = p("seat")
			if seat == 0: phase = "world"
			else:
				game.dev_loadout(seat, 2 if seat == 1 else 1)
				game.dev_abilities(4, 5); phase = "loadout"
		"loadout":
			if p("iron", seat) == (2 if seat == 1 else 1) and p("ability0", seat) == 4 and p("ability1", seat) == 5:
				game.on_ready(); phase = "ready"
		"ready":
			if p("players") == 2 and p("marked_ready", 1) and p("marked_ready", 2):
				if seat == 1: game.on_start()
				phase = "world"
		"world":
			if p("in_yard", 1) and p("in_yard", 2):
				if seat==2:
					if game.dev_spawn(5,1,150.0,0.0)<=0:return fail("submit remote development command")
				if seat > 0:
					game.dev_combat(true)
					if not game.dev_cast(0, 0.0, 0.0, false): return fail("opening rally")
				phase = "waves"
		"waves":
			if seat==2 and not denied and p("dev_result")==-1:
				if p("dev_reason")!=2:return fail("development admission reason")
				denied=true;print("RSY_GAUNTLET_DEV_DENIED")
			if p("run") != 0 or p("stage") == 3: return fail("gauntlet wiped")
			var wave := p("wave")
			if wave > wave_seen:
				var panel := game.get_node("UI/Transitions/Wave")
				if not panel.visible or not ("WAVE %d OF 3" % wave) in panel.get_node("Text").text: return fail("wave announcement absent")
				if wave != wave_seen + 1 or (wave_seen > 0 and (not rests.has(wave_seen) or p("head") < rests[wave_seen])): return fail("wave skipped or rest shortened")
				wave_seen = wave
				if seat > 0: game.dev_combat(true)
				stopped_for_rest = false
				print("RSY_GAUNTLET_WAVE role=", mode, " wave=", wave, " tick=", p("head"), " spawned=", p("spawn_index"))
			if wave > 0 and p("director_alive") == 0 and p("pending") == 0 and p("rest_until") > p("head"):
				if not rests.has(wave):
					var panel := game.get_node("UI/Transitions/Wave")
					var expected := "WAVE %d OF 3 IN" % (wave + 1) if wave < 3 else "SECURING FLOOR"
					if not panel.visible or not expected in panel.get_node("Text").text: return fail("rest announcement absent")
					print("RSY_WAVE_VIEW role=", mode, " wave=", wave, " text=", panel.get_node("Text").text)
					rests[wave] = p("rest_until")
					print("RSY_GAUNTLET_REST role=", mode, " wave=", wave, " tick=", p("head"), " until=", p("rest_until"))
				if not stopped_for_rest and seat > 0:
					game.dev_combat(false); game.dev_drive(0, 0, false)
					if p("hp", seat) > 0 and p("hp", seat) < 10 and p("cd1", seat) == 0:
						if not game.dev_cast(1, p("x", seat), p("y", seat), true): return fail("rest healing")
				stopped_for_rest = true
			if p("stage") == 2:
				var history: String = game.get_node("UI/Chat/Lines").text
				if not "wave 2 of 3 rolls in" in history or not "wave 3 of 3 rolls in" in history or not "floor clear" in history: return false
				if history.count("wave 2 of 3 rolls in") != 1 or history.count("wave 3 of 3 rolls in") != 1 or game.chat_probe("news_gaps") != 0: return fail("wave history duplicated or skipped")
				print("RSY_CHAT_WAVES role=", mode, " retained=true once=true")
				if wave_seen != 3 or rests.size() != 3 or p("head") < rests[3]: return fail("incomplete gauntlet")
				if p("spawn_index") != 13 or p("director_alive") != 0 or p("clears") != 1: return fail("wave totals")
				if p("cores", 1) != 1 or p("cores", 2) != 1: return fail("clear award")
				print("RSY_GAUNTLET_RESULT role=", mode, " waves=", wave_seen, " rests=", rests.size(), " spawned=", p("spawn_index"), " clears=", p("clears"), " hp1=", p("hp", 1), " hp2=", p("hp", 2), " tick=", p("head"))
				if seat>0:
					game.dev_combat(false);game.dev_drive(0,0,false)
					game.dev_walk(600.0 if seat==1 else 400.0,960.0,true)
				phase="gather"
		"gather":
			if seat>0:
				var target:=Vector2(600.0 if seat==1 else 400.0,960.0)
				if Vector2(p("x",seat),p("y",seat)).distance_to(target)>36:return false
				game.dev_walk(0.0,0.0,false);game.dev_drive(0,0,false)
				if seat==2 and not denied:return fail("missing development rejection")
			write("gathered-"+mode,{"ready":true});phase="kegs"
		"kegs":
			for role in participants:
				if read("gathered-"+role).is_empty():return false
			if p("projectiles")!=0:return false
			if seat==1:
				if p("props")!=0 or p("barrels")!=0:return fail("unexpected props before finale")
				if game.dev_spawn(5,1,150.0,0.0)<=0 or game.dev_spawn(5,1,150.0,50.0)<=0:return fail("queue kegs")
			phase="spawned"
		"spawned":
			if p("props")==2:
				shots_before=p("shots",1);booms_before=p("barrels")
				write("kegs-"+mode,{"shots":shots_before,"booms":booms_before,"props":2});phase="pop"
		"pop":
			for role in participants:
				if read("kegs-"+role).is_empty():return false
			if seat==1:game.dev_aim(1.0,0.0,p("shots",1)==shots_before)
			if p("barrels")==booms_before+2 and p("props")==0:
				if p("shots",1)!=shots_before+1 or p("clears")!=1 or p("cores",1)!=1 or p("cores",2)!=1:return fail("chain changed counters or needed extra pulls")
				if seat==1:game.dev_aim(1.0,0.0,false)
				print("RSY_GAUNTLET_CHAIN role=",mode," booms=2 pulls=1 tick=",p("head"))
				write("stopped-"+mode,{"ready":true});phase="hash"
	return false
