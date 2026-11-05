extends Node3D

var sample: Node
var camera: Camera3D
var proxies: Dictionary = {}
var last_positions: Dictionary = {}
var beams: Array[MeshInstance3D] = []
var title: Label
var objective: Label
var crew: Label
var debug: Label
var hint: Label
var result: Label
var result_box: VBoxContainer
var retry_button: Button
var next_button: Button
var selected_cargo := 0
var local_host := true
var cargo_clamps: Dictionary = {}
var bay_materials: Array[StandardMaterial3D] = []
var debug_visible := false
var party_box: VBoxContainer
var party_name: LineEdit
var party_code: LineEdit
var party_notice: Label
var party_host: Button
var party_join: Button
var party_recent: Button
var party_copy: Button
var party_leave: Button
var party_watch: Button
var party_copy_watch: Button
var party_rehost: Button
var menu_open := false
var feedback
var web_text_entry
var settings_box: VBoxContainer
var camera_zoom := 18.8
var pending_transition := ""
var pending_exit_code := 0
var hud: Control
var status_panel: PanelContainer
var help_panel: PanelContainer
var layout_probe := false
var layout_report_pending := false
var colors := {"robot_a":Color("4ce4cf"),"robot_b":Color("ff836e"),"cargo_a":Color("ffc857"),"cargo_b":Color("ffc857"),"cargo_long":Color("ea87c7"),"crane":Color("f8b65c"),"barge":Color("407f8d"),"ramp":Color("62858a"),"ground":Color("304c59"),"crane_anchor":Color("597582")}

