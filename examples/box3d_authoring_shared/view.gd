class_name Box3DAuthoringSampleView
extends Node3D

# Rendering and input latch only. The Odin framework driver owns every tick;
# no authoring Node, native solver or Godot physics state is queried here.
var _driver: Node
var _proxies: Dictionary={}
var _label: Label
var _reset: Button
var _message: String=""
var _scripted: bool=false
func _ready() -> void:
	_driver=get_parent();_scripted=OS.get_environment("BOX3D_SAMPLE_SCRIPTED")=="1"
	_proxies={"ground":$Visuals/Ground,"pendulum":$Visuals/Pendulum,"player":$Visuals/Player,"sensor":$Visuals/Sensor}
	$Camera3D.look_at(Vector3(0,1,0),Vector3.UP)
	var canvas:=CanvasLayer.new();add_child(canvas)
	var panel:=PanelContainer.new();panel.position=Vector2(16,16);canvas.add_child(panel)
	var box:=VBoxContainer.new();panel.add_child(box)
	_label=Label.new();_label.text="Authored Box3D — initializing driver";box.add_child(_label)
	var help:=Label.new();help.text="WASD / arrows: move shared player    Space: pulse
R / Reset: public framework reset when supported    Esc: close
Green volume: actual authored sensor; orange pendulum: one hinge";box.add_child(help)
	_reset=Button.new();_reset.text="Request public Reset";_reset.pressed.connect(_request_reset);box.add_child(_reset)
	var close:=Button.new();close.text="Close and release owners";close.pressed.connect(_close);box.add_child(close)
	get_tree().auto_accept_quit=false
func _json(method: String) -> Dictionary:
	if _driver==null or not _driver.has_method(method):return {}
	var value: Variant=_driver.call(method)
	if not value is String or value.is_empty():return {}
	var parsed: Variant=JSON.parse_string(value)
	return parsed if parsed is Dictionary else {}
func _process(_delta: float) -> void:
	if _driver==null:return
	if not _scripted and _driver.has_method("control"):
		var x: int=int(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))-int(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
		var z: int=int(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))-int(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
		_driver.call("control",x,z,Input.is_key_pressed(KEY_SPACE))
	var status: Dictionary=_json("status");var frame: Dictionary=_json("presentation")
	if frame.get("version",0)==1:
		for body in frame.get("bodies",[]):
			if not body is Dictionary or not _proxies.has(body.get("key","")):continue
			var p: Variant=body.get("position");var r: Variant=body.get("rotation")
			if not p is Array or p.size()!=3 or not r is Array or r.size()!=4:continue
			var position:=Vector3(p[0],p[1],p[2]);var rotation:=Quaternion(r[0],r[1],r[2],r[3])
			if position.is_finite() and rotation.is_finite():
				var proxy: Node3D=_proxies[body.key];proxy.position=position;proxy.quaternion=rotation
	if not status.is_empty():
		var supported: bool=bool(status.get("reset_supported",false));_reset.disabled=not supported
		_label.text="%s authored sample | %s | %s
head %s  confirmed %s  %s
%s"%[status.get("framework",""),status.get("role",""),status.get("phase",""),status.get("head","?"),status.get("confirmed","?"),"SCRIPTED (driver boundary)" if _scripted else "interactive",status.get("error","") if _message.is_empty() else _message]
		if DisplayServer.get_name()!="headless":DisplayServer.window_set_title("%s authored Box3D — %s"%[status.get("framework",""),status.get("role","")])
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_R:_request_reset()
		if event.keycode==KEY_ESCAPE:_close()
func _request_reset() -> void:
	if _driver==null or not _driver.has_method("request_reset"):return
	_message="Reset requested" if bool(_driver.call("request_reset")) else "Reset unsupported/unavailable on this framework path"
func _close() -> void:
	var closed: bool=_driver!=null and _driver.has_method("close") and bool(_driver.call("close"))
	get_tree().quit(0 if closed else 1)
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:_close()
