extends CanvasLayer

var target:Node2D
var state:OptionButton
var fraction:HSlider
var speed:SpinBox
var guides:CheckBox
var message:Label
var guide:Node2D

class SpatialGuide extends Node2D:
	var target:Node
	func _process(_dt:float):queue_redraw()
	func _draw():
		if target==null or not target.has_method("preview_radius"):return
		var radius:float=target.preview_radius()
		var reach:float=target.preview_range() if target.has_method("preview_range") else 0.0
		if radius>0:draw_arc(Vector2.ZERO,radius,0,TAU,96,Color(.2,.9,.6,.8),1.5,true)
		if reach>0:draw_arc(Vector2.ZERO,reach,0,TAU,96,Color(.9,.7,.2,.7),1.0,true)

func _ready():
	target=get_parent() as Node2D
	var box:=VBoxContainer.new();box.position=Vector2(12,12);box.custom_minimum_size=Vector2(255,0);add_child(box)
	var title:=Label.new();title.text="Isolated Preview";box.add_child(title)
	var refresh:=Button.new();refresh.text="Refresh authored data";refresh.pressed.connect(refresh_preview);box.add_child(refresh)
	state=OptionButton.new()
	for text in ["Idle","Attack / active","Charge","Hurt","Death / expired"]:state.add_item(text)
	state.selected=int(target.preview_phase()) if target.has_method("preview_phase") else 1;state.item_selected.connect(func(_i):apply());box.add_child(state)
	var scrub:=Label.new();scrub.text="Charge / progress";box.add_child(scrub)
	fraction=HSlider.new();fraction.max_value=1;fraction.step=.01;fraction.value=.7;fraction.value_changed.connect(func(_v):apply());box.add_child(fraction)
	var playback:=Label.new();playback.text="Playback speed (0 pauses)";box.add_child(playback)
	speed=SpinBox.new();speed.min_value=0;speed.max_value=4;speed.step=.1;speed.value=1;speed.value_changed.connect(func(_v):apply());box.add_child(speed)
	guides=CheckBox.new();guides.text="Show radius / range guides";guides.button_pressed=true;guides.toggled.connect(func(_v):apply());box.add_child(guides)
	message=Label.new();message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(message)
	guide=SpatialGuide.new();guide.target=target;target.add_child.call_deferred(guide)
	apply()

func apply():
	if state==null or fraction==null or speed==null or guides==null:return
	if target.has_method("preview_apply"):target.preview_apply(state.selected,fraction.value,speed.value)
	if is_instance_valid(guide):guide.visible=guides.button_pressed

func refresh_preview():
	if target.has_method("preview_can_refresh") and not target.preview_can_refresh():message.text="Refresh is available only in an isolated preview.";return
	# Reload only this isolated preview's authored source. The Odin method also
	# refuses refresh after a live presentation has bound the view.
	for property in target.get_property_list():
		if property.name in ["preview_state","definition","appearance"]:
			var current:Variant=target.get(property.name)
			if current is Resource and not current.resource_path.is_empty():
				var replacement:Resource=ResourceLoader.load(current.resource_path,"",ResourceLoader.CACHE_MODE_REPLACE_DEEP)
				if replacement!=null:target.set(property.name,replacement)
	var ok:bool=target.preview_refresh() if target.has_method("preview_refresh") else false
	message.text=target.preview_message() if target.has_method("preview_message") else ("Refreshed" if ok else "Refresh rejected")
	apply()
