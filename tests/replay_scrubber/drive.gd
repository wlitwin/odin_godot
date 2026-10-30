extends SceneTree
var game:Node
var slider:HSlider
var branch:Button
var fields:OptionButton
var value:LineEdit
var apply_edit:Button
var reset_edit:Button
var export_recording:Button
var finished:=false
var observations:=[]
var folder:=""
func _initialize():
 folder=OS.get_environment("SCRUBBER_RESULT_DIR")
 run.call_deferred()
func key(code:Key,down:bool):
 var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=down;Input.parse_input_event(event)
func frames(n:int):
 for _i in range(n):await process_frame
func tap(code:Key):
 key(code,true);await frames(2);key(code,false);await frames(2)
func p(name:String)->int:return int(game.probe_history(name))
func record(name:String):
 observations.append({"name":name,"head":int(game.probe_tick()),"selected":p("selected"),"first":p("first"),"last":p("last"),"epoch":p("epoch"),"active":p("active"),"edited":p("edited"),"exports":p("exports"),"x":float(game.probe_x()),"shots":int(game.probe_shots()),"views":int(game.probe_views()),"begins":int(game.probe_begins()),"edit_status":str(game.find_child("ReplayFieldStatus",true,false).text),"status":str(game.get_node("Status").text)})
func finish(code:int,reason:String=""):
 if finished:return
 finished=true
 var file:=FileAccess.open(folder+"/result.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"pass":code==0,"reason":reason,"observations":observations}));file.close();file=null
 print("REPLAY_SCRUBBER_", "OK" if code==0 else "FAIL", " ",reason)
 game.queue_free();game=null;slider=null;branch=null;await frames(3);quit(code)
func choose(offset:int):
 slider.value=offset;await frames(2)
func mouse_event(event:InputEvent):
 Input.parse_input_event(event)
 if DisplayServer.get_name()=="headless":root.push_input(event,true)
func click(button:Button):
 var point:=button.get_global_rect().get_center()
 var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.button_mask=MOUSE_BUTTON_MASK_LEFT;event.pressed=true;mouse_event(event)
 # Both button events deliberately arrive before the next frame.
 event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=false;mouse_event(event)
 await frames(2)
func edit(path:String,text:String):
 for index in range(fields.item_count):
  if fields.get_item_text(index)==path:
   fields.select(index);await frames(2);value.text=text;await click(apply_edit)
   record("edit:"+path+"="+text)
   return
 await finish(1,"missing field "+path)
func save_recording(name:String):
 var before:=p("exports")
 await click(export_recording)
 if p("exports")!=before+1 or p("export_bytes")<=0:await finish(1,"recording export");return
 var result:=DirAccess.copy_absolute(OS.get_environment("REPLAY_RECORDING_PATH"),folder+"/"+name+".rplrec")
 if result!=OK:await finish(1,"recording copy");return
 record("recorded_"+name)
func run():
 game=load("res://hello.tscn").instantiate();game.debug_enabled=true;root.add_child(game);game.pause(true)
 for node in game.find_children("*","HSlider",true,false):slider=node;break
 for node in game.find_children("*","Button",true,false):
  if str(node.text)=="Branch from this frame":branch=node
  if str(node.text)=="Apply to preview":apply_edit=node
  if str(node.text)=="Reset preview":reset_edit=node
  if node.name=="ReplayRecordingExport":export_recording=node
 for node in game.find_children("*","OptionButton",true,false):fields=node;break
 for node in game.find_children("*","LineEdit",true,false):
  if node.name=="ReplayFieldValue":value=node;break
 if slider==null or branch==null or fields==null or value==null or apply_edit==null or reset_edit==null or export_recording==null:await finish(1,"missing controls");return
 # Keep the older audit panel hidden while the history dock remains usable.
 await tap(KEY_F8)
 game.pause(false);key(KEY_RIGHT,true);key(KEY_SPACE,true);await frames(24)
 key(KEY_RIGHT,false);key(KEY_SPACE,false);game.pause(true);await frames(2)
 var head:=int(game.probe_tick());var x:=float(game.probe_x());var shots:=int(game.probe_shots());var begins:=int(game.probe_begins());var views:=int(game.probe_views());var epoch:=p("epoch")
 if head<20 or head>80 or shots<2 or views<=2:await finish(1,"initial live workload");return
 record("live")
 await tap(KEY_F10)
 if p("active")!=1 or p("last")!=head or p("first")!=0:await finish(1,"pause/window");return
 await choose(0);record("past")
 if p("selected")!=0 or game.probe_tick()!=head or game.probe_x()!=x or game.probe_shots()!=shots or game.probe_views()!=2 or game.probe_begins()!=begins or game.get_node("Flash").visible:await finish(1,"inspection changed live history or replayed effects");return
 if not "tick 0    shots 0" in str(game.get_node("Status").text):await finish(1,"selected world not painted");return
 await choose(int(slider.max_value));record("head")
 if game.probe_views()!=views or game.probe_begins()!=begins or not game.probe_audit():await finish(1,"head view/audit");return
 await choose(0)
 await edit("$.actors.count","99")
 if p("edited")!=0:await finish(1,"model-invalid edit accepted");return
 await edit("$.shots","18446744073709551616")
 if p("edited")!=0:await finish(1,"overflow edit accepted");return
 await edit("$.shots","42");record("edited_preview")
 if p("edited")!=1 or game.probe_shots()!=shots or not "shots 42" in str(game.get_node("Status").text) or game.probe_begins()!=begins:await finish(1,"preview edit mutated live state/effects");return
 await click(reset_edit)
 if p("edited")!=0 or not "shots 0" in str(game.get_node("Status").text):await finish(1,"preview reset");return
 await edit("$.shots","41");await choose(1);await choose(0)
 if p("edited")!=0 or not "shots 0" in str(game.get_node("Status").text):await finish(1,"selection retained edit");return
 await edit("$.shots","42")
 await save_recording("original")
 var capture:=OS.get_environment("SCRUBBER_CAPTURE")
 if capture!="":
  await RenderingServer.frame_post_draw
  var captured:=root.get_texture().get_image();var err:=captured.save_png(capture);captured=null
  if err!=OK:await finish(1,"capture");return
 await tap(KEY_F10);await frames(12);record("resumed_original_paused")
 if p("active")!=0 or p("epoch")!=epoch or game.probe_tick()!=head or game.probe_views()!=views or game.probe_begins()!=begins:await finish(1,"resume discarded future or prior pause");return
 game.pause(false);await tap(KEY_F10);await choose(0)
 await edit("$.actors.values[0].body.position[0]","240")
 if p("edited")!=1:await finish(1,"position edit");return
 key(KEY_RIGHT,true);key(KEY_SPACE,true);await frames(3)
 await click(branch);await frames(5);record("branched_held_input")
 if p("active")!=0 or p("epoch")!=epoch+1 or game.probe_tick()>=head or game.probe_shots()!=0 or game.probe_x()!=240.0 or game.probe_views()!=2 or game.probe_begins()!=begins:await finish(1,"branch/effect epoch/held input guard");return
 key(KEY_RIGHT,false);key(KEY_SPACE,false);await frames(2)
 key(KEY_SPACE,true);await frames(2);key(KEY_SPACE,false);await frames(2);record("new_branch_shot")
 if game.probe_shots()!=1 or game.probe_begins()!=begins+1 or not game.probe_audit():await finish(1,"fresh branch input/effect");return
 if capture!="":
  await RenderingServer.frame_post_draw
  var shot_image:=root.get_texture().get_image();var shot_error:=shot_image.save_png(capture.get_base_dir()+"/shot.png");shot_image=null
  if shot_error!=OK:await finish(1,"shot capture");return
 game.pause(true);await save_recording("branch");game.pause(false)
 await frames(160);game.pause(true);await tap(KEY_F10);await choose(0);record("wrapped")
 if p("first")==0 or p("selected")!=p("first") or p("last")-p("first")!=127:await finish(1,"wrapped history range");return
 var new_epoch:=p("epoch");game.restart();await frames(3);record("reset")
 if p("active")!=0 or p("epoch")!=new_epoch+1 or game.probe_shots()!=0 or game.probe_views()!=2:await finish(1,"stale selection after reset");return
 await finish(0,"inspection resume branch views effects input and wrap")
