# Composed with drive.gd's shared SceneTree helpers by execute.py.
func run():
 root.size=Vector2i(640,360)
 game=load("res://slopball3d.tscn").instantiate();root.add_child(game);await process_frame
 node("UI/Lobby/Column/Name/Value").text={"host":"Captain","client":"Striker","observer":"Watcher"}[role]
 if role!="host":
  if not await until(func():return exists("open"),"host barrier"):return
 press("UI/Lobby/Column/Buttons/"+{"host":"Host","client":"Join","observer":"Watch"}[role])
 if not await until(func():return p("state_ready") and p("chat_ready"),"admission"):return
 if role=="host":mark("open")
 if not await until(func():return p("named",1) and p("named",2),"names"):return
 mark("joined-"+role)
 if role=="client":game.on_chat("ready for two matches")
 if not await until(func():return node("UI/Chat/Column/Lines").text.contains("Striker: ready for two matches"),"first chat"):return
 if role=="host":
  if not await until(func():return exists("joined-client") and exists("joined-observer"),"roster barrier"):return
  press("UI/Lobby/Column/Start")
  game.set_bot("striker")
 if not await until(func():return p("winner")>0,"first match winner",40000):return
 game.set_bot("idle")
 if role=="host":
  if not await until(func():return node("UI/Again").visible,"restart button frame"):return
 if not check(p("round")==1 and node("UI/Again").visible==(role=="host"),"restart visibility"):return
 mark("won-"+role)
 if role=="client":
  game.on_again();var tick:=p("tick")
  if not await until(func():return p("tick")>=tick+30,"guest restart verdict"):return
  if not check(p("round")==1 and p("winner")>0,"guest restart rejected"):return
  mark("guest-rejected")
 if role=="observer":
  game.on_again()
  if not check(p("seat")==0 and p("round")==1,"observer cannot restart"):return
 if role=="host":
  if not await until(func():return exists("won-client") and exists("won-observer") and exists("guest-rejected"),"winner barrier"):return
  if OS.get_environment("RS3_UI_CAPTURE")!="":
   await RenderingServer.frame_post_draw
   var image:=root.get_texture().get_image();image.save_png(OS.get_environment("RS3_UI_CAPTURE"));image=null
  press("UI/Again")
 if not await until(func():return p("round")==2 and not node("UI/Again").visible,"new match"):return
 if not check(p("winner")==0 and p("left")==0 and p("right")==0,"new match clears totals"):return
 if not check(p("named",1) and p("named",2) and p("seat")=={"host":1,"client":2,"observer":0}[role],"same roster and seats"):return
 if not await until(func():return p("restart_seeded")==1,"new solver scopes/poses"):return
 if not check(node("UI/Chat/Column/Lines").text.contains("Striker: ready for two matches"),"restart retains chat"):return
 mark("round-two-"+role)
 if role=="host":
  if not await until(func():return exists("round-two-client") and exists("round-two-observer"),"restart barrier"):return
  game.set_bot("striker")
 if not await until(func():return p("round")==2 and p("winner")>0,"second match winner",40000):return
 game.set_bot("idle")
 if not await until(func():return node("UI/Chat/Column/Lines").text.contains("Match 2 starts"),"restart narration"):return
 if role=="client":game.on_chat("second match complete")
 if not await until(func():return node("UI/Chat/Column/Lines").text.contains("Striker: second match complete"),"post restart chat"):return
 var f:=FileAccess.open(folder+"/result-"+role+".json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"round":p("round"),"seat":p("seat"),"started":p("started"),"winner":p("winner"),"left":p("left"),"right":p("right"),"kicks":p("kicks"),"handoffs":p("handoffs")}));f.close()
 game.set_process(false);mark("quiesced-"+role)
 if not await until(func():return exists("quiesced-host") and exists("quiesced-client") and exists("quiesced-observer"),"quiescence"):return
 print("REPLAY_SLOPBALL3D_UI_PEER_OK role=",role)
 game.queue_free();game=null;await process_frame;await process_frame;quit(0)
