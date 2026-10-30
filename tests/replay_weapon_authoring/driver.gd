extends SceneTree
var game: Node
var role := ""
var implementation := ""
var scenario := ""
var folder := ""
var phase := "boot"
var started := 0
var resource_floor := 0
var seat := 0
var finished := false
var trace := []
var inputs := []
var reloads := 0
var last_mode := -1
var next_sample := 0
var first_hit := {}
var swaps := []
var resource_present := false
const KEYS := ["damage","cooldown","mag","reload","jam","speed","ttl"]
func p(key: String, who := 0) -> int: return int(game.weapon_probe(key,seat if who==0 else who))
func values(key: String) -> Array: return [p(key,1),p(key,2)]
func rect(who: int) -> Array: return [p("region_x",who),p("region_y",who),p("region_w",who),p("region_h",who)]
func write(name: String, value: Dictionary):
	var f:=FileAccess.open(folder+"/"+name+".json.pending",FileAccess.WRITE);f.store_string(JSON.stringify(value));f.close()
	assert(DirAccess.rename_absolute(folder+"/"+name+".json.pending",folder+"/"+name+".json")==OK)
func both(name: String) -> bool: return FileAccess.file_exists(folder+"/"+name+"-host.json") and FileAccess.file_exists(folder+"/"+name+"-client.json")
func sample():
	if game==null or not p("ready"):return
	var mode:=p("local_mode")
	if mode==1 and last_mode!=1:reloads+=1
	last_mode=mode
	if Time.get_ticks_msec()>=next_sample:
		next_sample=Time.get_ticks_msec()+50
		trace.append({"ms":Time.get_ticks_msec()-started,"phase":phase,"spent":values("spent"),"iron":values("iron"),"local_spent":p("local_spent"),"ammo":values("ammo"),"mode":mode,"enemy_hp":p("enemy_hp"),"damage":p("damage_total"),"kills":p("kills_total"),"catalog":p("catalog")})
func until(test: Callable, timeout := 15000) -> bool:
	var deadline:=Time.get_ticks_msec()+timeout
	while Time.get_ticks_msec()<deadline and not finished:
		sample()
		if test.call():return true
		await process_frame
	return false
func fire(held: bool):game.weapon_fire(held);inputs.append({"ms":Time.get_ticks_msec()-started,"held":held,"local_spent":p("local_spent")})
func fail(reason: String):
	if finished:return
	write("failure-"+role,{"phase":phase,"reason":reason,"trace":trace,"inputs":inputs,"spent":values("spent"),"iron":values("iron"),"catalog":p("catalog"),"name":str(game.weapon_name()),"label":str(game.weapon_label())})
	print("WEAPON_AUTHORING_FAIL ",implementation," ",role," ",phase," ",reason);finish(1)
func finish(code: int):
	if finished:return
	finished=true;game.queue_free();game=null;await process_frame;await process_frame
	var deadline:=Time.get_ticks_msec()+2000
	while int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))>resource_floor and Time.get_ticks_msec()<deadline:await process_frame
	quit(code)
func _initialize():
	role=OS.get_environment("WEAPON_ROLE");implementation=OS.get_environment("WEAPON_IMPL");scenario=OS.get_environment("WEAPON_CASE");folder=OS.get_environment("WEAPON_DIR")
	resource_floor=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT));started=Time.get_ticks_msec();run.call_deferred()
