extends SceneTree
var game: Node
var role := ""
var implementation := ""
var scenario := ""
var folder := ""
var phase := "boot"
var started := 0
var resource_floor := 0
var trace := []
var inputs := []
var next_sample := 0
var finished := false
var total_guard := -1
var ready_sent := false
const ROLES := ["host","guest","helper"]
func p(key: String, seat := 1) -> int: return int(game.authoring_probe(key,seat))
func balances() -> Array: return [p("cash",1),p("cash",2),p("cash",3)]
func health() -> Array: return [p("hp",1),p("hp",2),p("hp",3)]
func write(name: String, value: Dictionary):
	var file := FileAccess.open(folder+"/"+name+".json.pending",FileAccess.WRITE)
	file.store_string(JSON.stringify(value));file.close()
	assert(DirAccess.rename_absolute(folder+"/"+name+".json.pending",folder+"/"+name+".json")==OK)
func all_have(prefix: String) -> bool:
	for name in ROLES:
		if not FileAccess.file_exists(folder+"/"+prefix+"-"+name+".json"): return false
	return true
func sample():
	if game==null or not p("ready"): return
	var money := balances();var hp := health()
	if role=="host" and total_guard>=0 and money[0]+money[1]+money[2]!=total_guard:
		fail("authority conservation");return
	if Time.get_ticks_msec()>=next_sample:
		next_sample=Time.get_ticks_msec()+100
		trace.append({"ms":Time.get_ticks_msec()-started,"phase":phase,"cash":money,"hp":hp,"prompt":str(game.authoring_prompt())})
func until(test: Callable, timeout := 15000) -> bool:
	var deadline := Time.get_ticks_msec()+timeout
	while Time.get_ticks_msec()<deadline and not finished:
		sample()
		if test.call(): return true
		await process_frame
	return false
func hold(value: bool):
	game.authoring_hold(value);inputs.append({"ms":Time.get_ticks_msec()-started,"held":value})
func fail(reason: String):
	if finished:return
	write("failure-"+role,{"reason":reason,"phase":phase,"cash":balances(),"hp":health(),"trace":trace,"inputs":inputs})
	print("AUTHORING_FAIL ",implementation," ",role," ",phase," ",reason)
	finish(1)
func finish(code: int):
	if finished:return
	finished=true;game.queue_free();game=null
	await process_frame;await process_frame
	var deadline:=Time.get_ticks_msec()+2000
	while int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))>resource_floor and Time.get_ticks_msec()<deadline:await process_frame
	quit(code)
func _initialize():
	role=OS.get_environment("AUTHORING_ROLE");implementation=OS.get_environment("AUTHORING_IMPL");scenario=OS.get_environment("AUTHORING_CASE");folder=OS.get_environment("AUTHORING_DIR")
	started=Time.get_ticks_msec();resource_floor=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT));run.call_deferred()
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	if implementation=="kit":game.call("on_host" if role=="host" else "on_join")
	if not await until(func():return p("seat")>0):fail("admission");return
	game.dev_loadout(0,0)
	if implementation=="replay":game.dev_drive(0,0,false)
	write("seated-"+role,{"seat":p("seat")})
	if not await until(func():return all_have("seated") and p("players")==3):fail("roster");return
	if implementation=="replay":
		# Re-declare from the local choice before readying; the accepted profile
		# must be visible, as in the existing paired-game harness.
		if not await until(func():return int(game.probe("iron",p("seat")))==0 and int(game.probe("look",p("seat")))==0):fail("declaration");return
		game.on_ready()
		if not await until(func():return p("marked_ready",1) and p("marked_ready",2) and p("marked_ready",3)):fail("ready");return
	if role=="host":game.on_start()
	if not await until(func():return p("ready") and p("stage")==2 and p("players")==3):fail("yard");return
	if not await until(func():return balances()==[0,0,0]):fail("fresh wallets");return
	for seat in [1,3]:
		var dx:=p("x",seat)-p("x",2);var dy:=p("y",seat)-p("y",2)
		if dx*dx+dy*dy>56*56:fail("participants outside shared reach");return
	write("yard-"+role,{"ready":true})
	if not await until(func():return all_have("yard")):fail("yard barrier");return
	phase="setup"
	if role=="host":
		if scenario=="funded":assert(game.authoring_grant(1,6))
		elif scenario=="contended":assert(game.authoring_grant(1,3));assert(game.authoring_grant(3,3))
		assert(game.authoring_down(2))
	var initial: Array=[6,0,0] if scenario=="funded" else [3,0,3] if scenario=="contended" else [0,0,0]
	if not await until(func():return balances()==initial and p("hp",2)==0):fail("setup acceptance");return
	total_guard=initial[0]+initial[1]+initial[2]
	write("armed-"+role,{"cash":balances(),"hp":health()})
	if not await until(func():return all_have("armed")):fail("input barrier");return
	phase="hold"
	var donor: bool=role=="host" if scenario=="funded" else role=="helper" if scenario=="funding_while_held" else role!="guest"
	if donor:hold(true)
	if scenario=="funding_while_held":
		phase="unfunded"
		var deadline:=Time.get_ticks_msec()+3000
		while Time.get_ticks_msec()<deadline and not finished:
			sample()
			if p("hp",2)!=0 or balances()!=[0,0,0]:fail("unfunded revive changed state");return
			await process_frame
		if role=="helper" and not str(game.authoring_prompt()).contains("3 scrap"):fail("missing affordability prompt");return
		write("unfunded-"+role,{"cash":balances(),"hp":health()})
		if not await until(func():return all_have("unfunded")):fail("unfunded barrier");return
		total_guard=-1;phase="funding"
		if role=="host":assert(game.authoring_grant(3,3))
		if not await until(func():var m:=balances();return m[0]+m[1]+m[2]==3):fail("live funding");return
		total_guard=3
	phase="result"
	if not await until(func():
		if p("hp",2)!=4:return false
		var m:=balances()
		return m==[3,3,0] if scenario=="funded" else m==[0,3,0] if scenario=="funding_while_held" else m==[0,3,3] or m==[3,3,0]
	):fail("paid revive result");return
	var expected:=balances();write("settled-"+role,{"cash":expected,"hp":health()})
	if not await until(func():return all_have("settled")):fail("settlement barrier");return
	phase="continued_hold"
	var deadline:=Time.get_ticks_msec()+2500
	while Time.get_ticks_msec()<deadline and not finished:
		sample()
		if balances()!=expected or p("hp",2)!=4:fail("repeat charge or changed result");return
		await process_frame
	if donor:hold(false)
	write("success-"+role,{"implementation":implementation,"role":role,"scenario":scenario,"seat":p("seat"),"cash":balances(),"hp":health(),"trace":trace,"inputs":inputs,"conserved_total":total_guard,"unfunded_verified":scenario=="funding_while_held"})
	if not await until(func():return all_have("success")):fail("finish barrier");return
	# All results are settled before any process retires its transport. Stop
	# application/engine polling together so teardown cannot race live sends.
	phase="teardown";game.set_process(false);multiplayer_poll=false
	write("quiesced-"+role,{"ready":true})
	if not await until(func():return all_have("quiesced")):fail("teardown barrier");return
	print("REPLAY_AUTHORING_PEER_OK ",implementation," ",scenario," ",role)
	await finish(0)
