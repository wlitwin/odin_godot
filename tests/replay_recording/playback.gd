extends SceneTree
var game:Node
var folder:String
var files:String
var finished:=false
var observations:=[]
func _initialize():
 folder=OS.get_environment("PLAYBACK_RESULT_DIR");files=OS.get_environment("PLAYBACK_FILES")
 root.gui_embed_subwindows=true;run.call_deferred()
func frames(n:int):
 for _i in range(n):await process_frame
func p(name:String)->int:return int(game.probe_history(name))
func button(name:String)->Button:return game.find_child("ReplayPlayback"+name,true,false)
func record(name:String):
 observations.append({"name":name,"live_tick":int(game.probe_tick()),"live_x":float(game.probe_x()),"live_shots":int(game.probe_shots()),"live_epoch":p("epoch"),"begins":int(game.probe_begins()),"views":int(game.probe_views()),"active":p("playback"),"selected":p("playback_selected"),"loads":p("playback_loads"),"rejections":p("playback_rejections"),"status":str(game.get_node("Status").text),"report":str(game.find_child("ReplayPlaybackReport",true,false).text)})
func send(event:InputEvent):
 Input.parse_input_event(event)
 if DisplayServer.get_name()=="headless":root.push_input(event,true)
func click(node:Button):
 var point:Vector2=root.get_screen_transform().affine_inverse()*(node.get_viewport().get_screen_transform()*node.get_global_rect().get_center())
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;send(event)
 await frames(3)
func key(code:Key,down:bool):
 var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=down;send(event)
func open_file(path:String):
 await click(button("Open"))
 var dialog:FileDialog=game.find_child("ReplayRecordingFileDialog",true,false)
 if not dialog.visible:await finish(1,"file chooser did not open");return
 dialog.current_path=path;await frames(8)
 # Programmatic path assignment does not select a file in Godot's file list.
 # Select the matching row, then exercise the actual Open button and file_selected signal.
 for list in dialog.find_children("*","ItemList",true,false):
  for index in range(list.item_count):
   if list.get_item_text(index)==path.get_file():list.select(index);list.emit_signal("item_selected",index)
 await frames(3)
 await click(dialog.get_ok_button());await frames(3)
func select_tick(offset:int):
 var slider:HSlider=game.find_child("ReplayPlaybackSlider",true,false);slider.value=offset;await frames(3)
func finish(code:int,reason:String):
 if finished:return
 finished=true;record("finished")
 if OS.get_environment("PLAYBACK_CAPTURE")!="":
  await RenderingServer.frame_post_draw
  var image:=root.get_texture().get_image();image.save_png(folder+"/failure.png");image=null
 var file:=FileAccess.open(folder+"/result.json",FileAccess.WRITE);file.store_string(JSON.stringify({"pass":code==0,"reason":reason,"observations":observations}));file.close();file=null
 print("REPLAY_PLAYBACK_", "OK" if code==0 else "FAIL", " ",reason)
 game.queue_free();game=null;await frames(4);quit(code)
func run():
 game=load("res://hello.tscn").instantiate();game.debug_enabled=true;root.add_child(game);game.pause(true);await frames(3)
 key(KEY_F8,true);await frames(2);key(KEY_F8,false);await frames(2)
 await click(button("Open"))
 var dialog:FileDialog=game.find_child("ReplayRecordingFileDialog",true,false)
 await click(dialog.get_cancel_button());await frames(4)
 if p("playback")!=0 or game.probe_tick()!=0:await finish(1,"cancel/pause preservation");return
 await open_file(files+"/original.rplrec");if finished:return
 record("loaded")
 if p("playback")!=1 or p("playback_loads")!=1 or p("playback_selected")!=0 or game.probe_tick()!=0 or game.probe_begins()!=0:await finish(1,"load mutated live timeline/effects");return
 await click(button("Play"));await frames(40);record("played")
 if p("playback_selected")!=p("playback_head") or p("playback_playing")!=0 or game.probe_tick()!=0 or game.probe_begins()!=0:await finish(1,"playback did not finish or replayed effects");return
 if not "shots 2" in str(game.get_node("Status").text):await finish(1,"recorded world not painted");return
 await select_tick(0)
 await open_file(files+"/bad.rplrec");if finished:return
 record("rejected")
 if p("playback_rejections")!=1 or p("playback_loads")!=1 or p("playback_selected")!=0 or p("playback")!=1:await finish(1,"bad replacement destroyed loaded recording");return
 await click(button("Close"));await frames(8)
 if game.probe_tick()!=0 or p("playback")!=0 or game.probe_begins()!=0:await finish(1,"return did not preserve paused original");return
 await open_file(files+"/branch.rplrec");if finished:return
 if not "tick 0" in str(game.get_node("Status").text):await finish(1,"branch recording baseline");return
 game.pause(false) # Prior pause is tested above; branch must restore the saved pause, not this override.
 key(KEY_RIGHT,true);key(KEY_SPACE,true);await click(button("Branch"));await frames(5);record("branched")
 if p("playback")!=0 or p("epoch")!=2 or game.probe_tick()!=0 or game.probe_x()!=240.0 or game.probe_shots()!=0 or game.probe_begins()!=0:await finish(1,"branch copied wrong frame or leaked held input/pause");return
 key(KEY_RIGHT,false);key(KEY_SPACE,false);game.pause(false);await frames(3)
 key(KEY_SPACE,true);await frames(3);key(KEY_SPACE,false);await frames(3)
 if game.probe_shots()!=1 or game.probe_begins()!=1 or not game.probe_audit():await finish(1,"new branch input/effect");return
 game.pause(true);await open_file(files+"/mismatch.rplrec");if finished:return
 record("mismatch")
 if p("playback_loads")!=3 or not "$.shots" in str(game.find_child("ReplayPlaybackReport",true,false).text) or p("playback_selected")!=p("playback_head"):await finish(1,"mismatch diagnostics");return
 var capture:=OS.get_environment("PLAYBACK_CAPTURE")
 if capture!="":
  await RenderingServer.frame_post_draw
  var image:=root.get_texture().get_image();var error:=image.save_png(capture);image=null
  if error!=OK:await finish(1,"capture");return
 game.restart();await frames(4)
 if p("playback")!=0 or game.probe_shots()!=0 or p("epoch")!=3:await finish(1,"reset retained loaded recording");return
 await click(button("Open"));game.queue_free();game=null;await frames(4)
 # A pending picker teardown must release every callable/window.
 finished=true
 var result:=FileAccess.open(folder+"/result.json",FileAccess.WRITE);result.store_string(JSON.stringify({"pass":true,"observations":observations}));result.close();result=null
 print("REPLAY_PLAYBACK_OK load seek play cancel reject mismatch branch effects teardown");quit(0)
