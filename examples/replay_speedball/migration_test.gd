extends SceneTree
var game:Node
var member:=0
var mode:=""
var folder:=""
var phase:="join"
var started:=0
var armed:=false
var expected_spikes:=0
var capture_pending:=false
var captured:={}
var minimum_hash_tick:=0
var proposal_tick:=0
var proposals:=0
var answered_tick:=0
func capture(name:String):
 if OS.get_environment("RSB_MIGRATION_RENDER")!="1" or captured.has(name) or capture_pending:return
 capture_pending=true;captured[name]=true
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png(folder+"/"+str(member)+"-"+name+".png")==OK)
 capture_pending=false
func p(key:String,seat:int=1)->int:return int(game.probe(key,seat))
func r(key:String)->int:return int(game.recovery_probe(key))
func exists(name:String)->bool:return FileAccess.file_exists(folder+"/"+name+".json")
func put(name:String,value:Dictionary):
 var f:=FileAccess.open(folder+"/"+name+".json.pending",FileAccess.WRITE);f.store_string(JSON.stringify(value));f.close()
 assert(DirAccess.rename_absolute(folder+"/"+name+".json.pending",folder+"/"+name+".json")==OK)
func read(name:String)->Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(folder+"/"+name+".json"))
func fail(reason:String):
 print("SPEEDBALL_MIGRATION_FAIL member=",member," phase=",phase," ",reason," room=",r("phase")," epoch=",r("epoch")," score=",p("left"),"/",p("right")," backup=",r("backup_tick"))
 if exists("final"):print("RSB_FINAL_WAIT tick=",p("tick")," expected=",read("final").tick," hash=",game.world_hash(int(read("final").tick))," chat=",game.get_node("UI/Chat/Column/Lines").text)
 quit(1)
