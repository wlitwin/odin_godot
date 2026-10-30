extends SceneTree
var game:Node
var closing:=false
var started:=0
func _initialize():
	game=load("res://cave.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
func done(code:int):
	closing=true;game.queue_free();game=null;await process_frame;await process_frame;quit(code)
func _process(_dt:float)->bool:
	if closing:return false
	if Time.get_ticks_msec()-started>5000:print("CAVE_LOBBY_PROFILE_FAIL timeout");done(1);return false
	if game.lobby_probe("profile_ready",0)!=1:return false
	var expected:=OS.get_environment("REPLAY_EXPECT_NAME")
	if game.get_node("Lobby/Panel/Column/Name").text!=expected:print("CAVE_LOBBY_PROFILE_FAIL name");done(1);return false
	if game.lobby_probe("profile_error",0)!=int(OS.get_environment("REPLAY_EXPECT_ERROR")):print("CAVE_LOBBY_PROFILE_FAIL error");done(1);return false
	print("REPLAY_CAVE_LOBBY_PROFILE_OK name=",expected);done(0);return false
