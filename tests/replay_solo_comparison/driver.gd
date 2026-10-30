extends SceneTree
const Navigation = preload("res://solo_navigation.gd")

const KEYS = ["tick", "stage", "run", "floor", "wave", "pending", "alive", "done", "rest_until", "spawned", "living", "props", "projectiles", "shots", "booms", "kills", "hp", "x", "y", "cores", "scrap", "mag", "jam", "iron"]
var game: Node
var implementation := ""
var folder := ""
var started := 0
var phase := "boot"
var trace := []
var inputs := []
var previous := {}
var sampled_at := 0
var resource_floor := 0
var finished := false
var nav = Navigation.new()
var navigation := []
var covers := []
var blocked_proof := {}
var barrel_receipt := {}
var forced_obstruction := false
var finale_mode := "navigate"

func p(key: String) -> int:
 return int(game.solo_probe(key))

func write(name: String, value: Dictionary):
 var f := FileAccess.open(folder + "/" + name + ".json", FileAccess.WRITE)
 f.store_string(JSON.stringify(value)); f.close()

func observe() -> Dictionary:
 var pos:Vector2=game.solo_position()
 var row := {"ms": Time.get_ticks_msec() - started, "phase": phase,"position":[pos.x,pos.y]}
 for key in KEYS: row[key] = p(key)
 # Record every director/health edge as well as regular trajectory samples.
 var changed := previous.is_empty()
 for key in ["phase", "wave", "pending", "alive", "done", "rest_until", "stage", "hp", "props", "booms"]:
  if previous.get(key, row[key]) != row[key]: changed = true
 if changed or row.ms >= sampled_at:
  trace.append(row); sampled_at = row.ms + 100
 previous = row
 return row

func drive(x: int, y: int, fire: bool):
 game.solo_input(x, y, fire)
 var command := [x, y, fire]
 if inputs.is_empty() or inputs.back().command != command:
  inputs.append({"ms": Time.get_ticks_msec() - started, "command": command})

func finish(code: int, reason: String):
 if finished: return
 finished = true
 write("result", {"implementation": implementation, "pass": code == 0, "reason": reason, "phase": phase, "trace": trace, "inputs": inputs,"covers":covers,"navigation":navigation,"blocked_proof":blocked_proof,"barrel_receipt":barrel_receipt,"forced_obstruction":forced_obstruction,"finale_mode":finale_mode})
 print("SOLO_COMPARE_", "OK" if code == 0 else "FAIL", " ", implementation, " ", reason)
 game.queue_free(); game = null
 await process_frame; await process_frame
 var deadline := Time.get_ticks_msec() + 2000
 while int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) > resource_floor and Time.get_ticks_msec() < deadline:
  await process_frame
 var remaining := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) - resource_floor
 write("shutdown", {"resources_remaining": remaining})
 quit(code)

func _initialize():
 implementation = OS.get_environment("COMPARE_IMPL"); folder = OS.get_environment("COMPARE_DIR")
 forced_obstruction=OS.get_environment("REPLAY_SOLO_OBSTRUCTED")=="1"
 finale_mode=OS.get_environment("REPLAY_SOLO_FINALE");if finale_mode=="":finale_mode="navigate"
 resource_floor = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 run.call_deferred()

func targets() -> Array:
 var result:=[]
 for i in p("props"):
  var prop:Vector3=game.solo_prop(i);result.append(Vector2(prop.x,prop.y))
 return result

func prop_health() -> Array:
 var result:=[]
 for i in p("props"):
  var prop:Vector3=game.solo_prop(i);result.append(int(prop.z))
 return result

func walk_route(path: Array, deadline: int) -> bool:
 for target in path:
  while Time.get_ticks_msec()<deadline:
   var pos:Vector2=game.solo_position();var delta:Vector2=target-pos
   if delta.length()<=6.0:break
   drive(int(sign(delta.x)) if absf(delta.x)>4 else 0,int(sign(delta.y)) if absf(delta.y)>4 else 0,false)
   observe();await process_frame
  if Time.get_ticks_msec()>=deadline:return false
 drive(0,0,false);return true

func plan_route(destination = null) -> Dictionary:
 var start:Vector2=game.solo_position();var targets_now:=targets()
 var plan:Dictionary=nav.route(start,targets_now,destination)
 var points:=[]
 for point in plan.path:points.append([point.x,point.y])
 navigation.append({"ms":Time.get_ticks_msec()-started,"phase":phase,"from":[start.x,start.y],"targets":targets_now.map(func(x):return [x.x,x.y]),"path":points,"found":plan.found,"nodes":plan.nodes,"destination":null if destination==null else [destination.x,destination.y]})
 return plan

