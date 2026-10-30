extends SceneTree
var game: Node
var role := OS.get_environment("REPLAY_CAVE_ROLE")
var work := OS.get_environment("CAVE_OWNER_DIR")
var observations := []

func _initialize() -> void:
	game = load("res://cave.tscn").instantiate()
	root.add_child(game)
	call_deferred("run")

func until(predicate: Callable, label: String, limit := 12.0) -> bool:
	var start := Time.get_ticks_msec()
	while not predicate.call():
		if Time.get_ticks_msec() - start > limit * 1000:
			print("CAVE_OWNER_FAIL ", role, " ", label)
			quit(1)
			return false
		await process_frame
	return true

func mark(name: String) -> void:
	var file := FileAccess.open(work.path_join(name), FileAccess.WRITE)
	file.store_string("ready")
	file.close()

func has(name: String) -> bool:
	return FileAccess.file_exists(work.path_join(name))

func m(key: String, seat := 0) -> int:
	return game.motion_probe(key, seat)

func note(label: String) -> void:
	observations.append({"label":label,"tick":game.campaign_probe("clock",0),"owner":m("prop_owner"),"revision":m("prop_revision"),"sequence":m("prop_sequence"),"x":m("prop_x"),"y":m("prop_y")})
	print("CAVE_OWNER_STATE ", role, " ", label, " ", JSON.stringify(observations.back()))

func run() -> void:
	if not await until(func(): return game.probe_ready() and game.probe_players() == 2, "join"): return
	if m("profile") != 1:
		print("CAVE_OWNER_FAIL wrong profile"); quit(1); return
	mark("admitted-" + role)
	if not await until(func(): return has("admitted-host") and has("admitted-client") and has("admitted-observer"), "party"): return
	if role == "host": game.walk_to(120.0,80.0)
	if not await until(func(): return abs(m("avatar_x",1)-120)<3 and abs(m("avatar_y",1)-80)<3, "host approach"): return
	if role == "host": game.carry()
	if not await until(func(): return m("prop_owner")==1 and m("prop_sequence")>0, "host possession"): return
	note("host carrying")
	if role != "observer": game.walk_to(220.0,80.0)
	if not await until(func(): return abs(m("avatar_x",1)-220)<3 and abs(m("avatar_x",2)-220)<3 and m("prop_x")>225, "carried movement"): return
	note("moved")
	mark("moved-"+role)
	if not await until(func(): return has("moved-host") and has("moved-client") and has("moved-observer"), "movement witnesses"): return
	if role == "host": game.set_down()
	if not await until(func(): return m("prop_owner")==0, "drop"): return
	note("dropped")
	mark("dropped-"+role)
	if not await until(func(): return has("dropped-host") and has("dropped-client") and has("dropped-observer"), "drop witnesses"): return
	if role == "client": game.carry()
	if not await until(func(): return m("prop_owner")==2 and m("prop_sequence")>0, "new owner"): return
	note("client carrying")
	if role == "client": game.walk_to(160.0,100.0)
	if not await until(func(): return abs(m("avatar_x",2)-160)<3 and abs(m("avatar_y",2)-100)<3 and abs(m("prop_x")-170)<3 and abs(m("prop_y")-88)<3, "new owner movement"): return
	note("continued")
	if m("avatar_owner",1)!=1 or m("avatar_owner",2)!=2 or game.probe_gems()!=3:
		print("CAVE_OWNER_FAIL identity or inventory"); quit(1); return
	var file := FileAccess.open(work.path_join(role+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"pass":true,"observations":observations,"drops":game.campaign_probe("fault_drops",0),"duplicates":game.campaign_probe("fault_duplicates",0)}));file.close()
	mark("done-"+role)
	if not await until(func(): return has("done-host") and has("done-client") and has("done-observer"), "completion"): return
	# Keep the authority serving until all observers have recorded continuation.
	await create_timer(0.25).timeout
	print("REPLAY_CAVE_OWNER_FLOW_OK ",role)
	quit(0)
