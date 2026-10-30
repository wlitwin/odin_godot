extends Node
var game:Node
var phase:="join"
var world_tick:=0
var started:=0
var closing:=false
func _ready():
 game=load("res://main.tscn").instantiate();add_child(game);started=Time.get_ticks_msec()
func p(name:String)->int:return int(game.probe(name,1))
func _process(_dt:float):
 if closing:return
 if bool(JavaScriptBridge.eval("globalThis.recordingClose||false",true)):
  closing=true;game.queue_free();game=null
  await get_tree().process_frame;await get_tree().process_frame
  JavaScriptBridge.eval("globalThis.recordingClosed=true;0",true);return
 if Time.get_ticks_msec()-started>30000:JavaScriptBridge.eval("globalThis.recordingFailure='timeout';0",true);return
 if not p("ready"):return
 JavaScriptBridge.eval("globalThis.recordingProgress="+JSON.stringify({"phase":phase,"head":p("head"),"world_tick":world_tick,"shots":p("shots"),"casts":p("casts"),"cd0":p("cd0"),"cd1":p("cd1"),"dev_result":p("dev_result"),"dev_reason":p("dev_reason")})+";0",true)
 match phase:
  "join":game.dev_loadout(0,0);game.dev_abilities(1,5);phase="loadout"
  "loadout":
   if p("iron")==0 and p("ability0")==1 and p("ability1")==5:game.on_ready();phase="ready"
  "ready":
   if p("marked_ready"):game.on_start();phase="world"
  "world":
   if p("in_yard"):
    world_tick=p("head");game.dev_aim(1,0,true)
    var cast0:bool=game.dev_cast(0,800,1040,true)
    var cast1:bool=game.dev_cast(1,1,0,false)
    var grant:int=game.dev_grant_scrap(1,100)
    if not cast0 or not cast1 or grant<=0:JavaScriptBridge.eval("globalThis.recordingFailure='submission';0",true);return
    phase="combat"
  "combat":
   if p("head")-world_tick>=75 and p("shots")>=3 and p("casts")>=2:
    game.on_menu();phase="export"
  "export":
   var button=game.find_child("ReplayRecordingExport",true,false)
   game.get_node("UI/Menu/Scroll").ensure_control_visible(button)
   var rect:Rect2=button.get_viewport().get_screen_transform()*button.get_global_rect()
   var size:=get_tree().root.size
   var state:={"phase":phase,"head":p("head"),"shots":p("shots"),"casts":p("casts"),"mobs":p("mobs"),"button":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"text":button.text,"width":size.x,"height":size.y}
   JavaScriptBridge.eval("globalThis.recordingState="+JSON.stringify(state)+";0",true)
