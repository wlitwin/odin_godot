extends SceneTree
const KEYS=["authority","seat","avatars","hp","iron","cores","kills","stage","floor","run","clock","wave","spawned","rest_until","living"]
var game:Node
var role:String
var folder:String
var impl:String
var phase:="boot"
var start:=0
var phase_at:=0
var closing:=false
var trace:=[]
var last_sample:=0
var cleared:=false
var resource_floor:=0
func p(key:String)->int:return int(game.dedicated_probe(key))
func _initialize():
 role=OS.get_environment("COMPARE_ROLE");folder=OS.get_environment("COMPARE_DIR");impl=OS.get_environment("COMPARE_IMPL")
 resource_floor=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 game=load("res://main.tscn").instantiate();root.add_child(game)
 start=Time.get_ticks_msec();phase_at=start
func observe(label:String=""):
 var row:={"label":label,"ms":Time.get_ticks_msec()-start,"phase":phase,"position":game.dedicated_position()}
 for key in KEYS:row[key]=p(key)
 trace.append(row)
func signal_done():
 var f:=FileAccess.open(folder+"/done-"+role,FileAccess.WRITE);f.store_string("ready");f.close()
func finish(code:int,reason:String):
 if closing:return
 closing=true;observe(reason)
 var f:=FileAccess.open(folder+"/"+role+".json",FileAccess.WRITE);f.store_string(JSON.stringify({"pass":code==0,"reason":reason,"implementation":impl,"role":role,"trace":trace}));f.close();f=null
 print("DEDICATED_", "OK" if code==0 else "FAIL", " ",impl," ",role," ",reason)
 game.queue_free();game=null;await process_frame;await process_frame
 var deadline:=Time.get_ticks_msec()+2000
 while int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))>resource_floor and Time.get_ticks_msec()<deadline:await process_frame
 quit(code)
func drive(x:int,y:int,fire:bool):game.dedicated_drive(x,y,fire)
func lane_walk():
 var pos:Vector2=game.dedicated_position()
 if absf(1850-pos.x)<30 and absf(544-pos.y)<30:drive(0,0,false);return
 if absf(1850-pos.x)>=30:
  if pos.y<1040:drive(1 if int(Time.get_ticks_msec()/900)%2==0 else -1,1,false)
  else:drive(int(sign(1850-pos.x)),0,false)
 else:drive(0,int(sign(544-pos.y)),false)
func _process(_dt:float)->bool:
 if closing:return false
 var now:=Time.get_ticks_msec()
 if now-start>90000:finish(1,"timeout "+phase);return false
 if phase=="boot":game.dedicated_boot(role=="server");phase="joined";return false
 if not p("ready"):return false
 if role=="server" and (p("seat")!=0 or p("hp")!=-1 or p("authority")!=1):finish(1,"authority acquired an avatar");return false
 if now>=last_sample:observe();last_sample=now+500
 match phase:
  "joined":
   if role=="server":phase="party"
   else:game.dedicated_profile(1 if role=="client1" else 2);phase="profile";phase_at=now
  "profile":
   if now-phase_at>=500:game.on_ready();phase="party"
  "party":
   if p("avatars")!=2:return false
   if role!="server" and (p("hp")<=0 or p("iron")!=0):return false
   observe("two clients entered");phase="fight";phase_at=now
  "fight":
   if p("run")!=0 or p("stage")==3:finish(1,"party wiped");return false
   if role!="server":
    var angle:=float(now-phase_at)/700.0;drive(int(sign(cos(angle))),int(sign(sin(angle))),true)
   if p("stage")==2 and p("floor")==1:
    if role=="server" and (p("spawned")!=6 or p("living")!=0 or p("wave")!=1):finish(1,"encounter mismatch");return false
    if role!="server" and p("cores")<1:return false
    observe("floor cleared");cleared=true;phase="gate"
  "gate":
   if p("floor")==2:
    if not cleared or p("avatars")!=2:finish(1,"floor advanced without party");return false
    if role!="server":drive(0,0,false)
    observe("floor two");signal_done();phase="done"
   elif role!="server":lane_walk()
  "done":
   if FileAccess.file_exists(folder+"/done-server") and FileAccess.file_exists(folder+"/done-client1") and FileAccess.file_exists(folder+"/done-client2"):finish(0,"avatarless authority, combat and floor progression")
 return false
