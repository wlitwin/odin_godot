extends SceneTree
var game:Node
var phase:="boot"
var started:=0
var rejected_at_start:=0
func _initialize():
 game=load("res://cave.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
func _process(_dt:float)->bool:
 if Time.get_ticks_msec()-started>15000:print("OWNER_UPGRADE_RESUME_FAIL timeout ",phase);quit(1);return true
 if phase=="boot" and game.probe_ready():
  if game.probe_restored_tick()!=1 or str(game.probe_restored_hash())!=OS.get_environment("OWNER_UPGRADE_HASH") or game.probe_epoch()!=2 or game.probe_door() or game.probe_bag()!=0:
   print("OWNER_UPGRADE_RESUME_FAIL restored state");quit(1);return true
  rejected_at_start=int(game.campaign_probe("rejected",0))
  game.door();game.door()
  game.walk_to(300,180);phase="walk"
 elif phase=="walk" and game.probe_near(300,180):game.loot(0);phase="loot"
 elif phase=="loot" and game.probe_bag()==3:
  if int(game.campaign_probe("rejected",0))<rejected_at_start+2:print("OWNER_UPGRADE_RESUME_FAIL pending intents lost");quit(1);return true
  if game.probe_gems()!=3:print("OWNER_UPGRADE_RESUME_FAIL inventory");quit(1);return true
  print("REPLAY_CAVE_OWNER_UPGRADE_RESUME_OK");quit(0);return true
 return false
