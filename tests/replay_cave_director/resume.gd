extends SceneTree
var game:Node
var started:=0
var expected:Dictionary
func _initialize():
 expected=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("REPLAY_CAVE_SAVE")+".json"))
 game=load("res://cave.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
func _process(_dt:float)->bool:
 if game==null:return false
 if Time.get_ticks_msec()-started>10000:print("CAVE_DIRECTOR_RESUME_FAIL timeout");quit(1);return false
 if not game.probe_ready():return false
 if str(game.probe_restored_hash())!=str(expected.hash) or game.probe_restored_tick()!=int(expected.tick) or game.probe_epoch()!=2:
  print("CAVE_DIRECTOR_RESUME_FAIL exact checkpoint");quit(1);return false
 if game.probe_head()<=int(expected.tick)+3:return false
 print("CAVE_DIRECTOR_RESUME_OK tick=",expected.tick," head=",game.probe_head())
 game.queue_free();game=null;await process_frame;await process_frame;quit(0);return false