func run():
	resource_present=ResourceLoader.exists("res://data/guns/stapler.tres")
	game=load("res://main.tscn").instantiate();root.add_child(game)
	if implementation=="kit":game.call("on_host" if role=="host" else "on_join")
	if not await until(func():return p("seat")>0):fail("admission");return
	seat=p("seat");game.dev_loadout(0,0)
	if implementation=="replay":game.dev_drive(0,0,false)
	write("seated-"+role,{"seat":seat,"resource_present":resource_present})
	if not await until(func():return both("seated") and p("players")==2):fail("roster");return
	if not await until(func():return p("declared",1)==1 and p("declared",2)==1):fail("initial declarations");return
	write("declared-"+role,{"ready":true})
	if not await until(func():return both("declared")):fail("declaration barrier");return
	if implementation=="replay":
		if not await until(func():return int(game.probe("iron",seat))==0 and int(game.probe("look",seat))==0):fail("initial loadout");return
		game.on_ready()
		if not await until(func():return p("marked_ready",1) and p("marked_ready",2)):fail("readiness");return
	if role=="host":game.on_start()
	if not await until(func():return p("ready") and p("stage")==2 and p("catalog")==8):fail("host catalog");return
	if not await until(func():return values("iron")==[0,0]):fail("initial equipped loadout");return
	write("equipped-"+role,{"iron":values("iron")})
	if not await until(func():return both("equipped")):fail("equipped barrier");return
	phase="select"
	for i in range(7):
		var old:=p("iron")
		if not game.weapon_swap():fail("swap submission");return
		if not await until(func():return p("iron")==((old+1)%8)):fail("swap acceptance");return
		swaps.append({"before":old,"after":p("iron")})
	if not await until(func():return values("iron")==[7,7] and rect(1)==[0,48,32,16] and rect(2)==[0,48,32,16] and str(game.weapon_label())=="stapler"):fail("weapon presentation");return
	var definition:={}
	for key in KEYS:definition[key]=p(key)
	if definition!={"damage":3,"cooldown":12,"mag":3,"reload":60,"jam":0,"speed":12,"ttl":30} or str(game.weapon_name())!="stapler":fail("definition values");return
	write("selected-"+role,{"definition":definition,"resource_present":resource_present})
	if not await until(func():return both("selected")):fail("select barrier");return
	phase="target"
	if role=="host":game.weapon_target()
	if not await until(func():return p("enemy_hp")==20 and p("living")==1):fail("training target");return
	write("target-"+role,{"hp":20})
	if not await until(func():return both("target")):fail("target barrier");return
	phase="first_shot"
	if role=="host":
		fire(true)
		if not await until(func():return p("local_spent")>=1):fail("first round");return
		fire(false)
		if p("local_spent")!=1:fail("first-round overshoot");return
	if not await until(func():return p("enemy_hp")==17 and p("damage_total")==3 and values("spent")==[1,0]):fail("single-shot damage");return
	first_hit={"enemy_hp":p("enemy_hp"),"damage":p("damage_total"),"spent":values("spent")}
	write("first-"+role,first_hit)
	if not await until(func():return both("first")):fail("first-shot barrier");return
	phase="fire"
	fire(true)
	if not await until(func():return p("local_spent")>=7):fail("seven rounds");return
	fire(false)
	if p("local_spent")!=7:fail("round overshoot");return
	phase="drain"
	if not await until(func():return values("spent")==[7,7] and values("ammo")==[2,2] and p("living")==0 and p("damage_total")==20 and p("kills_total")==1):fail("drained combat");return
	if reloads<2:fail("two reloads");return
	write("drained-"+role,{"ready":true})
	if not await until(func():return both("drained")):fail("drain barrier");return
	phase="settled"
	var until_ms:=Time.get_ticks_msec()+1000
	while Time.get_ticks_msec()<until_ms:
		sample()
		if values("spent")!=[7,7] or values("ammo")!=[2,2] or values("hp")!=[10,10]:fail("settled state changed");return
		await process_frame
	write("success-"+role,{"implementation":implementation,"role":role,"case":scenario,"seat":seat,"resource_present":resource_present,"definition":definition,"name":str(game.weapon_name()),"label":str(game.weapon_label()),"regions":[rect(1),rect(2)],"first_hit":first_hit,"swaps":swaps,"reloads":reloads,"spent":values("spent"),"ammo":values("ammo"),"damage":p("damage_total"),"kills":p("kills_total"),"trace":trace,"inputs":inputs})
	if not await until(func():return both("success")):fail("finish barrier");return
	game.set_process(false);multiplayer_poll=false;write("quiesced-"+role,{"ready":true})
	if not await until(func():return both("quiesced")):fail("quiescence");return
	print("REPLAY_WEAPON_AUTHORING_PEER_OK ",implementation," ",scenario," ",role)
	await finish(0)
