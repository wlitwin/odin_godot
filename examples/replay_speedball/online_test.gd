extends "res://migration_test.gd"
var role:=""
var returned:=false
var observer_rejoined:=false
var observer_incarnation:=0
func party(key:String)->int:return int(game.party_probe(key))
func press(path:String):game.get_node(path).pressed.emit()
func party_code()->LineEdit:return game.get_node("UI/Lobby/Column/Party/Code")
func _initialize():
 role=OS.get_environment("RSB_PARTY_ROLE");mode=OS.get_environment("RSB_PARTY_MODE");folder=OS.get_environment("RSB_PARTY_DIR")
 member={"host":1,"guest":2,"watcher":3,"returned":1}[role]
 returned=role=="returned";phase="menu";started=Time.get_ticks_msec()
 game=load("res://speedball.tscn").instantiate();root.add_child(game);game.set_bot("idle")
func _process(dt:float)->bool:
 if phase=="closed":return false
 if Time.get_ticks_msec()-started>100000:fail("party timeout");return true
 if party("failed"):fail(game.get_node("UI/Lobby/Column/Notice").text);return true
 if phase=="settle":
  if exists("ready-1") and exists("ready-3") and p("connected",1) and game.get_node("UI/Chat/Column/Lines").text.contains(post_migration_chat()) and recovered_ui():
   minimum_hash_tick=p("tick");phase="hash"
  return false
 if phase in ["new-action","hash","final","wait","quiesce","close","closed"]:
  # The final trio is the promoted guest, the true observer and a fresh returned host.
  return super._process(dt)
 match phase:
  "menu":
   if party("recent")!=1:return false
   capture("party-menu")
   if capture_pending:return false
   game.get_node("UI/Lobby/Column/Name/Value").text={"host":"Captain","returned":"Captain","guest":"Striker","watcher":"Spectator"}[role]
   if role=="host":press("UI/Lobby/Column/Buttons/Host");phase="invite"
   elif returned:
    if game.get_node("UI/Lobby/Column/Party/Choices/Rejoin").disabled:fail("recent credential unavailable");return true
    press("UI/Lobby/Column/Party/Choices/Rejoin");phase="returning"
   elif exists("invite") and (role!="watcher" or exists("guest-admitted")):
    # Invalid pasted codes must leave the menu usable before the valid invitation.
    party_code().text="invalid";press("UI/Lobby/Column/Buttons/Join")
    if p("ready"):fail("invalid invitation opened session");return true
    party_code().text=read("invite").code
    game.get_node("UI/Lobby/Column/Party/Choices/Watch").button_pressed=role=="watcher"
    press("UI/Lobby/Column/Buttons/Join");game.on_solo()
    if p("ready"):fail("competing local start during enrollment");return true
    phase="joined"
  "invite":
   if party("invited") and r("steady"):
    if not party_code().text.begins_with("RP1."):fail("invitation absent");return true
    put("invite",{"code":party_code().text});phase="joined"
  "joined":
   if not r("steady") or not p("chat_ready"):return false
   if not party("separate"):fail("room replaced personal identity");return true
   if role=="guest":put("guest-admitted",{"ready":true})
   if role=="watcher":
    if p("seat")!=0 or not party("observer") or party("backup"):fail("observer received player role or backups");return true
   elif p("seat")!=member:fail("player seat");return true
   if p("connected",1) and p("connected",2) and p("named",1) and p("named",2):
    put("joined-"+str(member),{"ready":true,"incarnation":party("incarnation")});phase="start"
  "start":
   if not exists("joined-1") or not exists("joined-2") or not exists("joined-3"):return false
   if member==1:press("UI/Lobby/Column/Start");game.set_bot("striker")
   phase="playing"
  "playing":
   if p("started")==1 and not game.get_node("UI/Lobby").visible:capture("party-playing")
   if member==2 and r("moving_backup") and r("backup_committed") and not armed:
    put("moving-backup",{"sequence":r("backup_sequence"),"tick":r("backup_tick")});armed=true
   if member==1 and exists("moving-backup") and r("moving_live") and r("backup_sequence")>=int(read("moving-backup").sequence):
    put("trigger",{"tick":p("tick"),"score":p("left")+p("right")})
    if mode=="planned":press("UI/Handoff")
    else:put("kill-owner",{"ready":true})
    phase="migrating"
   if r("epoch")==2:phase="migrating"
  "migrating":
   if r("epoch")!=2 or not r("steady") or not r("ready"):return false
   if member==1:
    put("retired",{"epoch":2});game.set_process(false);game.queue_free();finish.call_deferred();phase="closed"
   elif member==2:
    if not r("authority") or not r("exact") or not r("moving"):fail("checkpoint recovery");return true
    expected_spikes=r("restored_spikes")+2
    put("restored",{"checkpoint":r("tick"),"score":r("restored_score"),"spikes":r("restored_spikes")})
    phase="wait-return"
   else:
    if p("seat")!=0 or not party("observer") or r("authority") or party("backup"):fail("observer changed on migration");return true
    observer_incarnation=party("incarnation")
    press("UI/Leave")
    if p("ready") or not game.get_node("UI/Lobby").visible:fail("observer leave");return true
    press("UI/Lobby/Column/Party/Choices/Rejoin");phase="observer-returning"
  "observer-returning":
   if r("epoch")!=2 or not r("steady") or not p("chat_ready"):return false
   if p("seat")!=0 or not party("observer") or party("backup") or party("incarnation")<=observer_incarnation:fail("observer rejoin mode");return true
   observer_rejoined=true
   put("observer-rejoined",{"seat":0,"incarnation":party("incarnation"),"backup":false})
   put("ready-3",{"epoch":2});phase="wait-return"
  "returning":
   if r("epoch")!=2 or not r("steady") or not p("chat_ready"):return false
   if p("seat")!=1 or party("incarnation")<int(read("joined-1").incarnation)+1:fail("fresh incarnation and same seat");return true
   if not party("invited") or party_code().text!=read("invite").code:fail("invite changed across rejoin");return true
   if not party("separate"):fail("personal identity replaced");return true
   put("ready-1",{"epoch":2,"incarnation":party("incarnation"),"same_invite":true});phase="final"
  "wait-return":
   if not exists("ready-1") or not exists("ready-3"):return false
   if member==2:game.set_bot("spiker");phase="new-action"
   else:game.on_chat("after migration");phase="final"
 return false
# Parent checks used numeric fixture names. This party uses a named true observer.
func recovered_ui()->bool:
 var notice:Label=game.get_node("UI/Recovery")
 if not notice.visible or (not returned and not observer_rejoined and not notice.text.begins_with("Host changed")):fail("party recovery notice");return false
 if game.get_node("UI/Handoff").visible!=(member==2):fail("authority control");return false
 if not game.get_node("UI/Chat/Column/Lines").text.contains("The pitch has a new host"):return false
 return true

func post_migration_chat()->String:return "Observer: after migration"

func require_old_host()->bool:return true
func fail(reason:String):
 print("RSB_PARTY_CHAT ",game.get_node("UI/Chat/Column/Lines").text)
 super.fail(reason)
