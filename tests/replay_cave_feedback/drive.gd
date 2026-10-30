extends SceneTree
var game:Node
func check(ok:bool,why:String):
 if not ok:push_error("CAVE_FEEDBACK_FAIL "+why);quit(1)
func p(key:String)->int:return int(game.feedback_probe(key))
func _initialize():
 game=load("res://cave.tscn").instantiate();root.add_child(game);call_deferred("run")
func run():
 var deadline:=Time.get_ticks_msec()+15000
 while p("ready")!=1:
  if Time.get_ticks_msec()>deadline:check(false,"startup");return
  await process_frame
 game.set_process(false)
 var tick:int=int(game.campaign_probe("clock",0))
 var stamp:String=str(game.campaign_hash(tick))
 check(stamp!="-1","valid simulation snapshot")
 game.feedback_inject(0,5,300.0,180.0) # Begin Died
 check(p("nodes")==1 and p("died")==1 and p("started")==1,"death burst begins")
 var node:Node2D=game.feedback_node()
 check(node.get_parent()==game.get_node("Stage") and node.position==Vector2(300,180),"detached position")
 var emitter:CPUParticles2D=node.get_node("Particles")
 check(emitter.amount==12 and is_equal_approx(emitter.lifetime,.4) and emitter.one_shot and emitter.emitting,"authored emitter")
 await create_timer(.08).timeout
 game.feedback_inject(3,5,300.0,180.0) # Confirm
 game.feedback_inject(0,5,300.0,180.0) # repeated Begin
 check(p("started")==1 and p("duplicates")==1,"confirmation and duplicate do not restart")
 game.feedback_inject(1,5,330.0,180.0) # Update
 check(node.position==Vector2(330,180) and p("started")==1,"correction moves existing burst")
 var capture:=OS.get_environment("CAVE_FEEDBACK_CAPTURE")
 if not capture.is_empty():
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(capture)
 game.feedback_inject(2,5,330.0,180.0) # Cancel
 check(p("nodes")==0 and not node.visible and p("canceled")==1,"cancellation hides immediately")
 game.feedback_inject(0,5,330.0,180.0)
 check(p("nodes")==0 and p("started")==1,"canceled ID stays consumed")
 var old_key:int=(1<<32)|1
 var old_body:Node2D=game.feedback_stage_dweller(old_key)
 game.feedback_dweller_inject(0,old_key)
 check(old_body.modulate.is_equal_approx(Color(1,.35,.35,1)),"dweller hit flash")
 var hit_started:int=p("started")
 game.feedback_dweller_inject(3,old_key)
 check(p("started")==hit_started,"dweller confirmation does not restart")
 game.feedback_dweller_inject(2,old_key)
 check(old_body.modulate.is_equal_approx(Color.WHITE),"dweller cancellation clears flash")
 var replacement:Node2D=game.feedback_stage_dweller((2<<32)|1)
 game.feedback_dweller_inject(0,old_key)
 check(replacement.modulate.is_equal_approx(Color.WHITE),"old generation cannot flash replacement")
 check(str(game.campaign_hash(tick))==stamp,"presentation leaves simulation unchanged")
 await process_frame
 game.on_leave()
 check(p("ready")==0 and p("nodes")==0,"leave clears feedback")
 print("REPLAY_CAVE_FEEDBACK_VISUAL_OK")
 if OS.has_feature("web"):JavaScriptBridge.eval("globalThis.caveFeedbackDone=true;0",true)
 else:quit(0)
