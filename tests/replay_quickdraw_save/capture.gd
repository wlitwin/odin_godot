extends SceneTree
var game:Node
func _initialize():run.call_deferred()
func frames(n:int):
 for _i in range(n):await process_frame
func capture(name:String):
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image();assert(image.save_png(OS.get_environment("RQ_CAPTURE_DIR")+"/"+name+".png")==OK);image=null
func run():
 root.size=Vector2i(640,360);game=load("res://quickdraw.tscn").instantiate();root.add_child(game);await frames(3)
 await capture("menu")
 game.on_resume_solo();assert(game.save_probe("exact")==1)
 await frames(3);await capture("resumed")
 game.queue_free();game=null;await frames(3);quit()
