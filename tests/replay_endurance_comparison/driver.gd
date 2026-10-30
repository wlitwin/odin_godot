extends SceneTree
var game:Node
var role:=""
var implementation:=""
var folder:=""
var phase:="boot"
var started:=0
var measurement_started:=0
var tick_before:=0
var tx_before:=0
var frames:=[]
var frame_times:=[]
var trace:=[]
var census_cost:=[]
var seen:={}
var inputs:=[]
var finished:=false
var resource_floor:=0
var result:={}
var known_before:=0
var kills_before:=0
var shots_before:=[0,0]
var initial_ids:=[]
var health_sum_now:=0
var steady_since:=0
var warmup_receipt:={}
var warmup_trace:=[]
var warmup_sample_at:=0
var movement:=[]
var casts:=[]
var next_segment:=0
var next_cast:=0
var dashes:=[]
var hazards:=[]
var next_dash:=0
var next_hazard:=0
var condition:="delay"
const HAZARDS=[Vector2i(2000,2),Vector2i(5000,5),Vector2i(8000,5),Vector2i(12000,2),Vector2i(15000,5),Vector2i(18000,5)]
const CASTS=[Vector2i(2000,0),Vector2i(3000,1),Vector2i(11000,0),Vector2i(19000,1)]
const DIRECTIONS=[Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,0)]
func p(key:String,seat:int=1)->int:return int(game.compare_probe(key,seat))
func c(key:String,seat:int=1)->int:return int(game.compare_combat_probe(key,seat))
func write(name:String,value:Dictionary):
 var f:=FileAccess.open(folder+"/"+name+".json.pending",FileAccess.WRITE);f.store_string(JSON.stringify(value));f.close()
 assert(DirAccess.rename_absolute(folder+"/"+name+".json.pending",folder+"/"+name+".json")==OK)
func both(name:String)->bool:return FileAccess.file_exists(folder+"/"+name+"-host.json") and FileAccess.file_exists(folder+"/"+name+"-client.json")
func fail(reason:String):
 if finished:return
 write("failure-"+role,{"phase":phase,"reason":reason,"warmup_trace":warmup_trace,"trace":trace,"living":c("living"),"bodies":c("bodies"),"issued":int(game.compare_spawned()),"seen":seen.size()})
 print("ENDURANCE_FAIL ",implementation," ",role," ",phase," ",reason);finish(1)
func finish(code:int):
 if finished:return
 finished=true;game.queue_free();game=null
 await process_frame;await process_frame
 var until:=Time.get_ticks_msec()+2000
 while int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))>resource_floor and Time.get_ticks_msec()<until:await process_frame
 quit(code)
