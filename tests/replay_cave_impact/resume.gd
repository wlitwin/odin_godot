extends SceneTree
var game:Node
var started:=0
var phase:="boot"
func fail(why:String):print("IMPACT_RESUME_FAIL "+why);quit(1)
func _initialize():
 game=load("res://cave.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
func _process(_dt:float)->bool:
 if Time.get_ticks_msec()-started>15000:fail("timeout "+phase);return true
 if phase=="boot" and game.probe_ready():
  if int(game.probe_restored_tick())!=1 or str(game.probe_restored_hash())!=OS.get_environment("IMPACT_RESUME_HASH") or int(game.probe_epoch())!=2:fail("restored checkpoint");return true
  game.walk_to(300,180);phase="walk"
 elif phase=="walk" and game.probe_near(300,180):game.loot(0);phase="loot"
 elif phase=="loot" and int(game.probe_bag())==3:
  if int(game.feedback_probe("dweller_hits"))<1:fail("restored rock did not emit impact");return true
  if int(game.probe_gems())!=3:fail("inventory");return true
  print("REPLAY_CAVE_IMPACT_RESUME_OK");quit(0);return true
 return false
