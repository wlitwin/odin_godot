extends Node
var game:Node
var command:=0
var paused:=true
var closing:=false
func _ready():
 game=load("res://hello.tscn").instantiate();game.debug_enabled=true;add_child(game);game.pause(true)
func _process(_dt:float):
 if closing:return
 var value=JavaScriptBridge.eval("globalThis.scrubberCommand?JSON.stringify(globalThis.scrubberCommand):''",true)
 if value is String and value!="":
  var request=JSON.parse_string(value)
  if request is Dictionary and int(request.id)>command:
   command=int(request.id)
   if request.has("paused"):paused=bool(request.paused);game.pause(paused)
   if request.get("close",false):
    closing=true;game.queue_free();game=null
    await get_tree().process_frame;await get_tree().process_frame
    JavaScriptBridge.eval("globalThis.scrubberClosed=true;0",true);return
 var controls:={}
 for slider in game.find_children("*","HSlider",true,false):controls.slider=rect(slider);break
 for button in game.find_children("*","Button",true,false):
  if "Branch" in str(button.text):controls.branch=rect(button)
  elif "Resume" in str(button.text) or "Pause" in str(button.text):controls.toggle=rect(button)
  elif str(button.text)=="Apply to preview":controls.apply=rect(button)
  elif str(button.text)=="Reset preview":controls.reset=rect(button)
  elif button.name=="ReplayRecordingExport":controls.export=rect(button)
 for field in game.find_children("*","OptionButton",true,false):
  controls.fields=rect(field)
  controls.field_paths=[]
  for index in range(field.item_count):controls.field_paths.append(field.get_item_text(index))
  controls.field_selected=field.selected
  break
 for value_edit in game.find_children("*","LineEdit",true,false):
  if value_edit.name=="ReplayFieldValue":controls.value=rect(value_edit);break
 var playback_controls:={}
 for action in ["Open","Play","Close","Branch","Details"]:
  var control=game.find_child("ReplayPlayback"+action,true,false)
  if control!=null:playback_controls[action]=rect(control)
 playback_controls.slider=rect(game.find_child("ReplayPlaybackSlider",true,false))
 var playback:={}
 for name in ["playback","playback_selected","playback_first","playback_head","playback_loads","playback_rejections","playback_playing"]:playback[name]=int(game.probe_history(name))
 playback.report=str(game.find_child("ReplayPlaybackReport",true,false).text)
 playback.status=str(game.find_child("ReplayPlaybackStatus",true,false).text)
 playback.controls=playback_controls
 var size:=get_tree().root.size
 var state:={"command":command,"paused":paused,"playback":playback,"head":int(game.probe_tick()),"epoch":int(game.probe_history("epoch")),"active":int(game.probe_history("active")),"edited":int(game.probe_history("edited")),"exports":int(game.probe_history("exports")),"first":int(game.probe_history("first")),"last":int(game.probe_history("last")),"selected":int(game.probe_history("selected")),"x":float(game.probe_x()),"shots":int(game.probe_shots()),"begins":int(game.probe_begins()),"views":int(game.probe_views()),"edit_status":str(game.find_child("ReplayFieldStatus",true,false).text),"status":str(game.get_node("Status").text),"controls":controls,"width":size.x,"height":size.y}
 JavaScriptBridge.eval("globalThis.scrubberState="+JSON.stringify(state)+";0",true)
func rect(control:Control)->Array:
 var bounds:=control.get_viewport().get_screen_transform()*control.get_global_rect();return [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]
