extends SceneTree
var game:Node
var role:=""
var stage:=""
var folder:=""
var finished:=false
func _initialize():
 role=OS.get_environment("RQ_SAVE_ROLE");stage=OS.get_environment("RQ_SAVE_STAGE");folder=OS.get_environment("RQ_SAVE_DIR");run.call_deferred()
func p(key:String,seat:int=1)->int:return int(game.probe(key,seat))
func s(key:String)->int:return int(game.save_probe(key))
func frames(n:int):
 for _i in range(n):await process_frame
func until(test:Callable,ms:int=20000)->bool:
 var deadline:=Time.get_ticks_msec()+ms
 while Time.get_ticks_msec()<deadline:
  if test.call():return true
  await process_frame
 return false
func write(name:String,value:Dictionary):
 var f:=FileAccess.open(folder+"/"+name+".json.tmp",FileAccess.WRITE);f.store_string(JSON.stringify(value));f.close();f=null
 assert(DirAccess.rename_absolute(folder+"/"+name+".json.tmp",folder+"/"+name+".json")==OK)
func exists(name:String)->bool:return FileAccess.file_exists(folder+"/"+name+".json")
func read(name:String)->Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(folder+"/"+name+".json"))
func press(path:String):game.get_node(path).pressed.emit()
func finish(code:int,reason:String):
 if finished:return
 finished=true;write(stage+"-"+role+"-result",{"pass":code==0,"reason":reason})
 print("RQ_SAVE_", "OK" if code==0 else "FAIL", " ",stage," ",role," ",reason)
 game.queue_free();game=null;await frames(3);quit(code)
