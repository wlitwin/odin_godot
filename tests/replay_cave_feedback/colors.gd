extends SceneTree
var game:Node
func check(ok:bool,why:String):
 if not ok:push_error("CAVE_FEEDBACK_FAIL "+why);quit(1)
func _initialize():
 game=load("res://cave.tscn").instantiate();root.add_child(game);call_deferred("run")
func run():
 var deadline:=Time.get_ticks_msec()+15000
 while int(game.feedback_probe("ready"))!=1:
  if Time.get_ticks_msec()>deadline:check(false,"startup");return
  await process_frame
 game.set_process(false)
 var avatar:Node2D=game.get_node("Stage/Spelunker")
 game.feedback_inject(0,4,200.0,150.0) # player Hit
 var node:Node2D=game.feedback_node()
 var emitter:CPUParticles2D=node.get_node("Particles")
 check(avatar.modulate.is_equal_approx(Color(1,.35,.35,1)),"player hit flash")
 check(emitter.color.is_equal_approx(Color(1,.9,.4,1)),"impact sparks")
 game.feedback_inject(1,8,210.0,150.0) # Update to Slain
 check(avatar.modulate.is_equal_approx(Color.WHITE),"old flash retires on update")
 check(emitter.color.is_equal_approx(Color(.8,.4,1,1)),"dweller death color")
 check(int(game.feedback_probe("started"))==1,"color update does not restart")
 game.feedback_inject(2,8,210.0,150.0)
 await process_frame
 game.on_leave()
 print("REPLAY_CAVE_FEEDBACK_VISUAL_OK colors")
 quit(0)
