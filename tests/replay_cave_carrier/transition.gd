extends SceneTree
var game:Node
var mode:String
var folder:String
var started:=0
var closing:=false
func _initialize():
 mode=OS.get_environment("CAVE_CARRIER_CASE");folder=OS.get_environment("CAVE_CARRIER_OUT")
 game=load("res://cave.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
func value(tick:int,key:String)->int:return int(game.floor_value(tick,key,1))
func finish(code:int,reason:String):
 if closing:return
 closing=true
 var samples:=[]
 for tick in [101,104]:
  var fields:={"tick":tick}
  for key in ["hp","carrier","version","x","y","player_x","player_y"]:fields[key]=value(tick,key)
  samples.append(fields)
 var file:=FileAccess.open(folder+"/"+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify({"pass":code==0,"reason":reason,"samples":samples}));file.close();file=null
 print("CAVE_CARRIER_TRANSITION_", "OK" if code==0 else "FAIL", " ",mode," ",reason," ",samples)
 game.queue_free();game=null;await process_frame;await process_frame;quit(code)
func _process(_dt:float)->bool:
 if closing:return false
 if Time.get_ticks_msec()-started>12000:finish(1,"timeout");return false
 if not game.probe_ready() or game.probe_head()<104:return false
 for tick in [101,104]:
  if value(tick,"carrier")!=1 or value(tick,"version")!=7:finish(1,"ownership changed");return false
 if value(101,"x")!=230 or value(101,"y")!=138:finish(1,"initial attachment");return false
 if mode=="dead":
  if value(101,"hp")!=0 or value(104,"hp")!=100 or value(104,"x")!=90 or value(104,"y")!=108:finish(1,"death/respawn attachment");return false
 elif value(104,"x")!=230 or value(104,"y")!=138:finish(1,"disconnected prop moved");return false
 finish(0,"carrier retained")
 return false
