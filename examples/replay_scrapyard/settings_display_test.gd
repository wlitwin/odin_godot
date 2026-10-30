extends SceneTree
var bench:Node
var game:Node
var resource_floor:=0
func _initialize():resource_floor=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT));run.call_deferred()
func until(predicate:Callable,ms:int=15000)->bool:
	var end:=Time.get_ticks_msec()+ms
	while Time.get_ticks_msec()<end:
		if predicate.call():return true
		await process_frame
	return false
func finish(code:int,reason:String=""):
	if reason!="":print("RSY_SETTINGS_DISPLAY_FAIL ",reason)
	bench.queue_free();game=null;bench=null;await process_frame;await process_frame;var end:=Time.get_ticks_msec()+2000
	while int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))>resource_floor and Time.get_ticks_msec()<end:await process_frame
	quit(code)
func run():
	bench=load("res://dev/workbench.tscn").instantiate();bench.open_shop=true;bench.menu=true;bench.hurt=true;bench.jam=true;bench.statuses=true;bench.tally=true;root.add_child(bench);game=bench.game_node()
	if not await until(func():return bench.is_staged() and int(game.probe("stage",1))==2):await finish(1,"preview");return
	game.on_volume_down();game.on_shake()
	if int(game.probe("volume",1))!=7 or int(game.probe("shake_off",1))!=1:await finish(1,"settings controls");return
	var original:=DisplayServer.window_get_mode()
	game.on_fullscreen()
	if not await until(func():return DisplayServer.window_get_mode()!=original,5000):await finish(1,"fullscreen did not change");return
	await create_timer(1.0).timeout
	game.on_fullscreen()
	if not await until(func():return DisplayServer.window_get_mode()==original,5000):await finish(1,"fullscreen not restored");return
	var path:=OS.get_environment("RSY_SETTINGS_SPRAY")
	if path!="":
		game.on_spray_file(path)
		if not await until(func():return game.get_node("UI/Menu/Scroll/Column/SprayPreview").texture!=null):await finish(1,"spray preview");return
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	var capture:=OS.get_environment("RSY_SETTINGS_CAPTURE")
	if capture!="" and image.save_png(capture)!=OK:await finish(1,"capture");return
	image=null
	print("REPLAY_SETTINGS_DISPLAY_OK fullscreen_restored=true volume=7 shake_off=true spray_preview=",path!="")
	await finish(0)
