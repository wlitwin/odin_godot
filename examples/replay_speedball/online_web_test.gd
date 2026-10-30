extends Node
var game:Node
var last_command:=0
var last_result:Variant=null
var hash_tick:=0
var hash_value:="-1"
func _ready():
 if not OS.has_feature("web") or not bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('online_test')",true)):
  set_process(false);return
 game=get_parent()
func p(key:String,seat:int=1)->int:return int(game.probe(key,seat))
func r(key:String)->int:return int(game.recovery_probe(key))
func party(key:String)->int:return int(game.party_probe(key))
func _process(_dt:float):
 var request=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(globalThis.speedballCommand||null)",true)))
 if request is Dictionary and int(request.id)!=last_command:
  last_command=int(request.id);last_result=null
  match str(request.kind):
   "press":game.get_node(str(request.value)).pressed.emit()
   "name":game.get_node("UI/Lobby/Column/Name/Value").text=str(request.value)
   "invite":game.get_node("UI/Lobby/Column/Party/Code").text=str(request.value)
   "watch":game.get_node("UI/Lobby/Column/Party/Choices/Watch").button_pressed=bool(request.value)
   "bot":game.set_bot(str(request.value))
   "chat":game.on_chat(str(request.value))
   "handoff":last_result=game.handoff()
   "hash":hash_tick=int(request.value);hash_value=str(game.world_hash(hash_tick))
   "freeze":game.set_process(false)
   "slot":game.get_node("UI/Lobby/Column/Saved/Path").text=str(request.value)
   "save":last_result=game.on_save()
 var ready:=p("state_ready")==1
 var state={"command":last_command,"result":last_result,"failed":party("failed"),"recent":party("recent"),"profile_ready":party("profile_ready"),"profile_failed":party("profile_failed"),"profile_saved":party("profile_saved"),
  "profile_hash":str(game.profile_hash()),"name":game.get_node("UI/Lobby/Column/Name/Value").text,"invite":game.get_node("UI/Lobby/Column/Party/Code").text,
  "notice":game.get_node("UI/Lobby/Column/Notice").text,"chat":game.get_node("UI/Chat/Column/Lines").text,
  "invited":party("invited"),"incarnation":party("incarnation"),"separate":party("separate"),"observer":party("observer"),"backup":party("backup"),
  "ready":ready,"steady":r("steady"),"epoch":r("epoch"),"authority":r("authority"),"seat":p("seat") if ready else -1,
  "tick":p("tick") if ready else 0,"started":p("started") if ready else 0,"left":p("left") if ready else 0,"right":p("right") if ready else 0,"spikes":p("spikes") if ready else 0,
  "players":int(p("connected",1)==1)+int(p("connected",2)==1)+int(p("connected",3)==1)+int(p("connected",4)==1),
  "named":p("named",1)==1 and p("named",2)==1,"moving":r("moving_live"),"moving_backup":r("moving_backup"),"backup_committed":r("backup_committed"),"sequence":r("backup_sequence"),
  "exact":r("exact"),"restored_moving":r("moving"),"restored_score":r("restored_score"),"restored_spikes":r("restored_spikes"),"checkpoint":r("tick"),"lost":r("lost"),"interruption_ms":r("interruption"),
  "hash_tick":hash_tick,"hash":hash_value,
  "save_phase":int(game.browser_save_probe("phase")),"save_has":int(game.browser_save_probe("has")),"save_revision":int(game.browser_save_probe("revision")),"save_receipt":int(game.browser_save_probe("receipt")),"save_ok":int(game.browser_save_probe("success")),"save_error":int(game.browser_save_probe("error")),"store_error":int(game.browser_save_probe("store_error")),
  "saved_tick":int(game.save_probe("saved_tick")),"saved_hash":str(game.save_probe("saved_hash")),"restored_tick":int(game.save_probe("restored_tick")),"restored_hash":str(game.save_probe("restored_hash")),"restored_exact":int(game.save_probe("exact")),
  "save_notice":game.get_node("UI/SaveNotice").text,"resume_enabled":not game.get_node("UI/Lobby/Column/Resume/Solo").disabled,"save_enabled":not game.get_node("UI/Save").disabled,"winner":p("winner") if ready else 0,"round":p("round") if ready else 0}
 for key in ["save_completed","save_revision","save_tick","save_epoch","save_error","restore_error","restore_tick","restore_publication"]:state["party_"+key]=party(key)
 state["kicks"]=p("kicks") if ready else 0
 var layout_clear:=true
 var layout_conflicts:Array=[]
 for pair in [["UI/Save","UI/Handoff"],["UI/Save","UI/CopyInvite"],["UI/SaveNotice","UI/Recovery"],["UI/SaveNotice","UI/Again"]]:
  var a:Control=game.get_node(pair[0]);var b:Control=game.get_node(pair[1])
  if a.is_visible_in_tree() and b.is_visible_in_tree() and a.get_global_rect().intersects(b.get_global_rect()):
   layout_clear=false;layout_conflicts.append(str(pair)+" "+str(a.get_global_rect())+" "+str(b.get_global_rect()))
 state["party_layout_clear"]=layout_clear
 state["party_layout_conflicts"]=layout_conflicts
 JavaScriptBridge.eval("globalThis.speedballStatus="+JSON.stringify(state),true)
