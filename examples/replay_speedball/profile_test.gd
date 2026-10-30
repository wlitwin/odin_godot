extends "res://ui_test.gd"
func run():
 game=load("res://speedball.tscn").instantiate();root.add_child(game);await process_frame
 if role=="bad-identity" or role=="bad-name":
  press("UI/Lobby/Column/Buttons/Join")
  if not check(not p("ready") and not game.party_probe("active") and node("UI/Lobby/Column/Notice").text.contains("Could not"),"malformed profile fails closed"):return
  print("REPLAY_SPEEDBALL_PROFILE_CASE_OK role=",role)
  game.queue_free();await process_frame;await process_frame;quit(0);return
 if role=="override":
  press("UI/Lobby/Column/Buttons/Solo")
  if not await until(func():return p("state_ready") and p("named",1),"explicit token bypass"):return
  print("REPLAY_SPEEDBALL_PROFILE_CASE_OK role=",role)
  game.queue_free();await process_frame;await process_frame;quit(0);return
 if role=="host":
  press("UI/Lobby/Column/Buttons/Host")
  if not await until(func():return p("state_ready"),"host admission"):return
  mark("host-open")
  if not await until(func():return exists("writer-ready") and not p("connected",2),"writer disconnect",30000):return
  mark("writer-departed")
  if not await until(func():return exists("reader-ready") and p("connected",2),"fresh process rejoin",30000):return
  if not check(node("UI/Lobby/Column/Roster").text.contains("Returning Kicker"),"persisted roster name"):return
  mark("host-verified")
 else:
  if not await until(func():return exists("host-open"),"host barrier"):return
  if role=="writer":node("UI/Lobby/Column/Name/Value").text="Returning Kicker"
  elif not check(node("UI/Lobby/Column/Name/Value").text=="Returning Kicker","name loaded in fresh process"):return
  press("UI/Lobby/Column/Buttons/Join")
  if not await until(func():return p("state_ready") and p("seat")==2 and p("named",2),"persistent seat"):return
  mark(role+"-ready")
  if role=="writer":return # Runner kills this exact process, then starts a fresh reader.
  if not await until(func():return exists("host-verified"),"host verification"):return
 game.set_process(false);mark("quiesced-"+role)
 if not await until(func():return exists("quiesced-host") and exists("quiesced-reader"),"quiescence"):return
 print("REPLAY_SPEEDBALL_PROFILE_CASE_OK role=",role)
 game.queue_free();await process_frame;await process_frame;quit(0)
