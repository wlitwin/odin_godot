extends SceneTree
var game:Node
func check(ok:bool,why:String)->bool:
 if not ok:push_error("HELLO_INPUT_FAIL "+why);quit(1)
 return ok
func frames(n:int):
 for _i in n:await process_frame
func _initialize():
 game=load("res://hello.tscn").instantiate();root.add_child(game);call_deferred("run")
func run():
 await frames(3)
 game.pause(true)
 var tick:int=int(game.probe_tick());var shots:int=int(game.probe_shots())
 Input.action_press("ui_accept");await frames(2);Input.action_release("ui_accept");await frames(2)
 if not check(int(game.probe_tick())==tick and int(game.probe_shots())==shots,"pause freezes simulation"):return
 game.pause(false);await frames(8)
 if not check(int(game.probe_shots())==shots,"paused tap is not deferred gameplay"):return
 game.pause(true)
 Input.action_press("ui_accept");Input.action_press("ui_right");await frames(2)
 var x:float=float(game.probe_x());shots=int(game.probe_shots())
 game.pause(false);await frames(8)
 if not check(float(game.probe_x())==x and int(game.probe_shots())==shots,"held pause input waits for release"):return
 Input.action_release("ui_accept");Input.action_release("ui_right");await frames(2)
 Input.action_press("ui_accept");await frames(2);Input.action_release("ui_accept");await frames(2)
 if not check(int(game.probe_shots())==shots+1,"fresh post-pause press works"):return
 print("REPLAY_HELLO_PAUSE_INPUT_OK");quit(0)