func _initialize():
 member=int(OS.get_environment("RSB_MEMBER"));mode=OS.get_environment("REPLAY_MIGRATION_MODE");folder=OS.get_environment("REPLAY_MIGRATION_DIR")
 game=load("res://speedball.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec();game.set_bot("idle")
func _process(_dt:float)->bool:
 if Time.get_ticks_msec()-started>75000:fail("timeout");return true
 match phase:
  "join":
   if r("steady") and p("connected",1) and p("connected",2) and p("connected",3) and p("named",1) and p("named",2) and p("named",3):
    if p("seat")!=member:fail("seat assignment");return true
    if member==2:game.set_bot("striker")
    phase="playing"
  "playing":
   capture("playing")
   if member==2 and r("moving_backup") and r("backup_committed") and not armed:
    put("moving-backup",{"sequence":r("backup_sequence"),"tick":r("backup_tick")});armed=true
   if member==1 and exists("moving-backup") and r("moving_live") and r("backup_sequence")>=read("moving-backup").sequence:
    put("trigger",{"tick":p("tick"),"score":p("left")+p("right"),"unix_ms":int(Time.get_unix_time_from_system()*1000)})
    if mode=="planned":
     var button:Button=game.get_node("UI/Handoff")
     if not button.visible or button.disabled:fail("handoff unavailable");return true
     button.pressed.emit()
    else:put("kill-owner",{"ready":true})
    phase="migrating"
   if r("epoch")==2:phase="migrating"
  "migrating":
   if r("steady")==0:
    if game.get_node("UI/Lobby").visible:fail("lobby obscures recovery");return true
    capture("recovering")
   if r("epoch")==2 and r("steady") and r("ready") and r("chat_epoch")==2:
    if p("seat")!=member:fail("seat changed");return true
    if r("kind")!=(1 if mode=="planned" else 2):fail("recovery policy");return true
    put("ready-"+str(member),{"epoch":r("epoch"),"tick":p("tick")})
    if member==2:
     if not r("authority") or not r("exact") or not r("moving"):fail("moving scored checkpoint");return true
     expected_spikes=r("restored_spikes")+2;game.set_bot("spiker")
     put("restored",{"checkpoint":r("tick"),"score":r("restored_score"),"spikes":r("restored_spikes")})
     phase="new-action"
    else:
     if r("authority"):fail("duplicate authority");return true
     if member==3:game.on_chat("after migration")
     phase="final"
  "new-action":
   if p("spikes")>=expected_spikes:
    game.set_bot("idle");phase="settle"
  "settle":
   if exists("ready-3") and (mode=="crash" or exists("ready-1")) and p("connected",3) and (mode=="crash" or p("connected",1)) and game.get_node("UI/Chat/Column/Lines").text.contains(post_migration_chat()) and p("tick")%3==0:
    if not recovered_ui():return false
    minimum_hash_tick=p("tick");phase="hash"
  "hash":
   var complete:=proposal_tick>0
   var retry:=proposal_tick==0
   var expected:Dictionary=read("proposal") if exists("proposal") else {}
   for peer in ([1,3] if require_old_host() else [3]):
    if not exists("hash-"+str(peer)):complete=false;continue
    var answer:=read("hash-"+str(peer))
    if int(answer.tick)!=proposal_tick:complete=false;continue
    if answer.hash=="-1":retry=true
    elif answer.hash!=expected.hash:fail("common world hash");return true
   if retry and (complete or proposal_tick==0):
    var tick:=p("tick")-30
    if tick>proposal_tick and tick>=minimum_hash_tick:
     proposals+=1
     if proposals>128:fail("no common retained snapshot");return true
     proposal_tick=tick;tick_record(tick)
   elif complete and not retry:
    expected["proposals"]=proposals;put("final",expected);phase="wait"
  "final":
   if exists("proposal"):
    var proposal:=read("proposal")
    if int(proposal.tick)!=answered_tick:
     answered_tick=int(proposal.tick)
     put("hash-"+str(member),{"tick":answered_tick,"hash":str(game.world_hash(answered_tick))})
   if exists("final"):
    var expected:=read("final");var digest:=int(game.world_hash(int(expected.tick)))
    if digest<0:return false
    if str(digest)!=expected.hash:fail("common world hash");return true
    if p("spikes")<int(expected.spikes):return false
    if not game.get_node("UI/Chat/Column/Lines").text.contains(post_migration_chat()):return false
    if not recovered_ui():return false
    put("done-"+str(member),{"tick":expected.tick,"hash":expected.hash,"epoch":r("epoch"),"checkpoint":r("tick"),"lost":r("lost"),"interruption_ms":r("interruption")})
    phase="quiesce"
  "wait":
   if exists("done-3") and (not require_old_host() or exists("done-1")):
    var final:=read("final")
    put("done-2",{"tick":final.tick,"hash":final.hash,"epoch":r("epoch"),"checkpoint":r("tick"),"lost":r("lost"),"interruption_ms":r("interruption"),"exact":bool(r("exact")),"moving":bool(r("moving"))});phase="quiesce"
  "quiesce":
   if exists("done-2") and not capture_pending:
    game.set_process(false);put("quiesced-"+str(member),{"ready":true});phase="close"
  "close":
   if exists("quiesced-2") and exists("quiesced-3") and (not require_old_host() or exists("quiesced-1")):
    print("REPLAY_SPEEDBALL_MIGRATION_PEER_OK member=",member," mode=",mode," checkpoint=",r("tick")," lost=",r("lost"))
    phase="closed";game.queue_free();finish.call_deferred()
 return false
func recovered_ui()->bool:
 var notice:Label=game.get_node("UI/Recovery")
 var handoff:Button=game.get_node("UI/Handoff")
 if not notice.visible or not notice.text.begins_with("Host changed"):fail("recovery notice");return false
 if handoff.visible!=(member==2):fail("handoff authority visibility");return false
 if not game.get_node("UI/Chat/Column/Lines").text.contains("The pitch has a new host"):return false
 capture("recovered")
 return true
func tick_record(tick:int):
 var digest:=int(game.world_hash(tick));assert(digest>=0)
 put("proposal",{"tick":tick,"hash":str(digest),"left":p("left"),"right":p("right"),"spikes":p("spikes")})
func finish():await process_frame;await process_frame;quit(0)

func post_migration_chat()->String:return "member-3: after migration"

func require_old_host()->bool:return mode=="planned"
