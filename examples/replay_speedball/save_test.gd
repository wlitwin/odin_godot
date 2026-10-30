extends "res://ui_test.gd"
var stage:=""
func saved(key:String)->int:return int(game.save_probe(key))
func write_json(name:String,data:Dictionary):
 var f:=FileAccess.open(folder+"/"+name+".json",FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close()
func read_json(name:String)->Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(folder+"/"+name+".json"))
func capture(name:String):
 if OS.get_environment("RSB_SAVE_RENDER")!="1":return
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png(folder+"/"+name+".png")==OK)
func run():
 stage=OS.get_environment("RSB_SAVE_STAGE")
 game=load("res://speedball.tscn").instantiate();root.add_child(game);await process_frame
 if stage in ["wrong-owner","damaged","missing"]:
  press("UI/Lobby/Column/Resume/Host")
  if not check(not p("ready") and not p("state_ready"),"failed resume leaves no session"):return
  var notice:String=node("UI/Lobby/Column/Notice").text
  if not check(notice.contains({"wrong-owner":"host profile","damaged":"damaged","missing":"Could not open"}[stage]),"resume explanation"):return
  write_json(stage,{"rejected":true,"notice":notice})
  print("REPLAY_SPEEDBALL_SAVE_CASE_OK ",stage);await close_game();return
 if stage=="solo":
  await capture("resume-menu")
  press("UI/Lobby/Column/Resume/Solo")
  if not check(p("ready") and saved("exact")==1 and p("seat")==1,"solo resume"):return
  if not check(str(saved("restored_hash"))==read_json("saved").hash,"solo exact hash"):return
  game.set_bot("idle")
  await capture("resumed-solo")
  print("REPLAY_SPEEDBALL_SAVE_CASE_OK solo");await close_game();return
 if stage=="write":
  node("UI/Lobby/Column/Name/Value").text="Saver" if role=="host" else "Friend"
  if role!="host":
   if not await until(func():return exists("open-write"),"host barrier"):return
  press("UI/Lobby/Column/Buttons/"+("Host" if role=="host" else "Join"))
 else:
  if role=="host":
   press("UI/Lobby/Column/Resume/Host")
   if not check(p("ready") and saved("exact")==1,"exact restored frame"):return
   var expected:=read_json("saved")
   if not check(saved("restored_tick")==int(expected.tick) and str(saved("restored_hash"))==expected.hash,"saved frame hash"):return
   write_json("restored",{"tick":saved("restored_tick"),"hash":str(saved("restored_hash")),"epoch":int(game.recovery_probe("epoch")),"exact":bool(saved("exact"))})
  else:
   if not await until(func():return exists("open-read"),"resumed host barrier"):return
   press("UI/Lobby/Column/Buttons/Join")
 if not await until(func():return p("state_ready") and p("chat_ready"),"admission"):return
 if role=="host":mark("open-"+stage)
 if not await until(func():return p("named",1) and p("named",2) and p("connected",1) and p("connected",2),"named party"):return
 if not check(p("seat")== (1 if role=="host" else 2),"persistent seat"):return
 if not check(node("UI/Lobby/Column/Name/Value").text==("Saver" if role=="host" else "Friend"),"persistent name"):return
 mark("joined-"+stage+"-"+role)
 if stage=="write":
  if role=="host":
   if not await until(func():return exists("joined-write-client"),"writer barrier"):return
   press("UI/Lobby/Column/Start");game.set_bot("striker")
   if not await until(func():return saved("moving")==1 and p("left")+p("right")>0 and p("winner")==0,"scored moving save",50000):return
   press("UI/Save")
   if not check(saved("saved_tick")>0 and node("UI/SaveNotice").text.begins_with("Saved"),"save receipt"):return
   write_json("saved",{"tick":saved("saved_tick"),"hash":str(saved("saved_hash")),"round":p("round"),"left":p("left"),"right":p("right"),"spikes":p("spikes"),"moving":true})
   # Block the next staging-file open; the committed archive must survive.
   var committed:=FileAccess.get_file_as_bytes(OS.get_environment("RSB_SAVE"))
   var staging:=OS.get_environment("RSB_SAVE")+".pending"
   if not check(DirAccess.make_dir_absolute(staging)==OK,"prepare failed write"):return
   if not check(not game.on_save() and node("UI/SaveNotice").text.contains("Could not save"),"failed write reported"):return
   if not check(FileAccess.get_file_as_bytes(OS.get_environment("RSB_SAVE"))==committed,"failed write preserves exact archive bytes"):return
   print("RSB_FAILED_WRITE_PRESERVED")
   if not check(DirAccess.remove_absolute(staging)==OK,"remove test staging directory"):return
   mark("saved-ready")
  else:
   if not check(not node("UI/Save").visible and not game.on_save(),"guest cannot save"):return
  return # The runner kills both owned processes after the durable receipt.
 if role=="host":
  if not await until(func():return exists("joined-read-client"),"reader barrier"):return
  game.set_bot("spiker")
  if not await until(func():return p("spikes")>=2,"new commands after resume",25000):return
  game.set_bot("striker")
 if not await until(func():return p("winner")>0,"finish resumed match",50000):return
 game.set_bot("idle");mark("won-"+role)
 if role=="host":
  if not await until(func():return exists("won-client") and node("UI/Again").visible,"restart ready"):return
  press("UI/Again")
 if not await until(func():return p("round")==2,"restart resumed match"):return
 if role=="client":game.on_chat("resumed and restarted")
 if not await until(func():return node("UI/Chat/Column/Lines").text.contains("Friend: resumed and restarted"),"resumed chat"):return
 write_json("done-"+role,{"seat":p("seat"),"round":p("round"),"epoch":int(game.recovery_probe("epoch")),"left":p("left"),"right":p("right")})
 game.set_process(false);mark("quiesced-"+role)
 if not await until(func():return exists("quiesced-host") and exists("quiesced-client"),"quiescence"):return
 print("REPLAY_SPEEDBALL_SAVE_PEER_OK role=",role);await close_game()
func close_game():
 game.set_process(false);game.queue_free();await process_frame;await process_frame;quit(0)
