# Composed with drive.gd's shared SceneTree helpers by execute.py.
func run():
 root.size=Vector2i(640,360)
 game=load("res://claimball.tscn").instantiate();root.add_child(game);await process_frame
 if not await until(func():return p("state_ready"),"dedicated authority ready"):return
 mark("server-open")
 if not await until(func():return exists("quiesced-host") and exists("quiesced-client") and exists("quiesced-observer"),"dedicated second match completion",85000):return
 if not check(p("round")==2 and p("winner")>0,"dedicated second match winner"):return
 var f:=FileAccess.open(folder+"/result-server.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"round":p("round"),"winner":p("winner"),"left":p("left"),"right":p("right"),"kicks":p("kicks"),"spikes":p("spikes")}));f.close()
 print("REPLAY_CLAIMBALL_UI_PEER_OK role=server")
 game.queue_free();game=null;await process_frame;await process_frame;quit(0)