func material(color: Color, unshaded: bool=false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func cube(parent: Node3D, size: Vector3, color: Color, at: Vector3=Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color)
	node.position = at
	parent.add_child(node)
	return node

func text(parent: Control, content: String, font: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size",font)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

func panel(parent: Control, width: float) -> VBoxContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size.x = width
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.075,0.105,0.94)
	style.set_corner_radius_all(14)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel",style)
	parent.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",5)
	p.add_child(box)
	return box

func centered_panel(parent: Control, width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := panel(center,width)
	var backdrop: Control = box.get_parent()
	backdrop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	backdrop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return box

func fit_camera() -> void:
	if not is_instance_valid(camera):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y,1.0)
	# Keep the reference dock visible on narrow windows. DPI does not enter
	# this calculation; projection and pointer rays share viewport coordinates.
	camera.size = camera_zoom * maxf(1.0,(1280.0/720.0)/aspect)

func queue_layout_report() -> void:
	if not layout_probe or layout_report_pending:
		return
	layout_report_pending = true
	call_deferred("report_layout")

func control_layout(control: Control) -> Dictionary:
	var rect := control.get_global_rect()
	var screen := control.get_screen_transform() * Rect2(Vector2.ZERO,control.size)
	return {"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],
		"screen_rect":[screen.position.x,screen.position.y,screen.size.x,screen.size.y],
		"visible":control.is_visible_in_tree(),"focused":control.has_focus()}

func ui_layout() -> Dictionary:
	var controls := {}
	for entry in [["name",party_name],["code",party_code],["host",party_host],["join",party_join],
		["watch",party_watch],["recent",party_recent],["copy",party_copy],["copy_watch",party_copy_watch],
		["leave",party_leave],["rehost",party_rehost],["retry",retry_button],["next",next_button]]:
		controls[entry[0]] = control_layout(entry[1])
	var panels := {}
	for entry in [["status",status_panel],["help",help_panel],["crew",party_box.get_parent()],
		["results",result_box.get_parent()],["settings",settings_box.get_parent()]]:
		panels[entry[0]] = control_layout(entry[1])
	var viewport_size := get_viewport().get_visible_rect().size
	var pixels := get_window().size
	var origin := hud.get_screen_transform().origin
	return {"viewport":[viewport_size.x,viewport_size.y],"window_pixels":[pixels.x,pixels.y],
		"screen_origin":[origin.x,origin.y],
		"panels":panels,"controls":controls,"camera_size":camera.size,"camera_zoom":camera_zoom}

func report_layout() -> void:
	# Container sorting is deferred; observe settled geometry after a resize.
	await get_tree().process_frame
	await get_tree().process_frame
	layout_report_pending = false
	if is_inside_tree():
		print("DOCKYARD_UI_LAYOUT ",JSON.stringify(ui_layout()))

func _ready() -> void:
	sample = get_parent()
	feedback=preload("res://feedback.gd").new()
	add_child(feedback)
	if OS.has_feature("web"):
		add_child(preload("res://web_runtime.gd").new())
		web_text_entry=preload("res://web_text_entry.gd").new()
		add_child(web_text_entry)
	get_tree().auto_accept_quit=false
	get_window().close_requested.connect(func(): request_exit(0))
	# Functional software-GL automation can opt out of drawing. Physics, input,
	# copied presentation and network processing use the same game callbacks.
	if OS.has_feature("web") and str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('render')||'1'",true))=="0":
		get_viewport().disable_3d=true
	# Copy authored visual values while the detached authoring tree is present.
	# The runtime frees that source; later transforms come only from copied Frames.
	var source := sample.get_node("AuthoredWorld")
	for body in source.get_children():
		if not body is Box3DBody3D:
			continue
		var key: String = body.stable_key
		var proxy := Node3D.new()
		add_child(proxy)
		proxy.transform = body.transform
		proxies[key] = proxy
		if key == "delivery":
			continue
		for shape in body.shapes:
			if shape is Box3DBoxShape3D:
				var part := cube(proxy,shape.half_extents*2*shape.scale,colors.get(key,Color("627d87")))
				part.transform = shape.local_pose
			elif shape is Box3DSphereShape3D:
				var sphere := MeshInstance3D.new()
				var sphere_mesh := SphereMesh.new()
				sphere_mesh.radius=shape.radius*shape.scale.x
				sphere_mesh.height=sphere_mesh.radius*2
				sphere.mesh=sphere_mesh
				sphere.material_override=material(colors.get(key,Color("627d87")))
				sphere.transform=shape.local_pose
				proxy.add_child(sphere)
		if key.begins_with("robot_"):
			cube(proxy,Vector3(.72,.10,.73),Color("203b49"),Vector3(0,.42,0))
			for x in [-0.2,0.2]:
				cube(proxy,Vector3(.13,.18,.06),Color("132935"),Vector3(x,.12,.46))
				cube(proxy,Vector3(.065,.10,.065),Color("eafff7"),Vector3(x,.14,.49))
			cube(proxy,Vector3(.20,.25,.12),Color("f5f1d8"),Vector3(0,-.1,-.47))
		if key.begins_with("cargo_"):
			var half: Vector3 = body.shapes[0].half_extents
			cube(proxy,Vector3(.12,half.y*2+.012,half.z*2+.014),Color("785d49"))
			cube(proxy,Vector3(half.x*2+.014,.08,.12),Color("fff0b4"),Vector3(0,half.y+.015,0))
			var clamps := Node3D.new()
			proxy.add_child(clamps)
			for side in [-1.0,1.0]:
				cube(clamps,Vector3(.16,.16,.42),Color("8df2ba"),Vector3(side*(half.x+.03),-half.y+.04,0))
			clamps.visible=false
			cargo_clamps[key]=clamps
			var label := Label3D.new()
			label.text = "LONG" if key=="cargo_long" else "A" if key=="cargo_a" else "B"
			label.position.y = half.y+.45
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size = 48
			label.pixel_size = .010
			label.outline_size = 8
			label.outline_modulate = Color("142e38")
			proxy.add_child(label)
	# Everything below is presentation decoration, with no Godot physics bodies.
	cube(self,Vector3(90,.05,90),Color("113e55"),Vector3(0,-1.4,0))
	for x in range(-8,10,2):
		cube(self,Vector3(.025,.015,15.5),Color("43616a"),Vector3(x,.012,0))
	for z in range(-7,8,2):
		cube(self,Vector3(19.5,.015,.025),Color("43616a"),Vector3(0,.012,z))
	for x in [-9.4,9.4]:
		for z in [-7.3,7.3]:
			cube(self,Vector3(.35,2,.35),Color("f0bc67"),Vector3(x,.5,z))
	# Readable landing-pad stripes sit on the actual barge, not another collider.
	var barge: Node3D = proxies["barge"]
	for z in [-2.65,2.65]:
		cube(barge,Vector3(6.4,.025,.12),Color("9ceebc"),Vector3(0,.27,z))
	for x in [-3.2,3.2]:
		cube(barge,Vector3(.12,.025,5.3),Color("9ceebc"),Vector3(x,.27,0))
	var pads := [Vector3(-1.6,.29,.9),Vector3(1.2,.29,.9),Vector3(0,.29,-.7)]
	for index in range(3):
		var bay := MeshInstance3D.new()
		var marker := BoxMesh.new()
		marker.size=Vector3(3.1,.018,1.2) if index==2 else Vector3(1.5,.018,1.5)
		bay.mesh=marker
		var bay_material := material(Color("4b8b83"))
		bay.material_override=bay_material
		bay_materials.append(bay_material)
		bay.position=pads[index]
		barge.add_child(bay)
		var bay_label := Label3D.new()
		bay_label.text=["A · $250","B · $350","LONG · $600"][index]
		bay_label.position=pads[index]+Vector3(0,.12,0)
		bay_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		bay_label.font_size=38
		bay_label.pixel_size=.008
		barge.add_child(bay_label)
	var landing := Label3D.new()
	landing.text = "ESCAPE BARGE"
	landing.position = Vector3(0,2.4,0)
	landing.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	landing.font_size = 50
	landing.pixel_size = .009
	landing.modulate = Color("b1ffd1")
	barge.add_child(landing)
	for robot in ["robot_a","robot_b"]:
		var beam:=cube(self,Vector3.ONE,colors[robot])
		beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.visible=false
		beams.append(beam)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = camera_zoom
	camera.position = Vector3(14,17,20)
	add_child(camera)
	camera.look_at(Vector3(0,.2,0))
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.light_color = Color("ffe0b6")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("103849")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9ddacb")
	e.ambient_light_energy = .42
	env.environment = e
	add_child(env)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Control.new()
	hud.name = "HUD"
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margins := MarginContainer.new()
	margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right"]:
		margins.add_theme_constant_override("margin_"+edge,24)
	for edge in ["top","bottom"]:
		margins.add_theme_constant_override("margin_"+edge,22)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margins.add_child(rows)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(top)
	var box := panel(top,360)
	status_panel = box.get_parent()
	title = text(box,"DOCKYARD DUO",27,Color("fff2d6"))
	objective = text(box,"Get the cargo onto the barge",17,Color("a9f3db"))
	crew = text(box,"Opening the dock…",14,Color("9bb9c6"))
	crew.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var horizontal_space := Control.new()
	horizontal_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(horizontal_space)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 440
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(right)
	var vertical_space := Control.new()
	vertical_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vertical_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(vertical_space)
	var help := panel(rows,650)
	help_panel = help.get_parent()
	hint = text(help,"WASD / arrows   MOVE     ·     mouse + hold   MAGNET",16,Color("e6f1f2"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var help_detail := text(help,"Space  BOOST    ·    1 / 2 / 3  AIM    ·    Match each load to its bay; release to latch.",14,Color("9bb9c6"))
	help_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var help_flow := text(help,"1 GRAB  /  2 HAUL TO THE MATCHING BAY  /  3 RELEASE & SETTLE.     F2 settings · Esc crew · F3 diagnostics",13,Color("b1d8d2"))
	help_flow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug = text(right,"",12,Color("a9d6cf"))
	debug.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug.visible = false
	result_box = centered_panel(hud,430)
	result = text(result_box,"",26,Color("fff2d6"))
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	retry_button = Button.new()
	retry_button.text = "RETRY THIS JOB"
	retry_button.pressed.connect(func(): sample.call("retry",false))
	result_box.add_child(retry_button)
	next_button = Button.new()
	next_button.text = "NEXT JOB >"
	next_button.pressed.connect(func(): sample.call("retry",true))
	result_box.add_child(next_button)
	result_box.get_parent().visible=false
	party_box=panel(right,440)
	text(party_box,"BUILD YOUR CREW",23,Color("fff2d6"))
	party_name=LineEdit.new()
	party_name.placeholder_text="Your crew name"
	party_name.max_length=32
	party_box.add_child(party_name)
	party_code=LineEdit.new()
	party_code.placeholder_text="5-character room code"
	party_code.max_length=85
	party_code.focus_entered.connect(func():
		if web_text_entry != null:
			web_text_entry.edit(party_code)
	)
	party_box.add_child(party_code)
	var doors:=HBoxContainer.new()
	party_box.add_child(doors)
	party_host=Button.new()
	party_host.text="HOST"
	party_host.pressed.connect(func(): sample.call("party","host",party_name.text,""))
	doors.add_child(party_host)
	party_join=Button.new()
	party_join.text="JOIN"
	party_join.pressed.connect(func(): sample.call("party","join",party_name.text,party_code.text))
	doors.add_child(party_join)
	party_watch=Button.new()
	party_watch.text="WATCH"
	party_watch.pressed.connect(func(): sample.call("party","watch",party_name.text,party_code.text))
	doors.add_child(party_watch)
	party_recent=Button.new()
	party_recent.text="RECENT CREW"
	party_recent.pressed.connect(func(): sample.call("party","recent",party_name.text,""))
	doors.add_child(party_recent)
	party_copy=Button.new()
	party_copy.text="COPY INVITE"
	party_copy.pressed.connect(func():
		var info: Variant=JSON.parse_string(sample.call("online_status"))
		if info is Dictionary and not str(info.get("invite","")).is_empty():
			if web_text_entry != null:
				web_text_entry.copy_code(str(info["invite"]))
			else:
				DisplayServer.clipboard_set(str(info["invite"]))
	)
	party_box.add_child(party_copy)
	party_copy_watch=Button.new()
	party_copy_watch.text="COPY WATCH INVITE"
	party_copy_watch.pressed.connect(func():
		var info: Variant=JSON.parse_string(sample.call("online_status"))
		if info is Dictionary and not str(info.get("watch_invite","")).is_empty():
			if web_text_entry != null:
				web_text_entry.copy_code(str(info["watch_invite"]))
			else:
				DisplayServer.clipboard_set(str(info["watch_invite"]))
	)
	party_box.add_child(party_copy_watch)
	party_notice=text(party_box,"Opening room storage…",14,Color("b1d8d2"))
	party_notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	party_leave=Button.new()
	party_leave.text="LEAVE CREW"
	party_leave.pressed.connect(func():
		if bool(sample.call("close")):
			request_exit(0)
		else:
			party_notice.text="Finishing a callback. Try leaving again."
	)
	party_box.add_child(party_leave)
	party_rehost=Button.new()
	party_rehost.text="START A NEW CREW"
	party_rehost.pressed.connect(request_rehost)
	party_box.add_child(party_rehost)
	party_box.get_parent().visible=false
	settings_box=centered_panel(hud,430)
	text(settings_box,"YOUR DOCK",26,Color("fff2d6"))
	text(settings_box,"Local settings · the shared job keeps running",14,Color("b1d8d2"))
	text(settings_box,"Sound",16,Color("e6f1f2"))
	var volume:=HSlider.new()
	volume.min_value=0
	volume.max_value=100
	volume.step=5
	volume.value=65
	volume.value_changed.connect(func(value: float): feedback.volume=value*.01)
	settings_box.add_child(volume)
	text(settings_box,"Camera distance",16,Color("e6f1f2"))
	var zoom:=HSlider.new()
	zoom.min_value=16
	zoom.max_value=24
	zoom.step=.2
	zoom.value=camera_zoom
	zoom.value_changed.connect(func(value: float): camera_zoom=value;fit_camera())
	settings_box.add_child(zoom)
	var motion:=CheckButton.new()
	motion.text="Reduce particles / flashes"
	motion.toggled.connect(func(enabled: bool): feedback.reduced_motion=enabled)
	settings_box.add_child(motion)
	var close_settings:=Button.new()
	close_settings.text="BACK TO THE DOCK"
	close_settings.pressed.connect(func(): settings_box.get_parent().visible=false)
	settings_box.add_child(close_settings)
	settings_box.get_parent().visible=false
	layout_probe = OS.get_environment("DOCKYARD_LAYOUT_PROBE")=="1"
	if OS.has_feature("web"):
		layout_probe = layout_probe or str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('ui_layout')||'0'",true))=="1"
	get_viewport().size_changed.connect(fit_camera)
	get_viewport().size_changed.connect(queue_layout_report)
	party_name.focus_entered.connect(queue_layout_report)
	party_code.focus_entered.connect(queue_layout_report)
	for control in [status_panel,help_panel,party_box.get_parent(),result_box.get_parent(),settings_box.get_parent()]:
		control.resized.connect(queue_layout_report)
		control.visibility_changed.connect(queue_layout_report)
	fit_camera()
	queue_layout_report()
	prepare_visuals()

func prepare_visuals() -> void:
	# Compatibility/WebGL compiles a new visible variant on first draw. Exercise
	# the real beam and pooled effects before accepting a live crew lease.
	if DisplayServer.get_name()=="headless" or get_viewport().disable_3d:
		sample.call("visuals_ready")
		print("DOCKYARD_VISUALS_READY ",JSON.stringify({"mode":"drawing_disabled","elapsed_ms":0}))
		return
	set_process(false)
	var started:=Time.get_ticks_msec()
	var loading:=CanvasLayer.new()
	loading.layer=100
	add_child(loading)
	var cover:=ColorRect.new()
	cover.color=Color("103849")
	loading.add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center:=CenterContainer.new()
	cover.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text(center,"Preparing the dock…",26,Color("fff2d6"))
	for i in range(beams.size()):
		beams[i].position=Vector3(float(i)*.3,1,0)
		beams[i].scale=Vector3(.045,.045,1.5)
		beams[i].visible=true
	feedback.prepare_visuals()
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	for beam in beams:
		beam.visible=false
	feedback.visuals_prepared()
	loading.queue_free()
	set_process(true)
	sample.call("visuals_ready")
	print("DOCKYARD_VISUALS_READY ",JSON.stringify({"mode":"rendered","elapsed_ms":Time.get_ticks_msec()-started}))

func request_exit(code: int=0) -> void:
	if code!=0:
		pending_exit_code=code
	if pending_transition=="reload":
		pending_transition="quit"
		return
	if not pending_transition.is_empty():
		return
	pending_transition="quit"
	call_deferred("_finish_transition")

func request_rehost() -> void:
	if not pending_transition.is_empty() or not bool(sample.call("rehost")):
		return
	pending_transition="reload"
	call_deferred("_finish_transition")

func _finish_transition() -> void:
	var close_deadline:=Time.get_ticks_msec()+2000
	while is_instance_valid(sample) and not bool(sample.call("close")):
		if Time.get_ticks_msec()>=close_deadline:
			push_error("DOCKYARD_CLOSE_TIMEOUT")
			get_tree().quit(1)
			return
		await get_tree().process_frame
	feedback.begin_shutdown()
	var started:=Time.get_ticks_msec()
	var frames:=0
	while feedback.pending_playbacks()>0 and Time.get_ticks_msec()-started<2000:
		frames+=1
		await get_tree().process_frame
	var timed_out: bool=feedback.pending_playbacks()>0
	feedback.finish_shutdown(frames,Time.get_ticks_msec()-started,timed_out)
	if timed_out:
		pending_transition="quit"
		pending_exit_code=1
	if pending_transition=="reload":
		var error:=get_tree().reload_current_scene()
		if error!=OK:
			pending_transition=""
			party_notice.text="The new dock could not open. Reopen the game."
	else:
		get_tree().quit(pending_exit_code)

func _unhandled_key_input(event: InputEvent) -> void:
	if not pending_transition.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F2:
		settings_box.get_parent().visible=not settings_box.get_parent().visible
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		menu_open=not menu_open
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode>=KEY_1 and event.keycode<=KEY_3:
			selected_cargo=event.keycode-KEY_1
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F3:
		debug_visible = not debug_visible
		debug.visible = debug_visible

func _process(_dt: float) -> void:
	if not pending_transition.is_empty():
		return
	if not is_instance_valid(sample) or not sample.has_method("status"):
		return
	var status: Variant = JSON.parse_string(sample.call("status"))
	var value: Variant = JSON.parse_string(sample.call("presentation"))
	var online: Variant = JSON.parse_string(sample.call("online_status"))
	var in_menu:=false
	if online is Dictionary and bool(online.get("enabled",false)):
		in_menu=not bool(online.get("go",false)) or bool(online.get("ended",false)) or menu_open
		party_box.get_parent().visible=in_menu
		party_notice.text=str(online.get("message",""))
		var can_start:=bool(online.get("can_start",false))
		party_host.disabled=not can_start
		party_join.disabled=not can_start
		party_watch.disabled=not can_start
		party_recent.disabled=not can_start or not bool(online.get("recent",false))
		party_copy.visible=not bool(online.get("ended",false)) and not str(online.get("invite","")).is_empty()
		var room_code:=str(online.get("invite",""))
		party_copy.text="ROOM: %s  ·  COPY" % room_code if room_code.length()==5 else "COPY INVITE"
		party_copy_watch.visible=not bool(online.get("ended",false)) and not str(online.get("watch_invite","")).is_empty()
		party_rehost.visible=bool(online.get("ended",false))
		party_name.editable=can_start
		party_code.editable=can_start
		if bool(online.get("connected",false)) and not in_menu:
			crew.text=str(online.get("name","Crew"))+" · CREW CONNECTED"
	if status is Dictionary:
		var role := str(status.get("role","host"))
		local_host=role=="host"
		crew.text = ("P1 · MINT  /  Hosting" if role=="host" else "P2 · CORAL  /  Joined crew") + "   •   " + str(status.get("phase","Joining"))
		if debug_visible:
			debug.text = "REPLAY + BOX3D\nhead %s   confirmed %s\n%s" % [str(status.get("head","—")),str(status.get("confirmed","—")),str(status.get("error",""))]
	if online is Dictionary and bool(online.get("enabled",false)):
		if not bool(online.get("connected",false)):
			crew.text="Choose a name, then host or join a crew."
		elif not str(online.get("name","")).is_empty():
			crew.text=str(online.name)+" · "+("OBSERVER" if str(status.get("role",""))=="observer" else "P1 / MINT" if local_host else "P2 / CORAL")
	if value is Dictionary:
		for row in value.get("bodies",[]):
			var key := str(row.get("key",""))
			if not proxies.has(key):
				continue
			var p: Array = row.get("position",[])
			var q: Array = row.get("rotation",[])
			if p.size()==3 and q.size()==4:
				var at := Vector3(p[0],p[1],p[2])
				var proxy: Node3D = proxies[key]
				proxy.position = at
				if key.begins_with("robot_"):
					# The Native sphere rolls; its cosmetic robot shell stays upright.
					var before: Vector3=last_positions.get(key,at)
					var motion := at-before
					if motion.length_squared()>.00001:
						proxy.rotation.y=lerp_angle(proxy.rotation.y,atan2(motion.x,motion.z),.25)
				else:
					proxy.quaternion = Quaternion(q[0],q[1],q[2],q[3])
				last_positions[key] = at
		feedback.consume(value,proxies)
		var score := int(value.get("score",0))
		var phase := str(value.get("phase","Working"))
		var seconds := int(ceil(float(value.get("remaining_ticks",9000))/60.0))
		var job := str(value.get("job","First Shift"))
		var payout := int(value.get("payout",0))
		objective.text = "%s  ·  %02d:%02d\nCARGO SECURED  %d / 3" % [job.to_upper(),seconds/60,seconds%60,score]
		if phase=="Departing":
			objective.text="BARGE LEAVING!  ·  %d / 3 SECURED" % score
		var lost: Array = value.get("lost",[false,false,false])
		var delivered: Array=value.get("delivered",[false,false,false])
		var cargo_names := ["cargo_a","cargo_b","cargo_long"]
		for index in range(3):
			var cargo_key: String=cargo_names[index]
			if proxies.has(cargo_key):
				proxies[cargo_key].visible=not bool(lost[index])
			if cargo_clamps.has(cargo_key):
				cargo_clamps[cargo_key].visible=bool(delivered[index])
			bay_materials[index].albedo_color=Color("8ce8b2") if bool(delivered[index]) else Color("4b8b83")
		var cooldown: Array=value.get("cooldown",[0,0])
		var seat_index := 0 if local_host else 1
		hint.text="WASD / arrows  MOVE   ·   mouse + hold  MAGNET   ·   BOOST %s" % ("READY" if int(cooldown[seat_index])==0 else "CHARGING")
		result_box.get_parent().visible=phase=="Results"
		result.text=("PERFECT HAUL!" if score==3 else "SHIFT COMPLETE")+"\n%d / 3 LOADS  ·  $%d" % [score,payout]
		if not local_host:
			result.text+="\nWaiting for the host’s next job…"
		retry_button.visible=local_host
		next_button.visible=local_host
		for beam in beams:
			beam.visible=false
		var magnets: Array = value.get("magnet",[0,0])
		for seat in range(2):
			var robot := "robot_a" if seat==0 else "robot_b"
			var target := int(magnets[seat])
			if target<1 or target>3 or not last_positions.has(robot):
				continue
			var cargo: String = ["cargo_a","cargo_b","cargo_long"][target-1]
			if not last_positions.has(cargo):
				continue
			var start: Vector3=last_positions[robot]+Vector3(0,.35,0)
			var end: Vector3=last_positions[cargo]
			var direction:=end-start
			var length:=direction.length()
			if length<.001:
				continue
			var beam: MeshInstance3D=beams[seat]
			beam.position=(start+end)*.5
			var up:=Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP))>.99 else Vector3.UP
			beam.look_at(end,up)
			beam.scale=Vector3(.045,.045,length)
			beam.visible=true
	if OS.get_environment("BOX3D_SAMPLE_SCRIPTED")=="1" or OS.get_environment("DOCKYARD_AUTOCAPTURE")=="1" or (OS.has_feature("web") and str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('scripted')||'0'",true))=="1"):
		return
	if in_menu or settings_box.get_parent().visible or (status is Dictionary and str(status.get("role",""))=="observer"):
		sample.call("control",0,0,0,0,0,false,false)
		return
	var axes := Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	var right := camera.global_basis.x
	var back := camera.global_basis.z
	right.y=0
	back.y=0
	var move := right.normalized()*axes.x + back.normalized()*axes.y
	if move.length()>1:
		move=move.normalized()
	var mouse := get_viewport().get_mouse_position()
	var selected_key: String=["cargo_a","cargo_b","cargo_long"][selected_cargo]
	var selected_position: Vector3=last_positions.get(selected_key,Vector3(0,.5,0))
	var aim: Variant = Plane(Vector3.UP,selected_position.y).intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
	var point: Vector3 = aim if aim is Vector3 else Vector3.ZERO
	# Keyboard cargo selection is an aiming aid over copied presentation only.
	# Native ray queries still decide what the magnet can actually grab.
	if Input.is_physical_key_pressed(KEY_1) or Input.is_physical_key_pressed(KEY_2) or Input.is_physical_key_pressed(KEY_3):
		var cargo: String=["cargo_a","cargo_b","cargo_long"][selected_cargo]
		if last_positions.has(cargo):
			point=last_positions[cargo]
	sample.call("control",roundi(move.x*100),roundi(move.z*100),roundi(point.x*100),roundi(point.y*100),roundi(point.z*100),Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),Input.is_physical_key_pressed(KEY_SPACE))
