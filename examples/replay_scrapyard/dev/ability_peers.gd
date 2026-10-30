extends SceneTree
var game:Node
var seat:int=0
var marked:bool=false
var equipped:bool=false
var started:bool=false
var casted:bool=false
var captured:bool=false
var captured_hash:int=-1
var finishing:bool=false
var target_tick:int=0
var elapsed:float=0
var role:String=OS.get_environment("RSY_ROLE")
var directory:String=OS.get_environment("RSY_AUTHORING_RESULTS")
var ability:int=int(OS.get_environment("RSY_AUTHORING_ID"))
func _initialize():boot.call_deferred()
func boot():
	game=load("res://main.tscn").instantiate();root.add_child(game)
func p(key:String,who:int=1)->int:return game.probe(key,who)
func fail(message:String):printerr("REPLAY_AUTHORING_PEER_FAIL ",role," ",message);quit(1)
func _process(dt:float)->bool:
	if finishing:return false
	elapsed+=dt
	if elapsed>60:fail("deadline");return false
	if game==null or not p("ready"):return false
	seat=p("seat")
	if p("players")<2:return false
	if p("stage")==0:
		if not equipped:equipped=game.authoring_equip(ability);return false
		if p("ability0",seat)!=ability:return false
		if not marked:game.on_ready();marked=true
		if seat==1 and p("marked_ready",1) and p("marked_ready",2) and not started:game.on_start();started=true
		return false
	if not casted and seat==1:
		game.dev_hurt(1,4)
		casted=game.dev_cast(0,0,0,false)
	if p("casts",1)<1:return false
	if seat==1 and target_tick==0:
		target_tick=((p("head")+92)/3)*3
		var file:=FileAccess.open(directory+"/target.json",FileAccess.WRITE);file.store_string(JSON.stringify({"tick":target_tick}));file=null
	if target_tick==0 and FileAccess.file_exists(directory+"/target.json"):
		target_tick=int(JSON.parse_string(FileAccess.get_file_as_string(directory+"/target.json")).tick)
	if target_tick>0 and p("head")>=target_tick+24 and not captured:
		var hash:int=game.probe_hash(target_tick)
		if hash<0:return false
		captured=true;captured_hash=hash
		var file:=FileAccess.open(directory+"/done-"+role+".json",FileAccess.WRITE);file.store_string(JSON.stringify({"hash":str(hash)}));file=null
	if captured and FileAccess.file_exists(directory+"/done-host.json") and FileAccess.file_exists(directory+"/done-client.json"):
		print("REPLAY_AUTHORING_HASH tick=",target_tick," hash=",captured_hash)
		print("REPLAY_AUTHORING_PEER_OK role=",role," ability=",ability," casts=",p("casts",1))
		finishing=true;finish.call_deferred()
	return false

func finish():
	game.queue_free();game=null
	await process_frame;await process_frame
	await create_timer(.2).timeout
	quit()
