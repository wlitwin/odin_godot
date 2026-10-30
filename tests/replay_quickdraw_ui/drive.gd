extends SceneTree
var game:Node
var role:=""
var folder:=""
var finished:=false
var records:=[]
func _initialize():
 role=OS.get_environment("RQ_UI_ROLE");folder=OS.get_environment("RQ_UI_DIR");run.call_deferred()
func p(key:String,seat:int=1)->int:return int(game.ui_probe(key,seat))
func write(name:String,data:Dictionary):
 var file:=FileAccess.open(folder+"/"+name+".json.tmp",FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close();file=null
 assert(DirAccess.rename_absolute(folder+"/"+name+".json.tmp",folder+"/"+name+".json")==OK)
func exists(name:String)->bool:return FileAccess.file_exists(folder+"/"+name+".json")
func until(test:Callable,ms:int=15000)->bool:
 var deadline:=Time.get_ticks_msec()+ms
 while Time.get_ticks_msec()<deadline:
  if test.call():return true
  await process_frame
 return false
func frames(n:int):
 for _i in range(n):await process_frame
func key(code:Key,down:bool):
 var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=down;Input.parse_input_event(e)
func tap(code:Key):key(code,true);await frames(2);key(code,false);await frames(2)
func mouse(e:InputEvent):
 Input.parse_input_event(e)
 if DisplayServer.get_name()=="headless":root.push_input(e,true)
func click(path:String):
 var button:Button=game.get_node(path);var point:=button.get_global_rect().get_center()
 if DisplayServer.get_name()!="headless":Input.warp_mouse(point)
 var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;mouse(motion);await frames(2)
 var e:=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;mouse(e)
 await frames(2)
 e=InputEventMouseButton.new();e.position=point;e.global_position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=false;mouse(e)
 await frames(2)
func record(name:String):
 var roster:=str(game.get_node("UI/Lobby/Column/Roster").text)
 records.append({"name":name,"tick":p("tick"),"players":p("players"),"seat":p("seat"),"started":p("started"),"roster":roster,"chat":str(game.get_node("UI/Chat/Column/Lines").text),"kills":[p("kills",1),p("kills",2)],"deaths":[p("deaths",1),p("deaths",2)],"gold":[p("gold",1),p("gold",2)]})
func finish(code:int,reason:String=""):
 if finished:return
 finished=true
 if code!=0 and is_instance_valid(game):record("failure")
 write("result-"+role,{"pass":code==0,"reason":reason,"records":records})
 print("RQ_UI_", "OK" if code==0 else "FAIL", " ",role," ",reason)
 game.queue_free();game=null;await frames(3);quit(code)
func lines()->String:return str(game.get_node("UI/Chat/Column/Lines").text)
func ready_names()->bool:return "Grit" in str(game.get_node("UI/Lobby/Column/Roster").text) and "Ada Ω" in str(game.get_node("UI/Lobby/Column/Roster").text)
func run():
 root.size=Vector2i(640,360)
 game=load("res://quickdraw.tscn").instantiate();root.add_child(game);await frames(3)
 if p("ready")!=0 or not game.get_node("UI/Lobby").visible:await finish(1,"front door");return
 game.get_node("UI/Lobby/Column/Name/Value").text={"host":"Grit","guest":"Ada Ω","observer":"Lookout"}[role]
 if role=="host":
  game.get_node("UI/Lobby/Column/Name/Value").text="   "
  await click("UI/Lobby/Column/Buttons/Host")
  if p("ready")!=0 or not "display name" in str(game.get_node("UI/Lobby/Column/Notice").text):await finish(1,"invalid name accepted");return
  game.get_node("UI/Lobby/Column/Name/Value").text="Grit";await click("UI/Lobby/Column/Buttons/Host")
  if not await until(func():return p("state_ready") and p("players")==1 and p("chat_ready")):await finish(1,"host open");return
  write("host-open",{"ready":true})
 elif role=="guest":
  if not await until(func():return exists("host-open")):await finish(1,"host barrier");return
  await click("UI/Lobby/Column/Buttons/Join")
 else:
  if not await until(func():return exists("chat-host") and exists("chat-guest")):await finish(1,"late observer barrier");return
  await click("UI/Lobby/Column/Buttons/Watch")
 if not await until(func():return p("state_ready") and p("players")==2 and p("chat_ready") and ready_names()):await finish(1,"admission/names");return
 record("admitted")
 if role=="guest":
  game.on_start();var tick:=p("tick")
  if not await until(func():return p("tick")>=tick+30):await finish(1,"refusal timing");return
  if p("started")!=0:await finish(1,"guest started duel");return
  write("guest-refused",{"tick":p("tick")})
 if role=="host":
  if not await until(func():return exists("guest-refused")):await finish(1,"start refusal barrier");return
  if p("started")!=0:await finish(1,"automatic start from menu");return
  if not await until(func():return not game.get_node("UI/Lobby/Column/Start").disabled):await finish(1,"start button");return
  await click("UI/Lobby/Column/Start")
 if not await until(func():return p("started")==1 and not game.get_node("UI/Lobby").visible):await finish(1,"start");return
 if role in ["host","guest"]:
  await tap(KEY_ENTER)
  if not p("typing"):await finish(1,"Enter focus");return
  var seat:=p("seat");var before:=[p("x",seat),p("drone_x",seat),p("shots"),p("lobs"),p("gold",seat)]
  for code in [KEY_D,KEY_L,KEY_SPACE,KEY_B]:key(code,true)
  Input.action_press("rq_fire");Input.action_press("rq_lob")
  var tick:=p("tick")
  if not await until(func():return p("tick")>=tick+30):await finish(1,"live typing clock");return
  for code in [KEY_D,KEY_L,KEY_SPACE,KEY_B]:key(code,false)
  Input.action_release("rq_fire");Input.action_release("rq_lob")
  var after:=[p("x",seat),p("drone_x",seat),p("shots"),p("lobs"),p("gold",seat)]
  if before!=after or p("boots",seat)!=0 or p("dash",seat)!=0:await finish(1,"typing leaked gameplay");return
  var input:LineEdit=game.get_node("UI/Chat/Column/Input");input.text="draft"
  await tap(KEY_ESCAPE)
  if p("typing") or input.text!="draft":await finish(1,"Escape focus/draft");return
  await tap(KEY_ENTER)
  input.text="[b]ready[/b]" if role=="host" else "hello Ω";input.text_submitted.emit(input.text)
  if input.text!="" or input.has_focus():await finish(1,"submit focus");return
  if not await until(func():return "Grit: [b]ready[/b]" in lines() and "Ada Ω: hello Ω" in lines()):await finish(1,"named literal chat");return
  if game.get_node("UI/Chat/Column/Lines").bbcode_enabled or not "[b]ready[/b]" in game.get_node("UI/Chat/Column/Lines").get_parsed_text():await finish(1,"chat markup");return
  write("chat-"+role,{"ready":true});record("typing_chat")
 else:
  if p("seat")!=0 or p("players")!=2 or not "Watching" in str(game.get_node("Status").text):await finish(1,"observer controls/seat");return
  if not await until(func():return "Grit: [b]ready[/b]" in lines() and "Ada Ω: hello Ω" in lines()):await finish(1,"late history");return
  if not await until(func():return p("named_observer")==1):await finish(1,"observer name negotiation");return
  game.on_chat("watching Ω")
 if not await until(func():return "Lookout (observer): watching Ω" in lines()):await finish(1,"observer label");return
 if role=="host":
  game.drive(0,1,0,0,0)
  if not await until(func():return p("y",1)>=298):await finish(1,"clear firing lane");return
  game.drive(0,0,1,2,0)
  if not await until(func():return p("kills",1)==1):await finish(1,"live scoreboard kill");return
  game.drive(0,0,0,0,0)
 if not await until(func():return p("kills",1)==1 and p("deaths",2)==1 and p("gold",1)==2):await finish(1,"score authority convergence");return
 await tap(KEY_TAB)
 key(KEY_TAB,true);await frames(2)
 var panel:Control=game.get_node("UI/Scoreboard")
 if not panel.visible:await finish(1,"Tab scoreboard");return
 var grid:GridContainer=game.get_node("UI/Scoreboard/Column/Grid")
 if str(grid.get_child(5).text)!="Grit" or str(grid.get_child(10).text)!="Ada Ω":await finish(1,"scoreboard names");return
 if str(grid.get_child(6).text)!="1" or str(grid.get_child(12).text)!="1" or str(grid.get_child(8).text)!="2":await finish(1,"nonzero scoreboard values");return
 if not await until(func():return p("ping_known",1) and p("ping_known",2)):await finish(1,"round-trip rows");return
 record("scoreboard")
 if OS.get_environment("RQ_UI_CAPTURE")!="":
  await RenderingServer.frame_post_draw
  var image:=root.get_texture().get_image();var error:=image.save_png(OS.get_environment("RQ_UI_CAPTURE"));image=null
  if error!=OK:await finish(1,"scoreboard capture");return
 key(KEY_TAB,false);await frames(2)
 if panel.visible:await finish(1,"scoreboard release");return
 write("score-"+role,{"ready":true})
 if not await until(func():return exists("score-host") and exists("score-guest") and exists("score-observer")):await finish(1,"score barrier");return
 if role=="guest":
  await click("UI/Leave")
  if p("ready")!=0 or not game.get_node("UI/Lobby").visible:await finish(1,"leave menu");return
  write("guest-left",{"ready":true})
  if not await until(func():return exists("left-observed")):await finish(1,"departure barrier");return
  await click("UI/Lobby/Column/Buttons/Join")
  if not await until(func():return p("seat")==2 and p("players")==2 and p("started")==1 and p("chat_ready")):await finish(1,"same identity rejoin");return
  game.on_chat("back again")
 else:
  if not await until(func():return exists("guest-left") and p("connected",2)==0):await finish(1,"departure");return
  if str(grid.get_child(10).text)!="Ada Ω (left)":await finish(1,"departed row");return
  if role=="host":write("left-observed",{"ready":true})
 if not await until(func():return "Ada Ω: back again" in lines() and p("players")==2):await finish(1,"rejoined chat");return
 if p("deaths",2)!=1 or p("kills",1)!=1:await finish(1,"rejoin reset score");return
 record("rejoined");write("done-"+role,{"ready":true})
 if not await until(func():return exists("done-host") and exists("done-guest") and exists("done-observer")):await finish(1,"finish barrier");return
 await finish(0,"front door start input chat scores observer leave and rejoin")
