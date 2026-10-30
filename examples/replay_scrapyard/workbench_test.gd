extends SceneTree
var bench:Node
var game:Node
var started:=0
var resource_floor:=0
var original_role:=""
var original_save:=""
var case:=""
func _initialize():
	case=OS.get_environment("WB_CASE")
	original_role=OS.get_environment("RSY_ROLE");original_save=OS.get_environment("RSY_SAVE")
	resource_floor=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	run.call_deferred()
func p(key:String)->int:return int(game.probe(key,1))
func until(predicate:Callable,ms:int=15000)->bool:
	var deadline:=Time.get_ticks_msec()+ms
	while Time.get_ticks_msec()<deadline:
		if predicate.call():return true
		await process_frame
	return false
func finish(code:int,reason:String=""):
	if reason!="":print("RSY_WORKBENCH_FAIL ",reason)
	bench.queue_free();game=null;bench=null
	await process_frame;await process_frame
	var deadline:=Time.get_ticks_msec()+2000
	while int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))>resource_floor and Time.get_ticks_msec()<deadline:await process_frame
	if OS.get_environment("RSY_ROLE")!=original_role or OS.get_environment("RSY_SAVE")!=original_save:
		print("RSY_WORKBENCH_FAIL environment not restored");code=1
	quit(code)
func key(code:Key,pressed:bool):
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func run():
	bench=load("res://dev/workbench.tscn").instantiate()
	bench.open_shop=true
	match case:
		"boss":bench.boss=true
		"wipe":bench.wipe=true
		_:bench.statuses=true;bench.hurt=true;bench.jam=true;bench.kegs=2;bench.menu=true;bench.note=true;bench.tally=true
	root.add_child(bench);game=bench.game_node()
	if game==null:await finish(1,"no real game child");return
	if not await until(func():return bench.is_staged()):await finish(1,"preview not confirmed");return
	if case=="boss":
		if not await until(func():return p("mobs")==1 and p("stage")==1):await finish(1,"boss does not hold combat");return
	elif case=="wipe":
		if not await until(func():return p("stage")==3 and p("hp")==0):await finish(1,"wipe did not use normal run transition");return
	else:
		if not await until(func():return p("stage")==2):await finish(1,"shop never cleared");return
		if p("hp")!=5 or p("gun_mode")!=2 or p("props")!=2 or p("scrap")<500 or p("cores")<20 or p("fx_mask")&24!=24:
			await finish(1,"preview values");return
		if not game.get_node("UI/Shop").visible or not game.get_node("UI/Menu").visible or not game.get_node("UI/Tally").visible:
			await finish(1,"panels not showing actual state");return
		var hud := game.get_node("UI/CombatHUD")
		if hud.get_node("Vitals/Text").text != "5/10" or not "JAMMED" in hud.get_node("Ammo/State").text or not hud.get_node("Vitals/St0").visible or not hud.get_node("Vitals/St1").visible:
			await finish(1,"preview states absent from HUD");return
		var capture:=OS.get_environment("WB_CAPTURE")
		if capture!="":
			await RenderingServer.frame_post_draw
			var picture:=root.get_texture().get_image()
			if picture.save_png(capture)!=OK:await finish(1,"screenshot");return
		var x:=p("x");var head:=p("head");game.dev_drive(1,0,false)
		await create_timer(0.3).timeout
		if p("x")!=x or p("head")<=head+5:await finish(1,"menu must block local input while simulation advances");return
		game.dev_drive(0,0,false)
		key(KEY_ESCAPE,true);await process_frame;await process_frame;key(KEY_ESCAPE,false)
		if p("menu_open")!=0:await finish(1,"Esc did not close menu");return
		key(KEY_TAB,true);await process_frame;await process_frame
		if p("tally_open")!=1:await finish(1,"Tab did not open tally");return
		key(KEY_TAB,false);await process_frame;await process_frame
		if p("tally_open")!=0:await finish(1,"Tab release did not close tally");return
		await create_timer(2.2).timeout
		if p("fx_mask")&24!=24 or p("status_applied")<4:await finish(1,"statuses did not refresh through actions");return
	print("REPLAY_SCRAPYARD_WORKBENCH_OK case=",case," head=",p("head")," stage=",p("stage"))
	await finish(0)
