extends SceneTree
var game:Node
var role:String
var folder:String
var phase:="join"
var started:=0
var stage_time:=0
var observations:=[]
var closing:=false
func _initialize():
 role=OS.get_environment("REPLAY_CAVE_ROLE");folder=OS.get_environment("CAVE_SOCIAL_OUT");run.call_deferred()
func run():
 game=load("res://cave.tscn").instantiate()
 if role=="host":
  var definition:Resource=game.floor1_def.duplicate(true);definition.wave_counts=PackedInt32Array([0]);definition.wave_rests=PackedInt32Array([0]);game.floor1_def=definition
 root.add_child(game);started=Time.get_ticks_msec()
func cell(row:int,column:int)->Label:return game.get_node("Social/Scoreboard/Column/Grid/Row%d_%d"%[row,column])
func mark_labels()->Array:
 var labels:=[]
 for node in game.find_children("CavePingName","Label",true,false):
  if not node.is_queued_for_deletion() and not node.get_parent().is_queued_for_deletion():labels.append(str(node.text))
 return labels
func write(name:String):
 var file:=FileAccess.open(folder+"/"+name+".json.pending",FileAccess.WRITE);file.store_string("{}");file.close();DirAccess.rename_absolute(folder+"/"+name+".json.pending",folder+"/"+name+".json")
func seen(name:String)->bool:return FileAccess.file_exists(folder+"/"+name+".json")
func all_seen(name:String)->bool:return seen(name+"-host") and seen(name+"-client") and seen(name+"-observer")
func record(name:String):
 observations.append({"name":name,"head":game.probe_head(),"epoch":game.probe_epoch(),"names":[cell(0,0).text,cell(1,0).text],"ping":[cell(0,7).text,cell(1,7).text],"visible":[cell(0,7).visible,cell(1,7).visible,cell(2,7).visible],"marks":mark_labels()})
func finish(code:int,reason:String):
 if closing:return
 closing=true;record("finish")
 var file:=FileAccess.open(folder+"/"+role+"-result.json",FileAccess.WRITE);file.store_string(JSON.stringify({"pass":code==0,"reason":reason,"observations":observations}));file.close();file=null
 print("REPLAY_CAVE_SOCIAL_DETAIL_", "OK" if code==0 else "FAIL", " role=",role," ",reason)
 game.queue_free();game=null;await process_frame;await process_frame;quit(code)
func _process(_dt:float)->bool:
 if closing or game==null:return false
 var now:=Time.get_ticks_msec()
 if now-started>40000:finish(1,"timeout "+phase);return false
 if not game.probe_ready() and phase not in ["left","wait_rejoin"]:return false
 match phase:
  "join":
   if game.probe_players()!=2 or game.lobby_name(1)!="Alpha" or game.lobby_name(2)!="Beta":return false
   game.show_score(true);phase="measure"
  "measure":
   if not cell(1,7).text.is_valid_int():return false
   var ping:=int(cell(1,7).text)
   if cell(0,7).text!="0" or ping<200 or ping>2000 or cell(2,7).visible:finish(1,"latency values/observer row");return false
   record("measured");write("measured-"+role);phase="start"
  "start":
   if not all_seen("measured"):return false
   if role!="observer":game.on_ready_button()
   phase="ready"
  "ready":
   if game.lobby_probe("ready",0)!=3:return false
   if role=="host":game.on_start()
   phase="play"
  "play":
   if game.lobby_probe("phase",0)!=1:return false
   game.show_score(false)
   if role=="client":game.mark()
   phase="old_mark"
  "old_mark":
   if not mark_labels().has("Beta"):return false
   record("old_mark");write("old-mark-"+role);phase="rename"
  "rename":
   if not all_seen("old-mark"):return false
   if role=="client":
    var name:LineEdit=game.get_node("Lobby/Panel/Column/Name");name.text="Scout [x]";name.text_submitted.emit(name.text)
   phase="renamed"
  "renamed":
   if game.lobby_name(2)!="Scout [x]":return false
   if not mark_labels().has("Beta"):finish(1,"rename changed/expired existing marker before acknowledgement");return false
   if role=="client":game.mark()
   phase="new_mark"
  "new_mark":
   if not mark_labels().has("Scout [x]"):return false
   if not mark_labels().has("Beta"):finish(1,"old marker attribution was rewritten");return false
   game.show_score(true);phase="capture"
  "capture":
   if cell(1,0).text!="Scout [x]":return false
   if not mark_labels().has("Beta") or not mark_labels().has("Scout [x]"):finish(1,"marker names not retained across scoreboard display");return false
   record("renamed_marks");stage_time=now;phase="expire"
   if role=="host" and OS.get_environment("CAVE_SOCIAL_CAPTURE")!="":capture.call_deferred()
  "expire":
   if now-stage_time<2700:return false
   if not mark_labels().is_empty():finish(1,"marker expiry");return false
   write("expire-"+role);phase="leave"
  "leave":
   if not all_seen("expire"):return false
   if role=="client":game.on_leave();stage_time=now;phase="left"
   else:phase="gone"
  "left":
   if now-stage_time<500:return false
   if game.probe_ready() or game.get_node("Social/Scoreboard").visible or game.social_metrics("enabled",0)!=0 or game.social_metrics("known",2)!=0:finish(1,"leave state/telemetry retained");return false
   write("left");phase="wait_rejoin"
  "gone":
   if game.probe_players()!=1 or cell(1,7).visible:return false
   record("departed");write("gone-"+role);phase="rejoined"
  "wait_rejoin":
   if not seen("gone-host") or not seen("gone-observer"):return false
   game.on_join();phase="rejoined"
  "rejoined":
   if not game.probe_ready() or game.probe_players()!=2:return false
   game.show_score(true)
   if game.lobby_name(2)!="Scout [x]" or game.social_metrics("known",2)!=1 or not cell(1,7).text.is_valid_int() or int(cell(1,7).text)!=game.social_metrics("ms",2):return false
   if int(cell(1,7).text)<200 or cell(2,7).visible:finish(1,"rejoin latency/roster");return false
   record("rejoined");write("done-"+role);phase="done"
  "done":
   if all_seen("done"):finish(0,"measured RTT stamped names expiry and rejoin")
 return false
func capture():
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image();image.save_png(OS.get_environment("CAVE_SOCIAL_CAPTURE"));image=null
