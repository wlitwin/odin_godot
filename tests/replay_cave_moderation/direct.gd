extends SceneTree
var game:Node
var role:=OS.get_environment("MODERATION_ROLE")
var folder:=OS.get_environment("MODERATION_DIR")
func mark(name:String):
 var f:=FileAccess.open(folder.path_join(name),FileAccess.WRITE);f.store_string("ready");f.close()
func exists(name:String)->bool:return FileAccess.file_exists(folder.path_join(name))
func check(ok:bool,why:String)->bool:
 if not ok:push_error("CAVE_MODERATION_FAIL "+why);quit(1)
 return ok
func until(test:Callable,label:String,seconds:=15)->bool:
 var start:=Time.get_ticks_msec()
 while not test.call():
  if not check(Time.get_ticks_msec()-start<seconds*1000,label):return false
  await process_frame
 return true
func _initialize():
 game=load("res://cave.tscn").instantiate();root.add_child(game);call_deferred("run")
func run():
 if role=="banned":
  if not await until(func():return game.get_node("Lobby/Panel/Column/Status").text.contains("removed"),"banned rejoin"):return
  check(not game.probe_ready(),"banned peer cannot play")
  mark("banned");print("CAVE_MODERATION_BANNED_OK");quit(0);return
 if not await until(func():return game.probe_ready() and int(game.probe_players())==2,"admission"):return
 if role=="client":
  game.on_name_submit("Renamed guest")
  game.kick(1) # unprivileged method call must not affect host
  mark("guest-attempt")
  if not await until(func():return game.get_node("Lobby/Panel/Column/Status").text.contains("removed"),"removal notice"):return
  check(not game.probe_ready(),"removed game closes")
  mark("removed");print("CAVE_MODERATION_REMOVED_OK");quit(0);return
 if not await until(func():return exists("guest-attempt"),"guest check"):return
 check(int(game.probe_players())==2,"guest could not remove host")
 var list:OptionButton=game.get_node("Lobby/Panel/Column/Moderation/Players")
 if not await until(func():return list.item_count==1,"roster control"):return
 check(list.get_item_id(0)==2,"only remote player is selectable")
 if not await until(func():return list.get_item_text(0).contains("Renamed guest"),"selector follows authoritative names"):return
 if OS.get_environment("MODERATION_RENDERED")=="1":
  Input.action_press("ui_cancel");await process_frame;await process_frame;Input.action_release("ui_cancel")
  await process_frame
  var control:Control=game.get_node("Lobby/Panel/Column/Moderation/Remove")
  check(control.is_visible_in_tree(),"moderation shown through Escape")
  var rect:Rect2=control.get_global_rect()
  check(root.get_visible_rect().encloses(rect),"remove control fits viewport")
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(folder.path_join("moderation.png"))
 game.get_node("Lobby/Panel/Column/Moderation/Remove").emit_signal("pressed")
 if not await until(func():return int(game.probe_players())==1 and exists("removed"),"roster shrinks"):return
 mark("host-removed")
 if not await until(func():return exists("banned"),"fresh process denied"):return
 print("CAVE_MODERATION_HOST_OK");quit(0)
