extends SceneTree
var game:Node
func _initialize():run.call_deferred()
func frames(n:int):
 for _i in range(n):await process_frame
func run():
 game=load("res://slopball3d.tscn").instantiate();root.add_child(game);await frames(3)
 var field:LineEdit=game.get_node("UI/Lobby/Column/Name/Value")
 var mode:=OS.get_environment("RS3_PROFILE_TEST")
 if mode=="write":field.text="Stetson Ω"
 elif mode=="read":
  if field.text!="Stetson Ω":print("RS3_PROFILE_FAIL saved name");quit(1);return
 game.on_solo();await frames(10)
 if mode=="corrupt":
  if game.ui_probe("ready",1)!=0 or not "saved name" in str(game.get_node("UI/Lobby/Column/Notice").text):print("RS3_PROFILE_FAIL corruption");quit(1);return
 elif game.ui_probe("ready",1)!=1:print("RS3_PROFILE_FAIL connect");quit(1);return
 print("RS3_PROFILE_OK ",mode);game.queue_free();game=null;await frames(3);quit()
