extends SceneTree
var game:Node
var role:=OS.get_environment("CAVE_ROCK_ROLE")
var folder:=OS.get_environment("CAVE_ROCK_DIR")
var rows:=[]
var key:=0
func p(name:String)->float:return float(game.rock_probe(name,key))
func check(ok:bool,why:String)->bool:
 if not ok:push_error("CAVE_ROCK_FAIL "+why);quit(1)
 return ok
func marker(name:String):
 var f:=FileAccess.open(folder.path_join(name),FileAccess.WRITE);f.store_string("ready");f.close()
func wait_for(checker:Callable,label:String,seconds:=15.0)->bool:
 var start:=Time.get_ticks_msec()
 while not checker.call():
  if not check(Time.get_ticks_msec()-start<seconds*1000,label):return false
  await process_frame
 return true
func _initialize():
 game=load("res://cave.tscn").instantiate();root.add_child(game);call_deferred("run")
func run():
 if not await wait_for(func():return game.probe_ready() and int(game.probe_players())==2,"admission"):return
 marker("ready-"+role)
 if role=="host":
  game.walk_to(120,180)
  if not await wait_for(func():return game.probe_near(120,180),"walk"):return
  if not await wait_for(func():return FileAccess.file_exists(folder.path_join("ready-client")) and FileAccess.file_exists(folder.path_join("ready-observer")),"peers"):return
  game.throw(1,0)
 if not await wait_for(func():return p("key")>0,"rock spawn"):return
 key=int(p("key"));var start:=Time.get_ticks_usec()
 while p("x")!=-1:
  rows.append({"us":Time.get_ticks_usec()-start,"tick":int(p("tick")),"x":p("x"),"y":p("y"),"draw_x":p("draw_x"),"draw_y":p("draw_y"),"vx":p("vx"),"vy":p("vy"),"fraction":p("fraction"),"center_x":p("center_x"),"center_y":p("center_y")})
  if not check(Time.get_ticks_usec()-start<5000000,"rock lifetime"):return
  await process_frame
 if not check(game.rock_view(key)==null,"expired membership leaves no ghost"):return
 var data:={"pass":true,"role":role,"key":key,"rows":rows}
 var file:=FileAccess.open(folder.path_join(role+".json"),FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
 marker("done-"+role)
 if not await wait_for(func():return FileAccess.file_exists(folder.path_join("done-host")) and FileAccess.file_exists(folder.path_join("done-client")) and FileAccess.file_exists(folder.path_join("done-observer")),"finish"):return
 print("REPLAY_CAVE_ROCK_PROCESS_OK "+role)
 quit(0)
