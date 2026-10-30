extends Node
var game:Node
var transitions:=[]
var previous:={}
func _ready():
 if not OS.has_feature("web"):set_process(false);return
 game=get_parent()
func _process(_dt:float):
 if bool(JavaScriptBridge.eval("globalThis.caveSocialShowScore||false",true)):
  game.show_score(true);JavaScriptBridge.eval("globalThis.caveSocialShowScore=false;0",true)
 var epoch:=int(game.probe_epoch())
 var rows:=[]
 for seat in range(1,4):
  var label:Label=game.get_node("Social/Scoreboard/Column/Grid/Row%d_7"%[seat-1])
  rows.append({"text":label.text,"visible":label.visible,"known":int(game.social_metrics("known",seat)),"ms":int(game.social_metrics("ms",seat))})
 var marks:=[]
 for label in game.find_children("CavePingName","Label",true,false):
  if not label.get_parent().is_queued_for_deletion():marks.append(str(label.text))
 var state:={"epoch":epoch,"scope":int(game.social_metrics("epoch",0)),"enabled":int(game.social_metrics("enabled",0)),"steady":bool(game.probe_steady()),"rows":rows,"marks":marks,"mark_ttl":int(game.social_metrics("mark_ttl",0)),"at":Time.get_ticks_msec()}
 if not previous.is_empty() and epoch!=int(previous.epoch):transitions.append({"before":previous,"after":state})
 previous=state
 JavaScriptBridge.eval("globalThis.caveSocial="+JSON.stringify(state)+";globalThis.caveSocialTransitions="+JSON.stringify(transitions)+";0",true)
