extends SceneTree
var game:Node
var role:=""
var phase:="menu"
var folder:=""
var started:=0
var closing:=false
var save_before:=0
func _initialize():
	role=OS.get_environment("RSB_RESTORE_ROLE");folder=OS.get_environment("RSB_RESTORE_DIR")
	game=load("res://speedball.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec();game.set_bot("idle")
func p(key:String,seat:int=1)->int:return int(game.probe(key,seat))
func party(key:String)->int:return int(game.party_probe(key))
func press(path:String):game.get_node(path).pressed.emit()
func exists(name:String)->bool:return FileAccess.file_exists(folder+"/"+name)
func write(name:String,value:String="done"):
	var f:=FileAccess.open(folder+"/"+name,FileAccess.WRITE);f.store_string(value);f.close()
func finish(code:int,why:String=""):
	if closing:return
	if why!="":print("RSB_PARTY_RESTORE_FAIL role=",role," phase=",phase," ",why)
	closing=true;game.queue_free();game=null;await process_frame;await process_frame;quit(code)
func _process(_dt:float)->bool:
	if closing:return false
	if Time.get_ticks_msec()-started>100000:finish(1,"timeout");return false
	if party("failed") or party("restore_error") or party("save_error"):finish(1,"party/restore/save failure");return false
	if not party("profile_ready") or not party("recent"):return false
	match phase:
		"menu":
			game.get_node("UI/Lobby/Column/Name/Value").text="Saved Captain" if role!="guest" else "New Striker"
			if role=="source":press("UI/Lobby/Column/Buttons/Host");phase="source_joined"
			elif role=="restored":press("UI/Lobby/Column/Party/Choices/Rejoin");phase="restored"
			elif exists("restored-ready"):
				game.get_node("UI/Lobby/Column/Party/Code").text=FileAccess.get_file_as_string(folder+"/invite")
				press("UI/Lobby/Column/Buttons/Join");phase="guest_joined"
		"source_joined":
			if not p("state_ready") or not p("chat_ready") or not p("named",1) or not party("invited"):return false
			write("invite",game.get_node("UI/Lobby/Column/Party/Code").text)
			press("UI/Lobby/Column/Start");game.set_bot("striker");phase="score"
		"score":
			if p("winner")==0:return false
			game.set_bot("idle")
			if not game.get_node("UI/Save").visible or game.get_node("UI/Save").disabled:finish(1,"host save control unavailable");return false
			press("UI/Save");phase="source_save"
		"source_save":
			if party("save_completed")==0:return false
			var data={"tick":party("save_tick"),"round":p("round"),"left":p("left"),"right":p("right"),"winner":p("winner"),"kicks":p("kicks"),"incarnation":party("incarnation"),"profile":str(game.profile_hash())}
			write("saved.json",JSON.stringify(data));print("RSB_PARTY_RESTORE_SOURCE_OK tick=",data.tick," round=",data.round," left=",data.left," right=",data.right," kicks=",data.kicks);finish(0)
		"restored":
			if not p("state_ready") or not game.recovery_probe("steady") or not p("chat_ready"):return false
			var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/saved.json"))
			if game.recovery_probe("epoch")!=2 or not party("restore_publication") or party("restore_tick")!=int(expected.tick) or party("incarnation")<=int(expected.incarnation):finish(1,"wrong restored authority");return false
			for key in ["round","left","right","winner","kicks"]:
				if p(key)!=int(expected[key]):finish(1,"saved "+key+" changed");return false
			if str(game.profile_hash())!=str(expected.profile) or not party("separate") or p("seat")!=1:finish(1,"profile/seat changed");return false
			print("RSB_PARTY_RESTORE_RESUMED_OK epoch=2 incarnation=",party("incarnation")," tick=",party("restore_tick")," round=",p("round")," score=",p("left")+p("right"))
			write("restored-ready");phase="wait_guest"
		"guest_joined":
			if not p("state_ready") or not p("chat_ready") or not p("named",2):return false
			if p("seat")!=2 or p("round")!=1 or p("winner")==0 or game.on_save():finish(1,"guest role/restored state");return false
			write("guest-ready");phase="guest_round"
		"wait_guest":
			if not exists("guest-ready") or not p("connected",2) or not p("named",2):return false
			if not game.get_node("UI/Again").visible:finish(1,"restart control missing");return false
			press("UI/Again");game.set_bot("striker");phase="round_two"
		"guest_round":
			if p("round")!=2 or not p("started"):return false
			game.on_chat("restored match restarted");write("guest-round");phase="guest_wait"
		"round_two":
			if not exists("guest-round") or p("round")!=2 or p("winner")==0:return false
			game.set_bot("idle")
			if not game.get_node("UI/Chat/Column/Lines").text.contains("New Striker: restored match restarted"):return false
			save_before=party("save_completed");press("UI/Save");phase="save_again"
		"save_again":
			if party("save_completed")<=save_before:return false
			if party("save_revision")<2 or party("save_epoch")!=2:finish(1,"continued publication");return false
			print("RSB_PARTY_RESTORE_CONTINUED_OK epoch=2 round=2 revision=",party("save_revision")," score=",p("left")+p("right")," kicks=",p("kicks"));write("host-done");finish(0)
		"guest_wait":
			if exists("host-done"):print("RSB_PARTY_RESTORE_GUEST_OK epoch=2 round=",p("round")," chat=true");finish(0)
	return false