func census():
 var began:=Time.get_ticks_usec()
 if implementation=="replay" and not p("ready"):
  if phase=="measure":
   census_cost.append(Time.get_ticks_usec()-began)
   trace.append({"ready":false,"us":Time.get_ticks_usec()-measurement_started,"resyncs":p("resyncs"),"reason":int(game.probe("resync_reason",1)),"head":int(game.probe("predhead",1)),"confirmed":int(game.probe("confirmed",1)),"facts":int(game.probe("facts",1))})
  return
 game.compare_census();game.compare_mixed_census();var enemies:=[];var health_sum:=0
 for i in c("bodies"):
  var v:Vector3=game.compare_enemy(i);var id:=str(game.compare_enemy_id(i));seen[id]=true
  enemies.append({"id":id,"x":v.x,"y":v.y,"hp":int(v.z),"kind":int(game.compare_enemy_kind(i))});health_sum+=int(v.z)
 var people:=[]
 for seat in [1,2]:
  var pos:Vector2=game.compare_position(seat)
  people.append({"x":pos.x,"y":pos.y,"hp":p("hp",seat),"loadout":int(game.compare_mixed_probe("loadout",seat)),"surge":int(game.compare_mixed_probe("surge",seat)),"burn":int(game.compare_mixed_probe("burn",seat)),"salve":int(game.compare_mixed_probe("salve",seat)),"dashes":int(game.compare_mixed_probe("dashes",seat)),"mode":int(game.compare_mixed_probe("mode",seat)),"rally":int(game.compare_mixed_probe("rally",seat)),"cd":[int(game.compare_mixed_probe("cd0",seat)),int(game.compare_mixed_probe("cd1",seat))]})
 health_sum_now=health_sum
 if c("census_overflow") or c("spawn_failed"):fail("adapter capacity/submission");return
 if role=="host" and c("stats_ready"):
  if c("damage",1)+c("damage",2)+health_sum!=seen.size()*3:fail("authority health conservation");return
  if c("scrap",1)+c("scrap",2)+c("loot")!=3*(c("kills",1)+c("kills",2)):fail("authority loot conservation");return
 if phase=="measure":
  census_cost.append(Time.get_ticks_usec()-began)
  trace.append({"stalls":int(game.compare_mixed_probe("stalls",1)),"catchups":int(game.compare_mixed_probe("catchups",1)),"ready":true,"us":Time.get_ticks_usec()-measurement_started,"tick":p("tick"),"living":c("living"),"people":people,"chilled":int(game.compare_mixed_probe("chilled",1)),"enemies":enemies,"drops":c("drops"),"loot":c("loot"),"damage":[c("damage",1),c("damage",2)],"kills":[c("kills",1),c("kills",2)],"scrap":[c("scrap",1),c("scrap",2)],"spent":[p("spent",1),p("spent",2)],"ammo":[p("ammo",1),p("ammo",2)],"projectiles":p("projectiles"),"resyncs":0 if implementation=="kit" else p("resyncs"),"lead":0 if implementation=="kit" else p("lead_ticks"),"prediction_depth":0 if implementation=="kit" else p("prediction_depth"),"facts_ahead":0 if implementation=="kit" else p("facts_head")-p("tick"),"reused":0 if implementation=="kit" else int(game.compare_reused()),"replayed":0 if implementation=="kit" else p("replayed_ticks")})
func until(predicate:Callable,timeout:int=20000)->bool:
 var deadline:=Time.get_ticks_msec()+timeout
 while Time.get_ticks_msec()<deadline and not finished:
  if phase in ["boot","fill"]:observe_warmup()
  if p("ready"):census()
  if predicate.call():return true
  await process_frame
 return false
func observe_warmup():
 var now:=Time.get_ticks_msec()
 if now<warmup_sample_at:return
 warmup_sample_at=now+100
 warmup_trace.append({"phase":phase,"ms":now-started,"tick":p("tick"),"lead":0 if implementation=="kit" else p("lead_ticks"),"depth":0 if implementation=="kit" else p("prediction_depth"),"facts_ahead":0 if implementation=="kit" else p("facts_head")-p("tick"),"resyncs":0 if implementation=="kit" else p("resyncs"),"large_snapshots":0 if implementation=="kit" else int(game.probe("large_snapshots",1))})
 if warmup_trace.size()%10==0:write("warmup-"+role,{"samples":warmup_trace})
func receive_steady()->bool:
 var now:=Time.get_ticks_msec()
 if implementation=="replay" and role=="client":
  if p("prediction_depth")>p("lead_ticks")+30 or p("facts_head")-p("tick")>30:steady_since=now
 return now-steady_since>=2000
func invariants()->bool:
 if p("stage")!=2 or p("players")!=2:return false
 for seat in [1,2]:
  if phase=="boot" and (p("x",seat)!=800+seat*40 or p("y",seat)!=544):return false
  if p("hp",seat)<1 or p("hp",seat)>10 or (phase in ["boot","fill"] and p("hp",seat)!=10) or p("iron",seat)!=0 or not game.compare_mixed_probe("loadout",seat):return false
  if p("mag",seat)!=8 or p("jam",seat)!=0 or p("cooldown",seat)!=20:return false
 return true
