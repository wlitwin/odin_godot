extends SceneTree
var game:Node
var role:=""
var stage:=""
var folder:=""
var finished:=false
func _initialize():
 role=OS.get_environment("RSL_SAVE_ROLE");stage=OS.get_environment("RSL_SAVE_STAGE");folder=OS.get_environment("RSL_SAVE_DIR");run.call_deferred()
func p(key:String,seat:int=1)->int:return int(game.probe("epoch")) if key=="epoch" else int(game.ui_probe(key,seat))
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
 print("RSL_SAVE_", "OK" if code==0 else "FAIL", " ",stage," ",role," ",reason)
 game.queue_free();game=null;await frames(3);quit(code)
func run():
 root.size=Vector2i(640,360);game=load("res://slopball.tscn").instantiate();root.add_child(game);await frames(3)
 if stage in ["wrong-owner","damaged","missing","policy","exhausted","room"]:
  if stage=="room":game.on_resume_host()
  else:press("UI/Lobby/Column/Resume/Host")
  if p("ready")!=0 or p("state_ready")!=0:await finish(1,"rejected resume opened a session");return
  var notice:=str(game.get_node("UI/Lobby/Column/Notice").text)
  var expected:String={"wrong-owner":"host profile","damaged":"damaged","missing":"Could not open","policy":"recovery service","exhausted":"another session","room":"direct sessions"}[stage]
  if not expected in notice:await finish(1,"resume explanation: "+notice);return
  await finish(0,notice);return
 if stage=="solo":
  press("UI/Lobby/Column/Resume/Solo")
  if s("exact")!=1 or str(s("restored_hash"))!=read("saved").hash or s("restored_tick")!=int(read("saved").tick):await finish(1,"solo exact frame");return
  if not await until(func():return s("seeded")==1):await finish(1,"solo solver seed");return
  if p("epoch")!=2 or p("players")!=1:await finish(1,"solo epoch/membership");return
  await finish(0,"solo restore and solver seed");return
 if stage=="write":
  game.get_node("UI/Lobby/Column/Name/Value").text="Saver" if role=="host" else "Friend Ω"
  if role=="host":press("UI/Lobby/Column/Buttons/Host")
  else:
   if not await until(func():return exists("open-write")):await finish(1,"write host barrier");return
   press("UI/Lobby/Column/Buttons/Join")
 else:
  if role=="host":
   press("UI/Lobby/Column/Resume/Host")
   var expected:=read("saved")
   if s("exact")!=1 or str(s("restored_hash"))!=expected.hash or s("restored_tick")!=int(expected.tick) or p("epoch")!=2:await finish(1,"host exact frame");return
   if not await until(func():return s("seeded")==1):await finish(1,"host solver seed");return
   write("restored",{"tick":s("restored_tick"),"hash":str(s("restored_hash")),"epoch":p("epoch"),"seeded":true})
  else:
   if not await until(func():return exists("open-read")):await finish(1,"read host barrier");return
   press("UI/Lobby/Column/Buttons/Join")
 if not await until(func():return p("state_ready") and p("chat_ready")):await finish(1,"admission");return
 game.set_bot("idle")
 if role=="host":write("open-"+stage,{"ready":true})
 if not await until(func():return p("players")==2 and p("named",1) and p("named",2)):await finish(1,"named members");return
 if p("seat")!=(1 if role=="host" else 2):await finish(1,"stable seat");return
 if game.get_node("UI/Lobby/Column/Name/Value").text!=("Saver" if role=="host" else "Friend Ω"):await finish(1,"profile name");return
 write("joined-"+stage+"-"+role,{"ready":true})
 if stage=="write":
  if role=="host":
   if not await until(func():return exists("joined-write-client")):await finish(1,"writer join");return
   press("UI/Lobby/Column/Start");game.set_bot("striker")
   if not await until(func():return s("moving")==1,50000):await finish(1,"scored moving save window");return
   game.set_bot("idle")
   var event:=InputEventKey.new();event.physical_keycode=KEY_F5;event.keycode=KEY_F5;event.pressed=true;Input.parse_input_event(event)
   await frames(2)
   event=InputEventKey.new();event.physical_keycode=KEY_F5;event.keycode=KEY_F5;event.pressed=false;Input.parse_input_event(event)
   if s("saved_tick")<=0 or not "Saved pitch" in str(game.get_node("UI/SaveNotice").text):await finish(1,"F5 save receipt");return
   write("saved",{"tick":s("saved_tick"),"hash":str(s("saved_hash")),"left":p("left"),"right":p("right")})
   var path:=OS.get_environment("RSL_SAVE");var committed:=FileAccess.get_file_as_bytes(path)
   if DirAccess.make_dir_absolute(path+".pending")!=OK:await finish(1,"failed-write setup");return
   if game.on_save() or not "Could not save" in str(game.get_node("UI/SaveNotice").text) or FileAccess.get_file_as_bytes(path)!=committed:await finish(1,"failed write replaced committed save");return
   if DirAccess.remove_absolute(path+".pending")!=OK:await finish(1,"failed-write cleanup");return
   write("saved-ready",{"preserved":true})
  else:
   if game.get_node("UI/Save").visible or game.on_save():await finish(1,"client saved authority");return
  return
 if p("left")!=int(read("saved").left) or p("right")!=int(read("saved").right):await finish(1,"saved score");return
 if role=="host":
  if not await until(func():return exists("joined-read-client")):await finish(1,"reader join");return
  game.set_bot("striker")
 if not await until(func():return p("winner")>0,60000):await finish(1,"finish resumed match");return
 game.set_bot("idle")
 if role=="host" and p("kicks")==0:await finish(1,"no new kicks");return
 if role=="client":game.on_chat("resumed match complete")
 if not await until(func():return "Friend Ω: resumed match complete" in str(game.get_node("UI/Chat/Column/Lines").text)):await finish(1,"post resume chat");return
 var floor_tick:=p("tick")
 if not await until(func():return p("tick")>=floor_tick+60):await finish(1,"continued world history");return
 if role=="host":
  var accepted:=false
  for attempt in range(1,41):
   var tick:=p("tick")-30;tick-=tick%3
   var digest:=int(game.probe_hash(tick))
   if tick<floor_tick or digest<0:await frames(3);continue
   write("candidate",{"serial":attempt,"tick":tick,"hash":str(digest)})
   if not await until(func():return exists("candidate-reply") and int(read("candidate-reply").serial)==attempt,1000):await finish(1,"candidate response");return
   var reply:=read("candidate-reply")
   if reply.available:
    if reply.hash!=str(digest):await finish(1,"final canonical world mismatch");return
    write("final-world",{"tick":tick,"hash":str(digest),"floor_tick":floor_tick});accepted=true;break
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
 if role=="host":
  if not game.on_save():await finish(1,"save continued match");return
  write("saved-again",{"tick":s("saved_tick"),"hash":str(s("saved_hash")),"epoch":p("epoch"),"winner":p("winner")})
 write("done-"+role,{"seat":p("seat"),"epoch":p("epoch"),"winner":p("winner"),"floor_tick":floor_tick,"final":read("final-world")})
 if not await until(func():return exists("done-host") and exists("done-client")):await finish(1,"finish barrier");return
 await finish(0,"fresh process solver continuation")
