extends Node
var game:Node
var command:=0
var result:Variant=null
var hash_tick:=0
var hash_value:="-1"
var leave_blocked:=false
func _ready():
 if not OS.has_feature("web") or not bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('online_test')",true)):set_process(false);return
 game=get_parent()
func p(key:String,seat:int=1)->int:return int(game.probe(key,seat))
func ui(key:String,seat:int=1)->int:return int(game.ui_probe(key,seat))
func party(key:String)->int:return int(game.party_probe(key))
func _process(_dt:float):
 var request=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(globalThis.quickdrawCommand||null)",true)))
 if request is Dictionary and int(request.id)!=command:
  command=int(request.id);result=null
  match str(request.kind):
   "press":game.get_node(str(request.value)).pressed.emit()
   "name":game.get_node("UI/Lobby/Column/Name/Value").text=str(request.value)
   "invite":game.get_node("UI/Lobby/Column/Party/Code").text=str(request.value)
   "watch":game.get_node("UI/Lobby/Column/Party/Choices/Watch").button_pressed=bool(request.value)
   "drive":game.drive(int(request.value[0]),int(request.value[1]),int(request.value[2]),int(request.value[3]),int(request.value[4]))
   "buy":result=game.purchase()
   "chat":game.on_chat(str(request.value))
   "handoff":result=game.handoff()
   "hash":hash_tick=int(request.value);hash_value=str(game.probe_hash(hash_tick))
   "slot":game.get_node("UI/Lobby/Column/Saved/Path").text=str(request.value)
   "save":result=game.on_save()
   "save_leave":
    result=game.on_save();game.on_leave();leave_blocked=ui("ready")==1 and game.browser_save_probe("phase")==3
   "freeze":game.set_process(false)
 var ready:=ui("state_ready")==1
 var roster:=str(game.get_node("UI/Lobby/Column/Roster").text)
 var state:={"command":command,"result":result,"failed":party("failed"),"recent":party("recent"),"profile_ready":party("profile_ready"),"profile_failed":party("profile_failed"),"profile_saved":party("profile_saved"),"profile_hash":str(game.profile_hash()),"name":str(game.get_node("UI/Lobby/Column/Name/Value").text),"invite":str(game.get_node("UI/Lobby/Column/Party/Code").text),"notice":str(game.get_node("UI/Lobby/Column/Notice").text),"chat":str(game.get_node("UI/Chat/Column/Lines").text),"named":roster.contains("Marshal") and roster.contains("Deputy") and roster.contains("Rider"),"invited":party("invited"),"member":party("member"),"incarnation":party("incarnation"),"separate":party("separate"),"observer":party("observer"),"backup":party("backup"),"ready":ready,"steady":p("steady"),"epoch":p("epoch"),"authority":p("authority"),"seat":p("seat") if ready else -1,"tick":p("head") if ready else 0,"started":ui("started") if ready else 0,"players":p("players"),"hp2":p("hp",2),"life2":p("life",2),"boots3":p("boots",3),"hits":p("hits"),"lobs":p("lobs"),"bullets":p("bullets"),"buys":p("buys"),"combat_backup":p("combat_backup"),"backup_sequence":p("backup_sequence"),"restored_exact":p("restored_exact"),"restored_combat":p("restored_combat"),"restored_hits":p("restored_hits"),"restored_lobs":p("restored_lobs"),"restored_life":p("restored_life"),"checkpoint":p("recovery_tick"),"lost":p("lost_ticks"),"hash_tick":hash_tick,"hash":hash_value,"observer_named":ui("named_observer"),"lobby_visible":game.get_node("UI/Lobby").visible}
 state["leave_blocked"]=leave_blocked
 state["boots1"]=p("boots",1);state["fire_cd"]=int(game.save_probe("fire_cd"));state["x"]=ui("x",1);state["y"]=ui("y",1)
 state["saved_tick"]=int(game.save_probe("saved_tick"));state["saved_hash"]=str(game.save_probe("saved_hash"))
 state["restored_tick"]=int(game.save_probe("restored_tick"));state["restored_hash"]=str(game.save_probe("restored_hash"));state["exact"]=int(game.save_probe("exact"))
 state["save_notice"]=str(game.get_node("UI/SaveNotice").text)
 state["recovery_notice"]=str(game.get_node("UI/Recovery").text)
 state["resume_enabled"]=not game.get_node("UI/Lobby/Column/Resume/Solo").disabled
 for key in ["phase","has","revision","receipt","success","error","store_error"]:state["slot_"+key]=int(game.browser_save_probe(key))
 for key in ["save_completed","save_revision","save_tick","save_epoch","save_error","restore_error","restore_tick","restore_publication"]:state["party_"+key]=party(key)
 var clear_layout:=true
 var handoff:Control=game.get_node("UI/Handoff")
 for path in ["Status","UI/Save","UI/CopyInvite","UI/SaveNotice"]:
  var control:Control=game.get_node(path)
  if handoff.is_visible_in_tree() and control.is_visible_in_tree() and handoff.get_global_rect().intersects(control.get_global_rect()):clear_layout=false
 state["recovery_layout_clear"]=clear_layout
 JavaScriptBridge.eval("globalThis.quickdrawStatus="+JSON.stringify(state),true)
