extends Node

# Test-project autoload only. Drives the actual menu widgets and public methods;
# never edits a Session, Timeline, Native body, network packet or canonical Game.
func _process(_dt: float) -> void:
	if not OS.has_feature("web"):
		return
	var raw: Variant=JavaScriptBridge.eval("globalThis.dockyardRequest?JSON.stringify(globalThis.dockyardRequest):''",true)
	if not raw is String or raw.is_empty():
		return
	JavaScriptBridge.eval("globalThis.dockyardRequest=null;0",true)
	var request: Variant=JSON.parse_string(raw)
	var scene: Node=get_tree().current_scene
	if not request is Dictionary or not is_instance_valid(scene) or not scene.has_method("online_status"):
		return
	var view: Node=scene.get_node("View")
	var info: Dictionary=JSON.parse_string(scene.call("online_status"))
	var pressed:=false
	var closed:=false
	if request.get("action","") in ["host","join","recent"]:
		var name_field: LineEdit=view.get("party_name")
		var code_field: LineEdit=view.get("party_code")
		name_field.text=str(request.get("name","Crew"))
		code_field.text=str(request.get("invite",""))
		var button: Button=view.get("party_"+str(request.action))
		if button.is_visible_in_tree() and not button.disabled:
			button.emit_signal("pressed")
			pressed=true
	elif request.get("action","")=="copy":
		var button: Button=view.get("party_copy")
		if button.is_visible_in_tree():
			button.emit_signal("pressed")
			pressed=true
	elif request.get("action","")=="close":
		closed=scene.call("close")
	var copy_button: Button=view.get("party_copy")
	var copy_at: Vector2=copy_button.get_global_rect().get_center()
	var response: Dictionary={"id":request.id,"button_pressed":pressed,"closed":closed,"copy_button":{"visible":copy_button.is_visible_in_tree(),"x":copy_at.x,"y":copy_at.y},"online":JSON.parse_string(scene.call("online_status")),"status":JSON.parse_string(scene.call("status")),"presentation":JSON.parse_string(scene.call("presentation"))}
	JavaScriptBridge.eval("globalThis.dockyardResponse="+JSON.stringify(response)+";0",true)
	if closed:
		get_tree().quit(0)
