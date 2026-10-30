extends SceneTree
var game:Node
var folder:String
var host:bool
func _initialize():run.call_deferred()
func write(name:String,value:Dictionary):
 var f:=FileAccess.open(folder+"/"+name+".json",FileAccess.WRITE);f.store_string(JSON.stringify(value));f.close()
func until(test:Callable)->bool:
 var end:=Time.get_ticks_msec()+15000
 while Time.get_ticks_msec()<end:
  if test.call():return true
  await process_frame
 return false
func run():
 folder=OS.get_environment("REPLAY_ACK_DIR");host=OS.get_environment("REPLAY_ACK_ROLE")=="host"
 game=load("res://main.tscn").instantiate();root.add_child(game)
 assert(await until(func():return game.probe("ready")==1))
 if host:
  assert(await until(func():return FileAccess.file_exists(folder+"/client.json")))
 else:
  await create_timer(2.0).timeout
  game.arm();write("armed",{"ready":true})
  assert(await until(func():return FileAccess.file_exists(folder+"/proxy/dropped.json")))
  game.issue()
  assert(await until(func():return game.probe("done")==1))
  var result:={}
  for key in ["elapsed","sequence","ack_reliable","ack_unreliable"]:result[key]=game.probe(key)
  write("client",result);print("REPLAY_ACK_DELIVERY ",JSON.stringify(result))
 game.set_process(false);game.queue_free();game=null
 await process_frame;await process_frame
 quit(0)
