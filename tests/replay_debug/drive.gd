extends SceneTree
var game:Node
func _initialize():run.call_deferred()
func key(code:Key):
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true;Input.parse_input_event(event)
	await process_frame;await process_frame
	event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=false;Input.parse_input_event(event)
	await process_frame
func finish(code:int,reason:String=""):
	if reason!="":print("REPLAY_DEBUG_FAIL ",reason)
	game.queue_free();game=null;await process_frame;await process_frame;quit(code)
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	game.set_fault(true);await key(KEY_F9)
	await create_timer(0.3).timeout
	var text:=str(game.report().text)
	if game.probe("audits")!=1 or game.probe("tick")!=2 or game.probe("inventory")!=7:await finish(1,"capture changed history or wrong tick");return
	if not "Diverged_State" in text or not "$.inventory[1]: 7 -> 8" in text:await finish(1,"missing field evidence");return
	var capture:=OS.get_environment("REPLAY_DEBUG_CAPTURE")
	if capture!="":
		await RenderingServer.frame_post_draw
		var image:=root.get_texture().get_image();var result:=image.save_png(capture);image=null
		if result!=OK:await finish(1,"capture");return
	await key(KEY_F8);await key(KEY_F9)
	if game.probe("visible")!=0 or game.probe("audits")!=1:await finish(1,"hidden audit");return
	game.set_fault(false);await key(KEY_F8);await key(KEY_F9);await create_timer(0.3).timeout
	if game.probe("audits")!=2 or game.probe("error")!=0 or not "Audit: None" in str(game.report().text):await finish(1,"successful audit");return
	print("REPLAY_DEBUG_OK tick=2 field=inventory[1] expected=7 actual=8 history_preserved=true")
	await finish(0)
