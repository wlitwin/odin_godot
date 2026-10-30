extends SceneTree
var game:Node
func _initialize():run.call_deferred()
func frames(n:int):
 for _i in range(n):await process_frame
func capture(name:String):
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image();assert(image.save_png(OS.get_environment("RCB_CAPTURE_DIR")+"/"+name+".png")==OK);image=null
func run():
 root.size=Vector2i(640,360);game=load("res://claimball.tscn").instantiate();root.add_child(game);await frames(3)
 for path in ["UI/Lobby/Column/Name","UI/Lobby/Column/Address","UI/Lobby/Column/Buttons","UI/Lobby/Column/Saved","UI/Lobby/Column/Resume","UI/Lobby/Column/Notice"]:
  var control:Control=game.get_node(path);var rect:=control.get_global_rect()
  assert(control.is_visible_in_tree() and rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=640 and rect.end.y<=332,path)
 await capture("menu")
 game.on_resume_solo();assert(game.save_probe("exact")==1)
 await frames(3);await capture("resumed")
 print("REPLAY_CLAIMBALL_SAVE_RENDER_OK")
 game.queue_free();game=null;await frames(3);quit()
