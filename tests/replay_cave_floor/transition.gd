extends SceneTree
var game:Node
var mode:String
var folder:String
var started:=0
var requested:=false
var closing:=false
func _initialize():
 mode=OS.get_environment("CAVE_FLOOR_CASE");folder=OS.get_environment("CAVE_FLOOR_OUT")
 game=load("res://cave.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
func value(tick:int,key:String)->int:return int(game.floor_value(tick,key,1))
func finish(code:int,reason:String,tick:int=0):
 if closing:return
 closing=true
 var fields:={}
 if tick>0:
  for key in ["depth","run","hp","stamina","rock","heal","chill","kills","damage","bag"]:fields[key]=value(tick,key)
 var file:=FileAccess.open(folder+"/"+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify({"pass":code==0,"reason":reason,"tick":tick,"fields":fields}));file.close();file=null
 print("CAVE_FLOOR_TRANSITION_", "OK" if code==0 else "FAIL", " ",mode," ",reason," ",fields)
 game.queue_free();game=null;await process_frame;await process_frame;quit(code)
func _process(_dt:float)->bool:
 if closing:return false
 if Time.get_ticks_msec()-started>12000:finish(1,"timeout");return false
 if not game.probe_ready():return false
 if mode=="descent":
  if game.probe_head()<101:return false
  if value(101,"depth")!=2 or value(101,"hp")!=65 or value(101,"stamina")!=3 or value(101,"rock")!=6 or value(101,"heal")!=10 or value(101,"chill")!=12 or value(101,"bag")!=3:finish(1,"descent values",101);return false
  finish(0,"retained after tick decay",101)
 else:
  if not requested:game.on_start();requested=true
  if game.lobby_probe("run",0)!=2:return false
  var head:=int(game.probe_head());var first:=head
  while first>100 and value(first-1,"run")==2:first-=1
  if value(first,"hp")!=100 or value(first,"stamina")!=10 or value(first,"rock")!=0 or value(first,"heal")!=0 or value(first,"bag")!=0 or value(first,"chill")!=value(first-1,"chill")-1 or value(first,"chill")<=0:finish(1,"restart values",first);return false
  if value(first,"kills")!=4 or value(first,"damage")!=42:finish(1,"restart ledger",first);return false
  finish(0,"run reset and active status retained",first)
 return false
