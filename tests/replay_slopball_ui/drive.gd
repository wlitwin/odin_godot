extends SceneTree
var game:Node
var role:=""
var folder:=""
var finished:=false
func p(key:String,seat:int=1)->int:return int(game.ui_probe(key,seat))
func node(path:String)->Node:return game.get_node(path)
func exists(name:String)->bool:return FileAccess.file_exists(folder+"/"+name)
func mark(name:String):var f:=FileAccess.open(folder+"/"+name,FileAccess.WRITE);f.store_string("ready\n");f.close()
func _initialize():role=OS.get_environment("RSL_UI_ROLE");folder=OS.get_environment("RSL_UI_DIR");run.call_deferred()
func check(condition:bool,label:String)->bool:
 if condition:return true
 print("SLOPBALL_UI_FAIL ",role," ",label);finished=true;quit(1);return false
func until(predicate:Callable,label:String,ms:int=15000)->bool:
 var end:=Time.get_ticks_msec()+ms
 while Time.get_ticks_msec()<end:
  if predicate.call():return true
  await process_frame
 return check(false,label)
func press(path:String):node(path).emit_signal("pressed")
func run():
 root.size=Vector2i(640,360)
 game=load("res://slopball.tscn").instantiate();root.add_child(game);await process_frame
 if not check(node("UI/Lobby").visible and not p("ready"),"initial menu"):return
 node("UI/Lobby/Column/Name/Value").text={"host":"Alpha","client":"Bravo","observer":"Watcher"}[role]
 if role!="host":
  if not await until(func():return exists("host-open"),"host barrier"):return
 press("UI/Lobby/Column/Buttons/"+{"host":"Host","client":"Join","observer":"Watch"}[role])
 if not await until(func():return p("state_ready") and p("chat_ready"),"session admission"):return
 if role=="host":mark("host-open")
 if role!="observer":
  if not await until(func():return p("named",1) and p("named",2),"named roster"):return
 if not await until(func():return node("UI/Lobby/Column/Roster").text.contains("Alpha") and node("UI/Lobby/Column/Roster").text.contains("Bravo"),"roster labels"):return
 if not check(not p("started"),"manual start"):return
 mark("joined-"+role)
 if role=="client":
  game.on_start();var tick:=p("tick")
  if not await until(func():return p("tick")>=tick+30,"reject guest start"):return
  if not check(not p("started"),"guest cannot start"):return
  mark("guest-rejected")
 if role=="host":
  if not await until(func():return exists("joined-client") and exists("joined-observer") and exists("guest-rejected"),"party barrier"):return
  press("UI/Lobby/Column/Start")
 if not await until(func():return p("started") and not node("UI/Lobby").visible,"started everywhere"):return
 Input.action_press("rsl_scores");await process_frame;await process_frame
 if not check(node("UI/Scoreboard").visible,"Tab scores"):return
 if not await until(func():return p("ping_known",1) and p("ping_known",2),"scoreboard ping"):return
 var cells:=node("UI/Scoreboard/Column/Grid").get_children()
 if not check(cells[3].text=="Alpha" and cells[6].text=="Bravo" and cells[4].text=="LEFT" and cells[7].text=="RIGHT","scoreboard rows"):return
 Input.action_release("rsl_scores");await process_frame;await process_frame
 if not check(not node("UI/Scoreboard").visible,"scoreboard release"):return
 if role=="client":
  var x:=p("x",2);Input.action_press("rsl_right")
  if not await until(func():return p("x",2)>x+12,"game movement"):return
  Input.action_release("rsl_right")
  for _i in 60:await process_frame
  var before:=Vector2(p("x",2),p("y",2));var kicks:=p("kicks")
  Input.action_press("rsl_chat");await process_frame;await process_frame;Input.action_release("rsl_chat");await process_frame
  Input.action_press("rsl_right");Input.action_press("rsl_kick")
  for _i in 40:await process_frame
  if not check(Vector2(p("x",2),p("y",2)).distance_to(before)<=1 and p("kicks")==kicks,"typing captures game controls"):return
  for action in ["rsl_right","rsl_kick"]:Input.action_release(action)
  node("UI/Chat/Column/Input").text="[b]goal chat[/b]"
  node("UI/Chat/Column/Input").emit_signal("text_submitted","[b]goal chat[/b]")
 if not await until(func():return node("UI/Chat/Column/Lines").text.contains("Bravo: [b]goal chat[/b]"),"chat everywhere"):return
 if role=="observer":
  if not await until(func():return p("named_observer")==1,"observer naming"):return
  game.on_chat("watching safely")
 if not await until(func():return node("UI/Chat/Column/Lines").text.contains("Watcher (observer): watching safely"),"named observer chat"):return
 if role=="host":game.set_bot("striker")
 if not await until(func():return p("left")+p("right")>0,"nonzero score",45000):return
 game.set_bot("idle")
 var score:="LEFT %d — %d RIGHT"%[p("left"),p("right")]
 if not check(node("UI/Scoreboard/Column/Score").text==score,"authoritative scoreboard score"):return
 if not check(node("UI/Chat/Column/Lines").get_parsed_text().contains("[b]goal chat[/b]"),"literal markup"):return
 mark("chat-"+role)
 if role=="client":
  if not await until(func():return exists("chat-host") and exists("chat-observer"),"chat barrier"):return
  press("UI/Leave")
  if not check(not p("ready") and node("UI/Lobby").visible and node("UI/Chat/Column/Lines").text.is_empty(),"leave resets local session"):return
  mark("client-left")
  if not await until(func():return exists("left-host") and exists("left-observer"),"leave observers"):return
  press("UI/Lobby/Column/Buttons/Join")
  if not await until(func():return p("state_ready") and p("seat")==2 and p("named",2) and p("started"),"rejoin running pitch"):return
  mark("rejoined")
 else:
  if not await until(func():return exists("client-left") and not p("connected",2),"remote departure"):return
  Input.action_press("rsl_scores");await process_frame;await process_frame
  if not check(cells[6].text.contains("Bravo (left)"),"departed scoreboard row"):return
  Input.action_release("rsl_scores");mark("left-"+role)
 if not await until(func():return exists("rejoined") and p("connected",2),"rejoin visible"):return
 if not check(p("left")+p("right")>0,"rejoin keeps score"):return
 if role=="host" and OS.get_environment("RSL_UI_CAPTURE")!="":
  Input.action_press("rsl_scores");await process_frame;await process_frame
  await RenderingServer.frame_post_draw
  var image:=root.get_texture().get_image();image.save_png(OS.get_environment("RSL_UI_CAPTURE"));image=null
  Input.action_release("rsl_scores")
 mark("done-"+role)
 if not await until(func():return exists("done-host") and exists("done-client") and exists("done-observer"),"completion barrier"):return
 if role=="host":
  press("UI/Leave");mark("host-closed")
 else:
  if not await until(func():return exists("host-closed") and node("UI/Lobby").visible and node("UI/Lobby/Column/Notice").text.contains("Connection ended"),"host departure"):return
  if not check(not node("UI/Chat/Column/Input").editable,"chat disabled on disconnect"):return
 game.set_process(false);mark("quiesced-"+role)
 if not await until(func():return exists("quiesced-host") and exists("quiesced-client") and exists("quiesced-observer"),"quiescence"):return
 print("REPLAY_SLOPBALL_UI_PEER_OK role=",role)
 game.queue_free();await process_frame;await process_frame;quit(0)
