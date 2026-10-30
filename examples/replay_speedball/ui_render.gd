extends SceneTree
var game:Node
var folder:=""
func _initialize():folder=OS.get_environment("RSB_RENDER_DIR");run.call_deferred()
func capture(name:String):
 await RenderingServer.frame_post_draw
 var img:=root.get_texture().get_image();assert(img.save_png(folder+"/"+name+".png")==OK)
func key(code:Key,pressed:bool):
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func run():
 game=load("res://speedball.tscn").instantiate();root.add_child(game)
 for _i in 12:await process_frame
 await capture("menu")
 game.get_node("UI/Lobby/Column/Buttons/Solo").grab_focus()
 key(KEY_SPACE,true);await process_frame;key(KEY_SPACE,false)
 var until:=Time.get_ticks_msec()+5000
 while game.probe("started",1)!=1 and Time.get_ticks_msec()<until:await process_frame
 assert(game.probe("started",1)==1)
 for _i in 20:await process_frame
 await capture("solo")
 key(KEY_TAB,true)
 for _i in 3:await process_frame
 assert(game.get_node("UI/Scoreboard").visible)
 await capture("scores")
 key(KEY_TAB,false)
 for _i in 3:await process_frame
 assert(not game.get_node("UI/Scoreboard").visible)
 print("REPLAY_SPEEDBALL_RENDER_OK")
 game.set_process(false);game.queue_free();await process_frame;await process_frame;quit(0)
