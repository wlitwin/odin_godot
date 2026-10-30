extends SceneTree
var game:Node
func check(ok:bool,why:String):
 if not ok:push_error("CAVE_ROCK_FAIL "+why);quit(1)
func _initialize():
 game=load("res://cave.tscn").instantiate();root.add_child(game);call_deferred("run")
func run():
 var start:=Time.get_ticks_msec()
 while not game.probe_ready():
  if Time.get_ticks_msec()-start>10000:check(false,"startup");return
  await process_frame
 game.throw(1,0)
 while float(game.rock_probe("key",0))<=0:
  if Time.get_ticks_msec()-start>10000:check(false,"spawn");return
  await process_frame
 game.set_process(false)
 var key:int=int(game.rock_probe("key",0))
 var source:=Vector2(float(game.rock_probe("x",key)),float(game.rock_probe("y",key)))
 var velocity:=Vector2(float(game.rock_probe("vx",key)),float(game.rock_probe("vy",key)))
 var node:Node2D=game.rock_view(key)
 for fraction in [0.0,.25,.5,.75,1.0]:
  check(bool(game.rock_preview_only(fraction)),"painting preserves complete frame")
  check(node.position.is_equal_approx(source+velocity*fraction),"visual fraction")
  check(abs(float(game.rock_probe("center_x",key)))<.01 and abs(float(game.rock_probe("center_y",key)))<.01,"centered glyph")
 check(node.get_node("Glyph").modulate.is_equal_approx(Color(1,.9,.4,1)),"authored projectile color")
 var capture:=OS.get_environment("CAVE_FEEDBACK_CAPTURE")
 if not capture.is_empty():
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(capture)
 game.on_leave()
 check(game.rock_view(key)==null,"leave destroys projectile view")
 print("REPLAY_CAVE_FEEDBACK_VISUAL_OK rocks")
 if OS.has_feature("web"):JavaScriptBridge.eval("globalThis.caveFeedbackDone=true;0",true)
 else:quit(0)
