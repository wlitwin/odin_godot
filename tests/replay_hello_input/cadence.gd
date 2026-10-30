extends SceneTree
var game:Node
func check(ok:bool,why:String)->bool:
 if not ok:push_error("HELLO_INPUT_FAIL "+why);quit(1)
 return ok
func _initialize():
 game=load("res://hello.tscn").instantiate();root.add_child(game);game.set_process(false);call_deferred("run")
func run():
 game.set_process(false)
 for fps in [30,60,120,144]:
  game.restart();Input.action_press("ui_right");Input.action_press("ui_accept")
  for _i in range(fps):game.input_frame(1.0/fps)
  Input.action_release("ui_right");Input.action_release("ui_accept");await process_frame
  if not check(int(game.probe_tick())==60 and int(game.probe_shots())==5,"one second held cadence "+str(fps)):return
  if not check(abs(float(game.probe_x())-280.0)<.01 and bool(game.probe_audit()),"shared movement/renderer audit "+str(fps)):return
 # A complete press/release on a render frame with no fixed tick is consumed once.
 game.restart();Input.action_press("ui_accept");game.input_frame(1.0/240.0)
 Input.action_release("ui_accept");await process_frame
 game.input_frame(1.0/240.0)
 print("HELLO_SHORT_TRACE tick=",game.probe_tick()," pressed=",game.input_metric("pressed")," gate=",game.input_metric("gate")," accumulator=",game.input_metric("accumulator"))
 if not check(int(game.probe_tick())==0 and int(game.input_metric("pressed"))==1,"short press retained before tick"):return
 game.input_frame(1.0/120.0)
 if not check(int(game.probe_tick())==1 and int(game.probe_shots())==1,"short press fires once"):return
 game.input_frame(1.0/60.0)
 if not check(int(game.probe_shots())==1 and int(game.input_metric("pressed"))==0,"edge consumed only once"):return
 var before:int=int(game.probe_tick());game.input_frame(10.0)
 if not check(int(game.probe_tick())==before+8 and float(game.input_metric("dropped"))>9.0,"catch-up is bounded"):return
 game.pause(true);var tick:int=int(game.probe_tick());game.input_frame(10.0)
 if not check(int(game.probe_tick())==tick and float(game.input_metric("accumulator"))==0,"pause clears backlog"):return
 game.pause(false);game.input_frame(0.0)
 if not check(int(game.probe_tick())==tick,"resume has no backlog"):return
 # A complete paused tap followed by resume in the same device frame must
 # not survive through Godot's just-pressed flag even though held is already up.
 game.restart();game.pause(true);Input.action_press("ui_accept");Input.action_release("ui_accept");game.pause(false)
 game.input_frame(1.0/60.0)
 if not check(int(game.probe_shots())==0,"same-frame paused tap is discarded"):return
 print("REPLAY_HELLO_INPUT_CADENCE_OK");quit(0)
