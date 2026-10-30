extends SceneTree
var game:Node
func _initialize():run.call_deferred()
func frames(n:int):
 for _i in range(n):await process_frame
func send(event:InputEvent):
 Input.parse_input_event(event)
func tap(code:Key,unicode:int=0):
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.unicode=unicode;event.pressed=true;send(event)
 await frames(2)
 event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=false;send(event);await frames(2)
func finish(code:int,why:String):
 print("CAVE_NAME_INPUT_", "OK" if code==0 else "FAIL", " ",why)
 game.queue_free();game=null;await frames(3);quit(code)
func run():
 game=load("res://cave.tscn").instantiate();root.add_child(game)
 for _i in range(180):
  if game.probe_ready() and game.lobby_name(1)=="Keyboard":break
  await process_frame
 if not game.probe_ready() or game.lobby_name(1)!="Keyboard":await finish(1,"ready");return
 var name:LineEdit=game.get_node("Lobby/Panel/Column/Name")
 var chat:LineEdit=game.get_node("Social/Chat/Input")
 name.grab_focus();name.text=""
 await tap(KEY_F,102);await frames(5)
 if name.text!="f" or game.social_probe("marks")!=0 or not name.has_focus():await finish(1,"typing F text=%s marks=%d focus=%s"%[name.text,game.social_probe("marks"),name.has_focus()]);return
 name.text="";await tap(KEY_ENTER);await frames(4)
 if game.lobby_name(1)!="Keyboard" or not name.has_focus() or chat.has_focus():await finish(1,"invalid name submission changed state/focus");return
 name.text="New [Name]";await tap(KEY_ENTER)
 for _i in range(90):
  if game.lobby_name(1)=="New [Name]":break
  await process_frame
 if game.lobby_name(1)!="New [Name]" or name.has_focus() or chat.has_focus() or game.social_probe("marks")!=0:await finish(1,"valid submission/focus guard name=%s name_focus=%s chat_focus=%s marks=%d"%[game.lobby_name(1),name.has_focus(),chat.has_focus(),game.social_probe("marks")]);return
 await finish(0,"F capture and valid/invalid Enter handling")
