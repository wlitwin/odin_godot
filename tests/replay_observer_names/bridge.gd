extends Node
var game:Node
var handled:=0
var queried:=0
func _ready():
 if not OS.has_feature("web"):set_process(false);return
 game=get_parent();JavaScriptBridge.eval("globalThis.observerState=null;0",true)
func _process(_dt):
 var raw=str(JavaScriptBridge.eval("JSON.stringify(globalThis.observerCommand||null)",true))
 if raw!="null":
  var command:Dictionary=JSON.parse_string(raw)
  if int(command.id)>handled:
   var accepted:=true
   match str(command.kind):
    "ready":game.on_ready()
    "start":game.on_start()
    "say":game.on_chat(str(command.text))
    "rename":game.get_node("UI/Lobby/Scroll/Layout/Name").text=str(command.text)
    "ping":accepted=game.ping(500.0,500.0)
    "handoff":accepted=game.handoff()
    _:accepted=false
   handled=int(command.id);JavaScriptBridge.eval("globalThis.observerAck="+JSON.stringify({"id":handled,"accepted":accepted})+";0",true)
 var query=int(JavaScriptBridge.eval("globalThis.observerQuery||0",true))
 if query>queried:
  queried=query
  var state={"query":query,"status":game.get_node("UI/Status").text,"history":game.get_node("UI/Chat/Lines").text,"chat_ready":game.chat_probe("ready"),"named_observer":game.chat_probe("named_observer"),"pending":game.chat_probe("pending"),"name":game.get_node("UI/Lobby/Scroll/Layout/Name").text}
  for key in ["ready","seat","epoch","authority","players","head","stage","restored_exact","recovery_ready"]:state[key]=game.probe(key,1)
  state["ready2"]=game.probe("marked_ready",2)
  JavaScriptBridge.eval("globalThis.observerState="+JSON.stringify(state)+";0",true)