func run():
 root.size=Vector2i(640,360);game=load("res://quickdraw.tscn").instantiate();root.add_child(game);await frames(3)
 if stage in ["wrong-owner","damaged","missing","room","policy","exhausted"]:
  if stage=="room":game.on_resume_host()
  else:press("UI/Lobby/Column/Resume/Host")
  if game.ui_probe("ready",1)!=0 or game.ui_probe("state_ready",1)!=0:await finish(1,"rejected resume opened a session");return
  var notice:=str(game.get_node("UI/Lobby/Column/Notice").text)
  var expected:String={"wrong-owner":"host profile","damaged":"damaged","missing":"Could not open","room":"direct sessions","policy":"recovery service","exhausted":"another session"}[stage]
  if not expected in notice:await finish(1,"resume explanation: "+notice);return
  await finish(0,notice);return
 if stage=="solo":
  press("UI/Lobby/Column/Resume/Solo")
  if s("exact")!=1 or str(s("restored_hash"))!=read("saved").hash or s("restored_tick")!=int(read("saved").tick):await finish(1,"solo exact frame");return
  if game.feedback_probe("hurt",1)!=0 or game.feedback_probe("landed",1)!=0:await finish(1,"historical feedback on solo resume");return
  await frames(30)
  if p("players")!=1 or not p("boots",1):await finish(1,"solo membership/equipment");return
  await finish(0,"solo restore");return
 if stage=="write":
  game.get_node("UI/Lobby/Column/Name/Value").text="Keeper" if role=="host" else "Partner Ω"
  if role=="host":press("UI/Lobby/Column/Buttons/Host")
  else:
   if not await until(func():return exists("open-write")):await finish(1,"write host barrier");return
   press("UI/Lobby/Column/Buttons/Join")
 else:
  if role=="host":
   press("UI/Lobby/Column/Resume/Host")
   var expected:=read("saved")
   if s("exact")!=1 or str(s("restored_hash"))!=expected.hash or s("restored_tick")!=int(expected.tick) or p("epoch")!=2:await finish(1,"host exact frame");return
   if game.feedback_probe("hurt",1)!=0 or game.feedback_probe("landed",1)!=0:await finish(1,"historical feedback after restore");return
   write("restored",{"tick":s("restored_tick"),"hash":str(s("restored_hash")),"epoch":p("epoch")})
  else:
   if not await until(func():return exists("open-read")):await finish(1,"read host barrier");return
   press("UI/Lobby/Column/Buttons/Join")
 if not await until(func():return p("steady") and game.ui_probe("chat_ready",1)):await finish(1,"admission");return
 game.drive(0,0,0,0,0)
 if role=="host":write("open-"+stage,{"ready":true})
 if not await until(func():return p("players")==2 and "Keeper" in str(game.get_node("UI/Lobby/Column/Roster").text) and "Partner Ω" in str(game.get_node("UI/Lobby/Column/Roster").text)):await finish(1,"named members");return
 if p("seat")!=(1 if role=="host" else 2):await finish(1,"stable seat");return
 write("joined-"+stage+"-"+role,{"ready":true})
 if stage=="write":
  if role=="host":
   if not await until(func():return exists("joined-write-client")):await finish(1,"writer join");return
   press("UI/Lobby/Column/Start")
   if not await until(func():return game.ui_probe("started",1)==1):await finish(1,"start");return
   if not game.purchase():await finish(1,"equipment purchase");return
   game.drive(0,1,0,0,1)
   if not await until(func():return game.ui_probe("y",1)>=298 and p("boots",1)):await finish(1,"firing lane/equipment");return
   game.drive(0,0,1,2,1)
   if not await until(func():return p("hp",2)==0):await finish(1,"saved respawn");return
   game.drive(0,0,4,2,1)
   if not await until(func():return s("combat")==1):await finish(1,"combat save window");return
   game.drive(0,0,0,0,0)
   # Actual keyboard route, with no chat/text focus.
   var event:=InputEventKey.new();event.physical_keycode=KEY_F5;event.keycode=KEY_F5;event.pressed=true;Input.parse_input_event(event)
   await frames(2)
   event=InputEventKey.new();event.physical_keycode=KEY_F5;event.keycode=KEY_F5;event.pressed=false;Input.parse_input_event(event)
   if s("saved_tick")<=0 or not "Saved duel" in str(game.get_node("UI/SaveNotice").text):await finish(1,"F5 save receipt");return
   write("saved",{"tick":s("saved_tick"),"hash":str(s("saved_hash")),"life":p("life",2),"lobs":p("lobs"),"buys":p("buys"),"kills":int(game.ui_probe("kills",1)),"deaths":int(game.ui_probe("deaths",2))})
   var path:=OS.get_environment("RQ_SAVE");var committed:=FileAccess.get_file_as_bytes(path)
   if DirAccess.make_dir_absolute(path+".pending")!=OK:await finish(1,"failed-write setup");return
   if game.on_save() or not "Could not save" in str(game.get_node("UI/SaveNotice").text) or FileAccess.get_file_as_bytes(path)!=committed:await finish(1,"failed write replaced committed save");return
   if DirAccess.remove_absolute(path+".pending")!=OK:await finish(1,"failed-write cleanup");return
   write("saved-ready",{"preserved":true})
  else:
   if game.get_node("UI/Save").visible or game.on_save():await finish(1,"client saved authority");return
  return # The runner kills these exact processes after the durable receipt.
 if not await until(func():return p("hp",2)==3 and p("life",2)>int(read("saved").life)):await finish(1,"saved respawn continuation");return
 if not p("boots",1) or game.ui_probe("kills",1)!=1 or game.ui_probe("deaths",2)!=1:await finish(1,"saved equipment/score");return
 if role=="client":
  if not game.purchase():await finish(1,"new purchase");return
  game.drive(0,0,4,0,-1)
  if not await until(func():return p("lobs")>int(read("saved").lobs)):await finish(1,"new lob");return
  game.drive(0,0,0,0,0);game.on_chat("back after the save")
 if not await until(func():return p("buys")==2 and "Partner Ω: back after the save" in str(game.get_node("UI/Chat/Column/Lines").text)):await finish(1,"new command/chat convergence");return
 game.drive(0,0,0,0,0);write("stopped-"+role,{"ready":true})
 if not await until(func():return exists("stopped-host") and exists("stopped-client") and p("bullets")==0):await finish(1,"drain resumed combat");return
 if role=="host":
  var accepted:=false
  for attempt in range(1,41):
   var tick:=p("head")-30;tick-=tick%3
   var digest:=int(game.probe_hash(tick))
   if tick<0 or digest<0:await frames(3);continue
   write("candidate",{"serial":attempt,"tick":tick,"hash":str(digest)})
   if not await until(func():return exists("candidate-reply") and int(read("candidate-reply").serial)==attempt,1000):await finish(1,"candidate response");return
   var reply:=read("candidate-reply")
   if reply.available:
    if reply.hash!=str(digest):await finish(1,"final canonical world mismatch");return
    write("final-world",{"tick":tick,"hash":str(digest)});accepted=true;break
   await frames(5)
  if not accepted:await finish(1,"no common retained snapshot");return
 else:
  var serial:=0;var deadline:=Time.get_ticks_msec()+25000
  while not exists("final-world") and Time.get_ticks_msec()<deadline:
   if exists("candidate"):
    var candidate:=read("candidate")
    if int(candidate.serial)>serial:
     serial=int(candidate.serial);var digest:=int(game.probe_hash(int(candidate.tick)))
     write("candidate-reply",{"serial":serial,"available":digest>=0,"hash":str(digest)})
   await process_frame
  if not exists("final-world"):await finish(1,"final world barrier");return
 write("done-"+role,{"seat":p("seat"),"epoch":p("epoch"),"buys":p("buys"),"lobs":p("lobs"),"life":p("life",2),"final":read("final-world")})
 if not await until(func():return exists("done-host") and exists("done-client")):await finish(1,"finish barrier");return
 await finish(0,"fresh process combat continuation")