func fire(value:bool):game.compare_trigger(value);inputs.append({"us":Time.get_ticks_usec()-measurement_started,"fire":value})
func _initialize():
 condition=OS.get_environment("COMPARE_CONDITION");role=OS.get_environment("COMPARE_ROLE");implementation=OS.get_environment("COMPARE_IMPL");folder=OS.get_environment("COMPARE_DIR")
 resource_floor=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT));started=Time.get_ticks_msec();run.call_deferred()
func run():
 game=load("res://main.tscn").instantiate();root.add_child(game)
 if implementation=="kit":game.call("on_host" if role=="host" else "on_join")
 if not await until(func():return bool(game.is_seated()) if implementation=="kit" else bool(game.probe("ready",1))):fail("admission");return
 game.dev_loadout(0,0);game.compare_choose()
 if implementation=="replay":game.dev_drive(0,0,false)
 write("seated-"+role,{"ready":true})
 if not await until(func():return both("seated") and p("players")==2 and p("declared",1)==1 and p("declared",2)==1):fail("declaration");return
 write("declared-"+role,{"ready":true})
 if not await until(func():return both("declared")):fail("declaration barrier");return
 if implementation=="replay":
  game.on_ready()
  if not await until(func():return game.probe("marked_ready",1) and game.probe("marked_ready",2)):fail("readiness");return
 if role=="host":game.on_start()
 if not await until(func():return p("ready") and invariants() and c("stats_ready")):fail("initial state");return
 phase="fill"
 if role=="host":game.compare_swarm(true)
 if not await until(func():return c("living")>=40):fail("population fill");return
 write("populated-"+role,{"living":c("living")})
 if not await until(func():return both("populated")):fail("population barrier");return
 steady_since=Time.get_ticks_msec()
 if not await until(receive_steady):fail("receive-progress warmup");return
 warmup_receipt={"steady_ms":Time.get_ticks_msec()-steady_since,"lead":0 if implementation=="kit" else p("lead_ticks"),"prediction_depth":0 if implementation=="kit" else p("prediction_depth"),"facts_ahead":0 if implementation=="kit" else p("facts_head")-p("tick")}
 write("armed-"+role,{"living":c("living"),"known":seen.size()})
 if not await until(func():return both("armed")):fail("measurement barrier");return
 initial_ids=seen.keys()
 known_before=seen.size();kills_before=c("kills",1)+c("kills",2);shots_before=[p("spent",1),p("spent",2)]
 measurement_started=Time.get_ticks_usec();tick_before=p("tick");tx_before=int(game.compare_tx());phase="measure";game.compare_start();fire(true)
 write("measuring-"+role,{"unix":Time.get_unix_time_from_system()})
 while Time.get_ticks_usec()-measurement_started<20000000 and not finished:
  var elapsed_ms:=(Time.get_ticks_usec()-measurement_started)/1000
  if elapsed_ms>=next_segment*1000:
   var direction:Vector2i=DIRECTIONS[next_segment%4];game.compare_move(direction.x,direction.y)
   movement.append({"us":Time.get_ticks_usec()-measurement_started,"direction":[direction.x,direction.y]});next_segment+=1
  if next_cast<CASTS.size() and elapsed_ms>=CASTS[next_cast].x:
   game.compare_cast(CASTS[next_cast].y);casts.append({"us":Time.get_ticks_usec()-measurement_started,"slot":CASTS[next_cast].y});next_cast+=1
  if next_dash<10 and elapsed_ms>=500+next_dash*2000:
   game.compare_dash();dashes.append({"us":Time.get_ticks_usec()-measurement_started});next_dash+=1
  if role=="host" and next_hazard<HAZARDS.size() and elapsed_ms>=HAZARDS[next_hazard].x:
   game.compare_hazard(HAZARDS[next_hazard].y);hazards.append({"us":Time.get_ticks_usec()-measurement_started,"status":HAZARDS[next_hazard].y});next_hazard+=1
  census()
  if (implementation=="kit" or p("ready")) and not invariants():fail("measurement invariants");return
  await process_frame
 if finished:return
 var elapsed:=Time.get_ticks_usec()-measurement_started;game.compare_stop();phase="drain";fire(false);game.compare_move(0,0)
 if role=="host":game.compare_swarm(false)
 write("sampled-"+role,{"unix":Time.get_unix_time_from_system()})
 var count:=int(game.compare_sample(-1))
 if count<1000 or game.compare_sample(-2)!=0:fail("sample capacity/rate");return
 for i in count:frames.append(int(game.compare_sample(i)));frame_times.append(int(game.compare_sample_time(i))-measurement_started)
 var cast_receipts:=[]
 if implementation=="kit":
  for index in int(game.compare_cast_receipt("count",0)):
   var receipt:={}
   for key in ["slot","seen","submitted","state","reason","sequence","model"]:receipt[key]=int(game.compare_cast_receipt(key,index))
   cast_receipts.append(receipt)
 result={"cast_receipts":cast_receipts,"condition":condition,"dashes":dashes,"hazards":hazards,"hazards_sent":int(game.compare_mixed_probe("hazards_sent",1)),"hazards_refused":int(game.compare_mixed_probe("hazards_refused",1)),"reuse_enabled":false if implementation=="kit" else bool(game.compare_reuse_enabled()),"implementation":implementation,"role":role,"elapsed_us":elapsed,"ticks":p("tick")-tick_before,"tx_bytes":int(game.compare_tx())-tx_before,"frame_us":frames,"frame_at_us":frame_times,"census_us":census_cost,"trace":trace,"warmup_trace":warmup_trace,"warmup":warmup_receipt,"initial_ids":initial_ids,"known_before":known_before,"kills_before":kills_before,"shots_before":shots_before,"inputs":inputs,"issued":int(game.compare_spawned()),"movement":movement,"casts":casts,"cast_sent":[int(game.compare_mixed_probe("sent",1)),int(game.compare_mixed_probe("sent",2))],"cast_refused":[int(game.compare_mixed_probe("refused",1)),int(game.compare_mixed_probe("refused",2))]}
 if not await until(func():return both("sampled")):fail("stop barrier");return
 var settle_until:=Time.get_ticks_msec()+(8000 if condition=="lossy" else 2500)
 if not await until(func():return Time.get_ticks_msec()>=settle_until):fail("settle");return
 if not await until(func():return p("ready") and p("projectiles")<=0 and p("mode",1)==0 and p("mode",2)==0,5000):fail("projectile drain");return
 result.dash_receipts={}
 if implementation=="replay":
  if not await until(func():return int(game.dash_probe("pending"))==0 and int(game.dash_probe("captured"))==0):fail("dash outcome drain");return
  for key in ["submitted","confirmed","refused","pending","captured"]:result.dash_receipts[key]=int(game.dash_probe(key))
 result.final_resyncs=0 if implementation=="kit" else p("resyncs")
 result.final_ready=bool(p("ready"))
 result.final={"living":c("living"),"damage":[c("damage",1),c("damage",2)],"kills":[c("kills",1),c("kills",2)],"scrap":[c("scrap",1),c("scrap",2)],"loot":c("loot"),"known":seen.size(),"health_sum":health_sum_now,"spent":[p("spent",1),p("spent",2)],"hp":[p("hp",1),p("hp",2)],"dashes":[int(game.compare_mixed_probe("dashes",1)),int(game.compare_mixed_probe("dashes",2))]}
 write("success-"+role,result)
 if not await until(func():return both("success")):fail("completion barrier");return
 game.set_process(false);multiplayer_poll=false;write("quiesced-"+role,{"ready":true})
 if not await until(func():return both("quiesced")):fail("quiescence");return
 print("REPLAY_ENDURANCE_PEER_OK ",implementation," ",role)
 await finish(0)
