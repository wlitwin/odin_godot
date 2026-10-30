extends SceneTree
var game:Node
var baseline:=false
var role:=""
var folder:=""
var phase:="boot"
var started:=0
var since:=0
var start_us:=0
var tx_before:=0
var tick_before:=0
var samples:=[]
var resource_floor:=0
var finishing:=false
var ready_submitted:=false
var combat:=false
var firing:=false
var frame_times:=[]
var census_us:=[]
var observation_us:=[]
var combat_started:=false
var seen_enemies:={}
var hurt_seen:=false
var fire_held:=false
var measure_us:=3000000
var trace:=[]
var inputs:=[]
var measured:={}
var reload_entries:=[0,0]
var last_mode:=[0,0]
func _initialize():
	baseline=OS.get_environment("COMPARE_IMPL")=="kit"
	combat=OS.get_environment("COMPARE_SCENARIO")=="combat"
	firing=OS.get_environment("COMPARE_SCENARIO") in ["firing","combat"]
	if firing:measure_us=8000000 if combat else 6000000
	role=OS.get_environment("COMPARE_ROLE");folder=OS.get_environment("COMPARE_DIR")
	resource_floor=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	game=load("res://main.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
func p(key:String,seat:int=1)->int:return int(game.compare_probe(key,seat))
func c(key:String,seat:int=1)->int:return int(game.compare_combat_probe(key,seat))
func write(name:String,value:Dictionary):
	var f:=FileAccess.open(folder+"/"+name+".json.pending",FileAccess.WRITE);f.store_string(JSON.stringify(value));f.close()
	assert(DirAccess.rename_absolute(folder+"/"+name+".json.pending",folder+"/"+name+".json")==OK)
func exists(name:String)->bool:return FileAccess.file_exists(folder+"/"+name+".json")
func fail(reason:String):
	var state:={}
	for key in ["ready","stage","players","seed","mobs","x","y","hp","look","iron","spent","ammo","mode","mag","jam","projectiles"]:state[key]=[p(key,1),p(key,2)]
	write("failure-"+role,{"reason":reason,"phase":phase,"state":state,"inputs":inputs,"trace":trace,"measurement":measured})
	print("COMPARE_FAIL ",role," ",phase," ",reason," state=",JSON.stringify(state));finish(1)
func finish(code:int):
	if finishing:return
	finishing=true;game.set_process(false);game.queue_free()
	await process_frame;await process_frame
	var until:=Time.get_ticks_msec()+2000
	while int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))>resource_floor and Time.get_ticks_msec()<until:await process_frame
	quit(code)
func invariant()->bool:
	if p("stage")!=2 or (not combat and p("mobs")!=0) or p("players")!=2 or p("seed")!=1337:return false
	for seat in [1,2]:
		if p("x",seat)!=800+seat*40 or p("y",seat)!=544 or (p("hp",seat)<=0 or p("hp",seat)>10 if combat else p("hp",seat)!=10) or p("iron",seat)!=0 or p("look",seat)!=0:return false
	if firing:
		for seat in [1,2]:
			if p("mag",seat)!=3 or p("jam",seat)!=0 or p("reload",seat)!=72 or p("cooldown",seat)!=20:return false
			if p("ammo",seat)<0 or p("ammo",seat)>3 or p("mode",seat)==2:return false
	return true
func firing_sample():
	var modes:=[p("mode",1),p("mode",2)]
	for i in 2:
		if modes[i]==1 and last_mode[i]!=1:reload_entries[i]+=1
	last_mode=modes
	trace.append({"us":Time.get_ticks_usec()-start_us,"tick":p("tick"),"projectiles":p("projectiles"),
		"baseline_misses":0 if baseline else p("baseline_misses"),"resyncs":0 if baseline else p("resyncs"),"facts_head":0 if baseline else p("facts_head"),"latest_snapshot":0 if baseline else p("latest_snapshot"),"rejected_packets":0 if baseline else p("rejected_packets"),
		"input_turnaround_ms":0 if baseline else p("input_turnaround_ms"),"arrival_lead_milli":0 if baseline else p("arrival_lead_milli"),"clock_scale_milli":1000 if baseline else p("clock_scale_milli"),"timing_samples":0 if baseline else p("timing_samples"),"lead_updates":0 if baseline else p("lead_updates"),
		"lead_ticks":0 if baseline else p("lead_ticks"),"prediction_depth":0 if baseline else p("prediction_depth"),"replayed_ticks":0 if baseline else p("replayed_ticks"),
		"spent":[p("spent",1),p("spent",2)],"ammo":[p("ammo",1),p("ammo",2)],"mode":modes})
func combat_sample():
	var capture_started:=Time.get_ticks_usec();game.compare_census();census_us.append(Time.get_ticks_usec()-capture_started)
	var began:=Time.get_ticks_usec()
	var enemies:=[]
	for index in c("bodies"):
		var value:Vector3=game.compare_enemy(index);var id:=str(game.compare_enemy_id(index));var kind:=int(game.compare_enemy_kind(index))
		enemies.append({"id":id,"x":value.x,"y":value.y,"hp":value.z,"kind":kind})
		seen_enemies[id]=true
	var health:=[p("hp",1),p("hp",2)];hurt_seen=hurt_seen or health[0]<10 or health[1]<10
	trace[-1]["combat"]={"enemies":enemies,"living":c("living"),"drops":c("drops"),"loot":c("loot"),"hp":health,
		"damage":[c("damage",1),c("damage",2)],"kills":[c("kills",1),c("kills",2)],"scrap":[c("scrap",1),c("scrap",2)]}
	observation_us.append(Time.get_ticks_usec()-began)
