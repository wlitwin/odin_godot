extends SceneTree
var game:Node
var role:=OS.get_environment("REPLAY_CAVE_ROLE")
var folder:=OS.get_environment("CAVE_CONTEXT_DIR")
var evidence:={}
func _initialize():
 game=load("res://cave.tscn").instantiate();root.add_child(game);call_deferred("run")
func until(check:Callable,label:String)->bool:
 var start:=Time.get_ticks_msec()
 while not check.call():
  if Time.get_ticks_msec()-start>15000:print("CAVE_CONTEXT_FAIL ",role," ",label);quit(1);return false
  await process_frame
 return true
func mark(name:String):
 var f:=FileAccess.open(folder.path_join(name),FileAccess.WRITE);f.store_string("ready");f.close()
func has(name:String)->bool:return FileAccess.file_exists(folder.path_join(name))
func x()->int:return int(game.motion_probe("avatar_x",2))
func bag()->int:return int(game.campaign_probe("bag_gems",2))
func run():
 if not await until(func():return game.probe_ready() and game.probe_players()==2,"join"):return
 mark("ready-"+role)
 if not await until(func():return has("ready-host") and has("ready-client") and has("ready-observer"),"admission"):return
 if role=="client":
  game.context_block(true);game.walk_to(300,180)
  if not await until(func():return abs(game.context_local_x()-300)<1,"local walk"):return
  if game.context_dropped()<10 or x()>110:print("CAVE_CONTEXT_FAIL stream not isolated");quit(1);return
  evidence.blocked_packets=game.context_dropped();evidence.local_x=game.context_local_x();evidence.authority_x=x()
  var rejected:=int(game.campaign_probe("rejected",0));game.context_legacy_loot()
  if not await until(func():return game.campaign_probe("rejected",0)>rejected,"legacy predicate rejection"):return
  if bag()!=0:print("CAVE_CONTEXT_FAIL legacy loot applied");quit(1);return
  evidence.legacy_refused=true;game.loot(0)
 if not await until(func():return bag()==3,"contextual loot"):return
 if x()>110 or game.probe_gems()!=3:print("CAVE_CONTEXT_FAIL moved actor or lost items");quit(1);return
 evidence.bag=bag();evidence.position_while_blocked=x();mark("checked-"+role)
 if not await until(func():return has("checked-host") and has("checked-client") and has("checked-observer"),"witnesses"):return
 if role=="client":game.context_block(false)
 if not await until(func():return abs(x()-300)<2,"stream continuation"):return
 evidence.position_after_unblock=x();evidence.pass=true
 var f:=FileAccess.open(folder.path_join(role+".json"),FileAccess.WRITE);f.store_string(JSON.stringify(evidence));f.close()
 mark("done-"+role)
 if not await until(func():return has("done-host") and has("done-client") and has("done-observer"),"done"):return
 print("REPLAY_CAVE_CONTEXT_OK ",role," ",JSON.stringify(evidence));game.queue_free();await process_frame;await process_frame;quit(0)
