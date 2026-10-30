extends SceneTree
var game:Node
var member:=0
var carrier:=0
var carrier_seat:=0
var expected_seat:=0
var folder:String
var mode:String
var phase:="join"
var started:=0
var version:=-1
var durable:=-1
var accepted:=0
var closing:=false
var observations:=[]
func _initialize():
 member=int(OS.get_environment("REPLAY_CAVE_MEMBER"));carrier=int(OS.get_environment("CAVE_CARRIER_MEMBER"))
 carrier_seat=int(OS.get_environment("CAVE_CARRIER_SEAT")) if OS.get_environment("CAVE_CARRIER_SEAT")!="" else carrier
 expected_seat=int(OS.get_environment("CAVE_EXPECTED_SEAT")) if OS.get_environment("CAVE_EXPECTED_SEAT")!="" else member
 folder=OS.get_environment("REPLAY_MIGRATION_DIR");mode=OS.get_environment("REPLAY_MIGRATION_MODE")
 game=load("res://cave.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
func value(key:String)->int:return int(game.carrier_value(key,carrier_seat))
func signal_file(name:String):
 var file:=FileAccess.open(folder+"/"+name,FileAccess.WRITE);file.store_string("ready");file.close()
func seen(name:String)->bool:return FileAccess.file_exists(folder+"/"+name)
func record(label:String):
 var entry:={"label":label,"epoch":game.probe_epoch(),"head":game.probe_head(),"recovery":game.probe_recovery_tick(),"seat":game.probe_seat()}
 for key in ["carrier","version","x","y","player_x","player_y","hp","connected"]:entry[key]=value(key)
 observations.append(entry)
func finish(code:int,reason:String):
 if closing:return
 closing=true;record(reason)
 var file:=FileAccess.open(folder+"/member-%d.json"%member,FileAccess.WRITE);file.store_string(JSON.stringify({"pass":code==0,"reason":reason,"observations":observations}));file.close();file=null
 print("CAVE_CARRIER_MIGRATION_","OK" if code==0 else "FAIL"," member=",member," carrier=",carrier," mode=",mode," phase=",phase," reason=",reason," observations=",observations)
 game.queue_free();game=null;await process_frame;await process_frame;quit(code)
func attached()->bool:return value("x")==value("player_x")+10 and value("y")==value("player_y")-12
func _process(_dt:float)->bool:
 if closing:return false
 if Time.get_ticks_msec()-started>35000:finish(1,"timeout");return false
 if game.probe_steady() and game.probe_epoch()==1 and not seen("admitted-%d"%member):signal_file("admitted-%d"%member)
 match phase:
  "join":
   if not game.probe_steady() or game.probe_players()!=3:return false
   if game.probe_seat()!=expected_seat:finish(1,"seat identity");return false
   if member==carrier:game.walk_to(120,80)
   phase="take" if member==carrier else "carried"
  "take":
   if game.probe_near(120,80):game.carry();phase="carried"
  "carried":
   if value("carrier")!=carrier_seat:return false
   version=value("version")
   if member==carrier:game.walk_to(180,80)
   phase="durable"
  "durable":
   if value("carrier")!=carrier_seat or value("version")!=version:finish(1,"carrier changed before handoff");return false
   if abs(value("player_x")-180)>20 or abs(value("player_y")-80)>20 or not attached():return false
   if not seen("ready-%d"%member):record("before handoff");signal_file("ready-%d"%member)
   if member!=1:phase="recover";return false
   if not seen("ready-2") or not seen("ready-3"):return false
   if durable<0:durable=int(game.probe_head())
   if game.probe_backup_tick()<durable or game.probe_prepared_tick()<durable:return false
   print("CAVE_CARRIER_DURABLE tick=",durable," backup=",game.probe_backup_tick()," prepared=",game.probe_prepared_tick())
   if mode=="planned":
    if not game.handoff():finish(1,"handoff refused");return false
   else:signal_file("kill_owner")
   phase="recover"
  "recover":
   if not game.probe_steady() or game.probe_epoch()!=2:return false
   if value("carrier")!=carrier_seat or value("version")!=version:finish(1,"ownership lost during recovery");return false
   if game.probe_head()<game.probe_recovery_tick()+20:return false
   if not attached():return false
   record("recovered");signal_file("recovered-%d"%member)
   if member==carrier:game.walk_to(240,80)
   phase="continued"
  "continued":
   if value("carrier")!=carrier_seat or value("version")!=version:finish(1,"ownership lost after recovery");return false
   if abs(value("player_x")-240)>20 or abs(value("player_y")-80)>20 or not attached():return false
   record("continued carrying");signal_file("continued-%d"%member);phase="drop"
  "drop":
   if not seen("continued-2") or not seen("continued-3") or (mode=="planned" and not seen("continued-1")):return false
   if member==carrier:accepted=int(game.probe_accepted());game.set_down()
   phase="released"
  "released":
   if value("carrier")!=0 or value("version")!=version+1:return false
   if member==carrier and game.probe_accepted()<=accepted:return false
   record("released in new epoch");signal_file("released-%d"%member);phase="done"
  "done":
   if seen("released-2") and seen("released-3") and (mode!="planned" or seen("released-1")):finish(0,"carry preserved and fresh release accepted")
 return false