func begin_measure():
	game.compare_start();start_us=Time.get_ticks_usec();tx_before=int(game.compare_tx());tick_before=p("tick");phase="measure"
	if firing:
		firing_sample()
		if combat:
			combat_sample()
			if role=="host":game.compare_spawn()
		else:hold_trigger()
func hold_trigger():
	game.compare_trigger(true);fire_held=true
	inputs.append({"us":Time.get_ticks_usec()-start_us,"fire":true,"aim":"nearest-living-enemy" if combat else [1,0]})
func release_trigger():
	if not fire_held:return
	game.compare_trigger(false);fire_held=false
	inputs.append({"us":Time.get_ticks_usec()-start_us,"fire":false,"aim":"nearest-living-enemy" if combat else [1,0]})
func record_result():
	measured["invariants"]=true
	if firing:
		measured["workload"]={"shots":[p("spent",1),p("spent",2)],"ammo":[p("ammo",1),p("ammo",2)],"reload_entries":reload_entries,
			"inputs":inputs,"observations":trace,"drained":true}
	if combat:
		measured["frame_at_us"]=frame_times;measured["census_us"]=census_us;measured["observation_us"]=observation_us
		measured["workload"]["combat"]={"unique_enemies":seen_enemies.size(),"hurt_seen":hurt_seen,"damage":[c("damage",1),c("damage",2)],"kills":[c("kills",1),c("kills",2)],"scrap":[c("scrap",1),c("scrap",2)],"drops":c("drops"),"living":c("living")}
	write(role,measured);print("COMPARE_MEASURED ",role);phase="done"
func _process(_delta:float)->bool:
	if finishing:return false
	if combat:
		if phase!="measure":game.compare_census()
		if c("census_overflow") or c("spawn_failed"):fail("combat adapter capacity/submission");return false
	var now:=Time.get_ticks_msec()
	if now-started>30000:fail("timeout");return false
	match phase:
		"boot":
			if baseline:game.call("on_host" if role=="host" else "on_join")
			phase="seat"
		"seat":
			var seated:=bool(game.is_seated()) if baseline else int(game.probe("ready",1))!=0
			if seated:
				game.dev_loadout(0,0)
				if not baseline:game.dev_drive(0,0,false)
				write("seated-"+role,{"ready":true});since=now;phase="start"
		"start":
			if not exists("seated-host") or not exists("seated-client") or now-since<500:return false
			if p("declared",1)!=1 or p("declared",2)!=1:return false
			if baseline:
				if role=="host":game.on_start()
			else:
				if int(game.probe("iron",1))!=0 or int(game.probe("iron",2))!=0:return false
				if not ready_submitted:game.on_ready();ready_submitted=true
				if role=="host" and int(game.probe("marked_ready",1)) and int(game.probe("marked_ready",2)):game.on_start()
			if p("ready"):phase="warmup";since=now
		"warmup":
			# The receive-side world must have caught up before measuring steady
			# work. A valid scene can otherwise still be displaying queued snapshots.
			if not baseline and role=="client":
				if p("prediction_depth")>p("lead_ticks")+4 or p("facts_head")-p("tick")>4:since=now
			if combat and not c("stats_ready"):since=now
			if now-since>=500:
				if not invariant():fail("initial world mismatch");return false
				if firing:write("armed-"+role,{"ready":true});phase="arm"
				else:begin_measure()
		"arm":
			if exists("armed-host") and exists("armed-client"):begin_measure()
		"measure":
			if not invariant():fail("world invariant changed");return false
			if firing:
				firing_sample()
				if combat:
					combat_sample()
					if not combat_started and hurt_seen:hold_trigger();combat_started=true
				if fire_held and p("spent",1 if role=="host" else 2)>=9:release_trigger()
				if trace.size()>1024 or p("projectiles")>4:fail("projectile/sample bound");return false
			if Time.get_ticks_usec()-start_us>=measure_us:
				game.compare_stop();var elapsed:=Time.get_ticks_usec()-start_us
				var n:=int(game.compare_sample(-1));if n<100 or game.compare_sample(-2)!=0:fail("sample count/overflow");return false
				for i in n:
					samples.append(int(game.compare_sample(i)))
					if combat:frame_times.append(int(game.compare_sample_time(i))-start_us)
				measured={"implementation":"kit" if baseline else "replay","role":role,"elapsed_us":elapsed,"tx_bytes":int(game.compare_tx())-tx_before,"ticks":p("tick")-tick_before,"frame_us":samples}
				if firing:
					release_trigger();since=now;phase="drain"
				else:record_result()
		"drain":
			if not invariant():fail("drain invariant changed");return false
			if now-since>4000:fail("drain timeout");return false
			if p("projectiles")>0 or p("mode",1)!=0 or p("mode",2)!=0:return false
			if p("spent",1)!=9 or p("spent",2)!=9:fail("held-trigger shot count");return false
			if combat:
				if c("living") or c("bodies") or c("drops"):return false
				if c("damage",1)+c("damage",2)!=12 or c("kills",1)+c("kills",2)!=4 or c("scrap",1)+c("scrap",2)!=12:return false
				if seen_enemies.size()!=4 or not hurt_seen:fail("combat paths unexercised");return false
			if reload_entries[0]<2 or reload_entries[1]<2:fail("reload path unexercised");return false
			record_result()
		"done":
			if exists("host") and exists("client"):print("COMPARE_OK ",role);finish(0)
	return false