func run():
 game = load("res://main.tscn").instantiate(); root.add_child(game)
 if implementation == "kit": game.on_single(); game.on_start()
 var deadline := Time.get_ticks_msec() + 20000
 var start_sent := false
 while not p("ready") and Time.get_ticks_msec() < deadline:
  if implementation == "replay" and not start_sent and game.probe("ready", 1) and game.probe("players", 1) == 1 and game.probe("meta_claimed", 1):
   game.on_start(); start_sent = true
  await process_frame
 if not p("ready"): finish(1, "world admission timeout"); return
 for i in game.solo_cover_count():
  var rect:Rect2=game.solo_cover(i);nav.covers.append(rect);covers.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
 if covers.size()!=30 or not finale_mode in ["stationary","navigate"]:finish(1,"geometry/controller configuration");return
 started = Time.get_ticks_msec(); phase = "waves"
 var initial := observe()
 if initial.hp != 10 or initial.floor != 1 or initial.iron != 0 or initial.mag != 255 or initial.jam != 0 or initial.cores != 0:
  finish(1, "initial scenario mismatch"); return
 while Time.get_ticks_msec() - started < 180000:
  var elapsed := Time.get_ticks_msec() - started
  drive(int(sign(cos(float(elapsed) / 700.0))), int(sign(sin(float(elapsed) / 700.0))), true)
  var row := observe()
  if row.hp <= 0 or row.run != initial.run or row.floor != 1 or row.stage == 3:
   finish(1, "solo crew wiped"); return
  if row.stage == 2 and row.done == 1 and row.living == 0: break
  await process_frame
 if p("stage") != 2 or p("spawned") != 13 or p("wave") != 3:
  finish(1, "three-wave clear timeout/count"); return
 phase = "drain"; drive(0, 0, false)
 deadline = Time.get_ticks_msec() + 2500
 while p("projectiles") > 0 and Time.get_ticks_msec() < deadline:
  drive(0, 0, false); observe(); await process_frame
 if p("projectiles") != 0: finish(1, "projectile drain"); return
 if forced_obstruction:
  phase="position_obstruction";var positioning:=plan_route(Vector2(788,588))
  if not positioning.found or not await walk_route(positioning.path,Time.get_ticks_msec()+15000):finish(1,"obstruction position unavailable");return
 var before_blasts := p("booms")
 phase = "spawn_barrels"
 var spawn_origin:Vector2=game.solo_position()
 game.dev_spawn(5, 1, 150, 0); game.dev_spawn(5, 1, 150, 50)
 deadline = Time.get_ticks_msec() + 2000
 while p("props") < 2 and Time.get_ticks_msec() < deadline:
  drive(0, 0, false); observe(); await process_frame
 if p("props") != 2: finish(1, "two live barrels not admitted"); return
 var admitted:=[]
 for i in 2:
  var prop:Vector3=game.solo_prop(i);admitted.append([prop.x,prop.y,prop.z])
 barrel_receipt={"origin":[spawn_origin.x,spawn_origin.y],"props":admitted,"ms":Time.get_ticks_msec()-started}
 phase = "barrels";observe();deadline=Time.get_ticks_msec()+25000
 if forced_obstruction:
  var at:Vector2=game.solo_position();var prior_health:=prop_health();var prior_shots:=p("shots")
  if nav.shot_clear(at,targets()):finish(1,"expected cover obstruction missing");return
  var through:=Time.get_ticks_msec()+1500
  while Time.get_ticks_msec()<through:drive(0,0,true);observe();await process_frame
  drive(0,0,false)
  blocked_proof={"ms":Time.get_ticks_msec()-started,"position":[at.x,at.y],"health_before":prior_health,"health_after":prop_health(),"shots":p("shots")-prior_shots,"booms":p("booms")-before_blasts,"props":p("props")}
  if p("props")!=2 or prop_health()!=prior_health or p("booms")!=before_blasts or p("shots")<=prior_shots:finish(1,"obstructed shots bypassed cover");return
 while p("props") > 0 and Time.get_ticks_msec() < deadline:
  var pos:Vector2=game.solo_position()
  if finale_mode=="navigate" and not nav.shot_clear(pos,targets()):
   var plan:=plan_route()
   if not plan.found or plan.path.is_empty():finish(1,"no safe firing route");return
   if not await walk_route(plan.path,deadline):finish(1,"firing route timeout");return
  else:
   drive(0,0,true);observe();await process_frame
 drive(0, 0, false); observe()
 if p("props") != 0 or p("booms") - before_blasts < 2:
  finish(1, "barrel finale failed"); return
 if p("hp") <= 0: finish(1, "barrel finale killed solo crew"); return
 phase = "complete"; observe(); finish(0, "three waves and two barrel blasts")
