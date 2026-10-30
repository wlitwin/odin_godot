extends SceneTree
var game:Node
var label:Label
var port:=""
func _initialize():run.call_deferred()
func finish(code:int,reason:String=""):
	if reason!="":print("REPLAY_DEBUG_PORT_FAIL ",reason)
	game.queue_free();game=null;label=null;await process_frame;await process_frame;quit(code)
func until(predicate:Callable,ms:int=15000)->bool:
	var end:=Time.get_ticks_msec()+ms
	while Time.get_ticks_msec()<end:
		if predicate.call():return true
		await process_frame
	return false
func run():
	port=OS.get_environment("DEBUG_PORT")
	game=load("res://hello.tscn" if port=="hello" else "res://cave.tscn").instantiate();game.debug_enabled=true;root.add_child(game)
	if not await until(func():return game.probe_tick()>30 if port=="hello" else game.probe_ready() and game.probe_head()>30):await finish(1,"runner not ready");return
	for node in game.find_children("*","Label",true,false):
		if str(node.text).begins_with("REPLAY DIAGNOSTICS"):label=node;break
	if label==null:await finish(1,"overlay missing");return
	var event:=InputEventKey.new();event.keycode=KEY_F9;event.physical_keycode=KEY_F9;event.pressed=true;Input.parse_input_event(event)
	await process_frame;await process_frame
	event=InputEventKey.new();event.keycode=KEY_F9;event.physical_keycode=KEY_F9;event.pressed=false;Input.parse_input_event(event)
	if not await until(func():return "Audit: None" in str(label.text),3000):await finish(1,"audit report: "+str(label.text));return
	if port=="cave" and not "TX " in str(label.text):await finish(1,"network counters missing");return
	print("REPLAY_DEBUG_PORT_OK port=",port," role=",OS.get_environment("REPLAY_CAVE_ROLE")," report=",str(label.text).replace("\n"," | "))
	if port=="cave":
		var directory:=OS.get_environment("DEBUG_PORT_DIR")
		var file:=FileAccess.open(directory+"/"+OS.get_environment("REPLAY_CAVE_ROLE")+".done",FileAccess.WRITE);file.store_string("audited");file.close();file=null
		if not await until(func():return FileAccess.file_exists(directory+"/host.done") and FileAccess.file_exists(directory+"/client.done"),5000):await finish(1,"peer audit barrier");return
	await finish(0)
