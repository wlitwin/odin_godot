extends SceneTree
var game:Node
var member:=int(OS.get_environment("REPLAY_CAVE_MEMBER"))
var folder:=OS.get_environment("MODERATION_DIR")
var mode:=OS.get_environment("MODERATION_MODE")
func p(key:String)->int:return int(game.moderation_probe(key))
func mark(name:String):
 var f:=FileAccess.open(folder.path_join(name),FileAccess.WRITE);f.store_string("ready");f.close()
func exists(name:String)->bool:return FileAccess.file_exists(folder.path_join(name))
func check(ok:bool,why:String)->bool:
 if not ok:push_error("CAVE_MODERATION_FAIL "+why);quit(1)
 return ok
func until(test:Callable,label:String,seconds:=20)->bool:
 var start:=Time.get_ticks_msec()
 while not test.call():
  if not check(Time.get_ticks_msec()-start<seconds*1000,label):return false
  await process_frame
 return true
func _initialize():
 game=load("res://cave.tscn").instantiate();root.add_child(game);call_deferred("run")
func run():
 if OS.get_environment("MODERATION_RETURN")=="1":
  if not await until(func():return p("removed")==1,"removed identity denied on fresh process"):return
  check(not game.probe_ready(),"fresh removed process cannot play")
  mark("return-denied");print("CAVE_MODERATION_RETURN_DENIED_OK");quit(0);return
 if not await until(func():return game.probe_ready(),"start"):return
 mark("admitted-"+str(member))
 if not await until(func():return int(game.probe_players())==3,"roster"):return
 mark("roster-"+str(member))
 if mode=="unsupported":
  if member==1:
   game.kick(2)
   if not await until(func():return p("phase")==4,"unsupported operation bounded failure"):return
   if not check(p("epoch")==1 and p("owner")==1 and int(game.probe_players())==3 and p("member2_enabled")==1,"unsupported operation preserves party"):return
   await create_timer(3).timeout
   if not check(p("epoch")==1 and game.probe_steady() and int(game.probe_players())==3,"lease renewal continues"):return
   mark("unsupported-complete")
  else:
   if not await until(func():return exists("unsupported-complete"),"unsupported host check"):return
  print("CAVE_MODERATION_ROOM_OK unsupported member=",member);quit(0);return
 if member==1:
  if not await until(func():return exists("roster-2") and exists("roster-3"),"all rosters observed"):return
  if not await until(func():return p("nominee")==2 and p("prepared")==1,"initial prepared successor"):return
  game.kick(2)
  if not await until(func():return p("phase")==3 and p("member2_enabled")==0 and int(game.probe_players())==2,"durable removal"):return
  if not check(p("ban_count")==1,"gameplay ban mirrors durable roster"):return
  if not await until(func():return p("nominee")==3 and p("prepared")==1,"replacement successor"):return
  mark("removed-and-replaced")
  if not await until(func():return exists("return-denied"),"fresh removed identity denied"):return
  if mode=="crash":
   mark("kill-owner")
   await create_timer(30).timeout
   check(false,"owner was not killed");return
  if not check(bool(game.moderation_handoff()),"handoff accepted"):return
  if not await until(func():return p("epoch")==2 and p("owner")==3 and game.probe_ready(),"old host returns"):return
  if not await until(func():return exists("continued"),"new gameplay"):return
  print("CAVE_MODERATION_ROOM_OK member=1");quit(0);return
 if member==2:
  if not await until(func():return p("removed")==1,"removed guest"):return
  check(not game.probe_ready(),"removed guest closed")
  mark("removed-guest");print("CAVE_MODERATION_ROOM_OK member=2 removed=true");quit(0);return
 if not await until(func():return p("epoch")==2 and p("owner")==3 and game.probe_ready(),"takeover"):return
 if not check(p("member2_enabled")==0 and p("ban_count")==1,"takeover preserves ban"):return
 game.walk_to(300,180)
 if not await until(func():return game.probe_near(300,180),"continued movement"):return
 game.loot(0)
 if not await until(func():return int(game.probe_bag())==3,"continued loot"):return
 mark("continued")
 await create_timer(.5).timeout
 print("CAVE_MODERATION_ROOM_OK member=3 epoch=2");quit(0)
