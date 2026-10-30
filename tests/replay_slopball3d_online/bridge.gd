extends Node
var game:Node
var command:=0
var result:Variant=null
var leave_blocked:=false
var hash_tick:=0
var hash_value:="-1"
func _ready():
 if not OS.has_feature("web") or not bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('online_test')",true)):set_process(false);return
 game=get_parent()
func p(key:String,seat:int=1)->int:return int(game.ui_probe(key,seat))
func r(key:String)->int:return int(game.probe(key))
func party(key:String)->int:return int(game.party_probe(key))
func _process(_dt:float):
 var request=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(globalThis.slopball3dCommand||null)",true)))
 if request is Dictionary and int(request.id)!=command:
  command=int(request.id);result=null
  match str(request.kind):
   "press":game.get_node(str(request.value)).pressed.emit()
   "name":game.get_node("UI/Lobby/Column/Name/Value").text=str(request.value)
   "invite":game.get_node("UI/Lobby/Column/Party/Code").text=str(request.value)
   "watch":game.get_node("UI/Lobby/Column/Party/Choices/Watch").button_pressed=bool(request.value)
   "bot":game.set_bot(str(request.value))
   "chat":game.on_chat(str(request.value))
   "handoff":result=game.handoff()
   "hash":hash_tick=int(request.value);hash_value=str(game.probe_hash(hash_tick))
   "slot":game.get_node("UI/Lobby/Column/Saved/Path").text=str(request.value)
   "save":result=game.on_save()
   "save_leave":
    result=game.on_save();game.on_leave();leave_blocked=p("ready")==1 and game.browser_save_probe("phase")==3
   "freeze":game.set_process(false);game.set_physics_process(false)
 var ready:=p("state_ready")==1
 var state={"command":command,"result":result,"ready":ready,"failed":party("failed"),"recent":party("recent"),"profile_ready":party("profile_ready"),"profile_failed":party("profile_failed"),"profile_saved":party("profile_saved"),"profile_hash":str(game.profile_hash()),"name":game.get_node("UI/Lobby/Column/Name/Value").text,"invite":game.get_node("UI/Lobby/Column/Party/Code").text,"notice":game.get_node("UI/Lobby/Column/Notice").text,"chat":game.get_node("UI/Chat/Column/Lines").text,
  "member":party("member"),"incarnation":party("incarnation"),"invited":party("invited"),"separate":party("separate"),"observer":party("observer"),"backup":party("backup"),"steady":r("steady"),"epoch":r("epoch"),"authority":r("authority"),"seat":p("seat") if ready else -1,"tick":r("head"),"players":p("players"),"named":p("named",1)==1 and p("named",2)==1 and p("named",3)==1,"started":p("started") if ready else 0,"left":p("left") if ready else 0,"right":p("right") if ready else 0,"winner":p("winner") if ready else 0,"round":p("round") if ready else 0,
  "owner":r("owner"),"body_epoch":r("body_epoch"),"body_revision":r("body_revision"),"body_sequence":r("body_sequence"),"ball_solver":p("ball_solver"),"kicks":r("kicks"),"goals":r("goals"),"moving":r("moving"),"moving_backup":r("moving_backup"),"complete_backup":r("complete_backup"),"backup_tick":r("backup_tick"),"prepared_tick":r("prepared_tick"),"exact":r("restored_exact"),"restored_moving":r("restored_moving"),"restored_goals":r("restored_goals"),"restored_right":r("restored_right"),"seeded":r("seeded"),"checkpoint":r("recovery_tick"),"lost":r("lost_ticks"),"observer_named":p("named_observer"),"lobby_visible":game.get_node("UI/Lobby").visible,"hash_tick":hash_tick,"hash":hash_value,"save_notice":game.get_node("UI/SaveNotice").text,"recovery_notice":game.get_node("UI/Recovery").text,"seed":JSON.parse_string(str(game.recovery_pose("seed"))),"live_pose":JSON.parse_string(str(game.recovery_pose("live"))),"restored_pose":JSON.parse_string(str(game.recovery_pose("restored"))),"spinning_backup":r("spinning_backup"),"publication_moving":int(game.save_probe("moving"))}
 for key in ["save_completed","save_revision","save_tick","save_epoch","save_error","restore_error","restore_tick","restore_publication"]:state["party_"+key]=party(key)
 for key in ["phase","has","revision","receipt","success","error","store_error"]:state["slot_"+key]=int(game.browser_save_probe(key))
 for key in ["saved_tick","restored_tick","exact","seeded"]:state["local_"+key]=int(game.save_probe(key))
 state["saved_hash"]=str(game.save_probe("saved_hash"));state["restored_hash"]=str(game.save_probe("restored_hash"))
 state["saved_pose"]=JSON.parse_string(str(game.save_pose("saved")));state["local_seed"]=JSON.parse_string(str(game.save_pose("seed")))
 state["resume_enabled"]=not game.get_node("UI/Lobby/Column/Resume/Solo").disabled
 state["save_enabled"]=not game.get_node("UI/Save").disabled;state["leave_blocked"]=leave_blocked
 var clear:=true
 for pair in [["UI/Save","UI/Handoff"],["UI/Save","UI/Recovery"],["UI/Save","UI/CopyInvite"],["UI/SaveNotice","UI/Recovery"],["UI/SaveNotice","UI/Again"]]:
  var a:Control=game.get_node(pair[0]);var b:Control=game.get_node(pair[1])
  if a.is_visible_in_tree() and b.is_visible_in_tree() and a.get_global_rect().intersects(b.get_global_rect()):clear=false
 state["layout_clear"]=clear
 JavaScriptBridge.eval("globalThis.slopball3dStatus="+JSON.stringify(state),true)
