extends SceneTree
var game:Node
var role:=OS.get_environment("CAVE_COMPARE_ROLE")
var folder:=OS.get_environment("CAVE_COMPARE_DIR")
var variant:=OS.get_environment("CAVE_COMPARE_VARIANT")
var measuring:=false
var finished:=false
var completed:=false
var start_ms:=0
var started_unix_ms:=0.0
var samples:=[]
var actions:=[]
var warm_state:={}

func _initialize():
 game=load("res://cave.tscn").instantiate();root.add_child(game);call_deferred("run")
func value(key:String,remote:=false)->float:return float(game.bench_value(key,remote))
func snapshot()->Dictionary:
 return {"ms":Time.get_ticks_msec()-start_ms,"unix_ms":Time.get_unix_time_from_system()*1000.0,"x":value("x"),"y":value("y"),"render_x":value("render_x"),"render_y":value("render_y"),"other_x":value("x",true),"other_y":value("y",true),"other_render_x":value("render_x",true),"other_render_y":value("render_y",true),"visible_bag":value("visible_bag"),"visible_gems":value("visible_gems"),"visible_door":value("visible_door"),"confirmed":value("confirmed"),"bag":value("bag"),"other_bag":value("bag",true),"gems":value("gems"),"door":value("door"),"hp":value("hp"),"mobs":value("mobs"),"depth":value("depth"),"tx":value("tx")}
func mark(name:String):
 var f:=FileAccess.open(folder.path_join(name),FileAccess.WRITE);f.store_string("ready");f.close()
func has(name:String)->bool:return FileAccess.file_exists(folder.path_join(name))
func until(check:Callable,label:String,timeout:=20.0)->bool:
 var start:=Time.get_ticks_msec()
 while not check.call():
  if finished:return false
  if Time.get_ticks_msec()-start>timeout*1000.0:fail(label);return false
  await process_frame
 return true
func near(point:Vector2)->bool:return Vector2(value("render_x"),value("render_y")).distance_to(point)<=8
func note(name:String):actions.append({"name":name,"ms":Time.get_ticks_msec()-start_ms,"unix_ms":Time.get_unix_time_from_system()*1000.0,"state":snapshot()})
func walk(point:Vector2,label:String)->bool:
 note(label+" issued");game.walk_to(point.x,point.y)
 if not await until(func():return near(point),label):return false
 note(label+" arrived");return true
func run():
 game.bench_boot(role=="host")
 if not await until(func():return value("players")==2,"admission"):return
 if role=="host":game.bench_start_game()
 if not await until(func():return value("ready")==1,"world"):return
 if value("hz")!=20 or value("seed")!=1337:fail("configuration");return
 if role=="host" and not bool(game.bench_backup()):fail("backup enable");return
 game.walk_to(120.0 if role=="host" else 160.0,120.0)
 if not await until(func():return near(Vector2(120 if role=="host" else 160,120)),"anchor"):return
 mark("anchor-"+role)
 if not await until(func():return has("anchor-host") and has("anchor-client"),"anchors"):return
 await create_timer(1.0).timeout
 warm_state=snapshot();mark("warm-"+role)
 if not await until(func():return has("warm-host") and has("warm-client"),"warmup"):return
 if role=="host":
  var file:=FileAccess.open(folder.path_join("start.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"unix_ms":Time.get_unix_time_from_system()*1000.0+400}));file.close()
 if not await until(func():return has("start.json"),"clock"):return
 var start:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("start.json")))
 if not await until(func():return Time.get_unix_time_from_system()*1000.0>=float(start.unix_ms),"start"):return
 game.bench_begin();start_ms=Time.get_ticks_msec();started_unix_ms=Time.get_unix_time_from_system()*1000.0;measuring=true
 if role=="client":
  if not await walk(Vector2(300,120),"east"):return
  if not await walk(Vector2(300,180),"chest"):return
  var loot_confirmed:=value("confirmed");note("loot issued");game.bench_use(false)
  if not await until(func():return value("visible_bag")==3,"visible loot"):return
  note("loot visible")
  if not await until(func():return value("confirmed")>loot_confirmed and value("bag")==3,"loot confirmation"):return
  note("loot confirmed")
  if not await walk(Vector2(560,180),"to door"):return
  var door_confirmed:=value("confirmed");note("door issued");game.bench_use(true)
  if not await until(func():return value("visible_door")==1,"visible door"):return
  note("door visible")
  if not await until(func():return value("confirmed")>door_confirmed and value("door")==1,"door confirmation"):return
  note("door confirmed")
  if not await walk(Vector2(160,180),"west"):return
  if not await walk(Vector2(160,120),"return"):return
  completed=true
 else:
  if not await until(func():return value("bag",true)==3 and value("door")==1,"authority outcomes"):return
  note("authority outcomes");completed=true

func _process(_dt:float)->bool:
 if not measuring or finished:return false
 samples.append(snapshot())
 if (role=="host" and value("gems")!=3) or value("gems")<0 or value("gems")>6 or value("mobs")!=0 or value("hp")!=100 or value("depth")!=1:fail("workload diverged");return false
 if Time.get_ticks_msec()-start_ms>=16000:finish()
 return false
func fail(reason:String):
 if finished:return
 finished=true
 var f:=FileAccess.open(folder.path_join(role+".failed.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"pass":false,"reason":reason,"state":snapshot(),"samples":samples,"actions":actions}));f.close()
 print("CAVE_COMPARE_FAIL ",variant," ",role," ",reason," ",JSON.stringify(snapshot()));quit(1)
func finish():
 if finished:return
 if not completed:fail("workload incomplete at window end");return
 game.bench_end();measuring=false;finished=true
 var count:=int(game.bench_sample(-1));var times:=[]
 for i in range(count):times.append(int(game.bench_sample(i)))
 var receipt:={"pass":true,"variant":variant,"role":role,"duration_ms":Time.get_ticks_msec()-start_ms,"start_unix_ms":started_unix_ms,"warm_state":warm_state,"final_state":snapshot(),"samples":samples,"actions":actions,"callback_us":times,"callback_dropped":int(game.bench_sample(-2)),"backup":value("backup")}
 if OS.get_environment("CAVE_COMPARE_PACKETS")=="1":
  receipt.packets=[]
  for kind in range(64):
   var count_kind:=int(game.bench_packet(kind,false))
   if count_kind>0:receipt.packets.append({"kind":kind,"count":count_kind,"bytes":int(game.bench_packet(kind,true))})
  receipt.observation_body_bytes=int(game.bench_packet(-1,true));receipt.observation_sparse_estimate=int(game.bench_packet(-2,true))
 var file:=FileAccess.open(folder.path_join(role+".json"),FileAccess.WRITE);file.store_string(JSON.stringify(receipt));file.close();mark("done-"+role)
 # Keep the authority alive until the second measurement has closed too.
 var until_time:=Time.get_ticks_msec()+5000
 while not (has("done-host") and has("done-client")) and Time.get_ticks_msec()<until_time:await process_frame
 if not (has("done-host") and has("done-client")):print("CAVE_COMPARE_FAIL peer completion");quit(1);return
 print("REPLAY_CAVE_COMPARE_PROCESS_OK ",variant," ",role," frames=",count," tx=",receipt.final_state.tx)
 game.queue_free();await process_frame;await process_frame;quit(0)
