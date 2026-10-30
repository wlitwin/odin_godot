extends SceneTree
var game:Node
var mode:String
var folder:String
var started:=0
var requested:=false
var closing:=false
func _initialize():
 mode=OS.get_environment("CAVE_RELIC_CASE");folder=OS.get_environment("CAVE_RELIC_OUT")
 game=load("res://cave.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
func value(tick:int,key:String)->int:return int(game.floor_value(tick,key,1))
func finish(code:int,reason:String,tick:int=0):
 if closing:return
 closing=true
 var fields:={}
 if tick>0:
  for key in ["depth","run","carrier","version","x","y","player_x","player_y"]:fields[key]=value(tick,key)
 var file:=FileAccess.open(folder+"/"+mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify({"pass":code==0,"reason":reason,"tick":tick,"fields":fields}));file.close();file=null
 print("CAVE_RELIC_TRANSITION_", "OK" if code==0 else "FAIL", " ",mode," ",reason," ",fields)
 game.queue_free();game=null;await process_frame;await process_frame;quit(code)
func _process(_dt:float)->bool:
 if closing:return false
 if Time.get_ticks_msec()-started>12000:finish(1,"timeout");return false
 if not game.probe_ready():return false
 if mode!="restart":
  if game.probe_head()<101:return false
  if value(101,"depth")!=2 or value(101,"version")!=7:finish(1,"descent identity",101);return false
  if mode=="resting":
   if value(101,"carrier")!=0 or value(101,"x")!=200 or value(101,"y")!=150:finish(1,"resting position",101);return false
  elif value(101,"carrier")!=1 or value(101,"x")!=value(101,"player_x")+10 or value(101,"y")!=value(101,"player_y")-12:finish(1,"carried attachment",101);return false
  finish(0,"relic retained across descent",101)
 else:
  # Let the restored C5 carry position advance under C6 before requesting restart.
  if game.probe_head()<102:return false
  if not requested:game.on_start();requested=true
  if game.lobby_probe("run",0)!=2:return false
  var head:=int(game.probe_head());var first:=head
  while first>100 and value(first-1,"run")==2:first-=1
  if value(first,"carrier")!=0 or value(first,"version")!=8 or value(first,"x")!=value(first-1,"x") or value(first,"y")!=value(first-1,"y"):finish(1,"restart release",first);return false
  finish(0,"restart releases at last recorded position",first)
 return false
