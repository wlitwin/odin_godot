extends "res://workbench_test.gd"
const ViewProbe = preload("res://view_probe.gd")

func flames() -> Array:
	var found := []
	for child in game.get_node("World").get_children():
		if child is Label and child.visible and str(child.name).begins_with("Flame"): found.append(child)
	return found
func arcs() -> Array:
	var found := []
	for child in game.get_node("World").get_children():
		if ViewProbe.polygon(child) and child.visible and str(child.name).begins_with("Arc"): found.append(child)
	return found
func picture(name: String):
	var directory := OS.get_environment("RSY_PATH_CAPTURE")
	if directory == "" or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(directory+"/"+name+".png") != OK: await finish(1,"path capture"); return
	image = null
func run():
	root.size = Vector2i(1280,704)
	bench = load("res://dev/workbench.tscn").instantiate(); bench.open_shop=true; bench.set_process(false)
	root.add_child(bench); game=bench.game_node()
	if not await until(func(): return p("ready")): await finish(1,"path admission"); return
	game.dev_abilities(2,1)
	if not await until(func(): return p("ability0")==2): await finish(1,"cone loadout"); return
	bench.set_process(true)
	if not await until(func(): return bench.is_staged() and p("stage")==2): await finish(1,"path staging"); return
	bench.open_shop=false
	var source := Vector2(p("x"),p("y"))
	if not game.dev_cast(0,1.0,0.0,false): await finish(1,"cone action"); return
	if not await until(func(): return flames().size()==5): await finish(1,"local five tongues"); return
	var radii := []; var angles := []; var bodies := flames()
	for label in bodies:
		if label.text!="*" or not str(label.name).begins_with("Flame0_"): await finish(1,"flame glyph/bank"); return
		var center: Vector2 = label.position + label.get_combined_minimum_size()/2
		radii.append(center.distance_to(source)); angles.append((center-source).angle())
	angles.sort()
	for i in range(5):
		if absf(angles[i]-float(i-2)*0.25)>0.001 or absf(radii[i]-radii[0])>0.01: await finish(1,"fan direction/centering"); return
	await picture("cone")
	await process_frame; await process_frame
	var center: Vector2 = bodies[2].position + bodies[2].get_combined_minimum_size()/2
	if not bodies[2].visible or center.distance_to(source)<=radii[0]: await finish(1,"tongue flight"); return
	if not await until(func(): return flames().is_empty(),500): await finish(1,"tongue expiry"); return
	if game.dev_spawn(5,1,60.0,0.0)<=0 or game.dev_spawn(5,1,110.0,0.0)<=0: await finish(1,"spread targets"); return
	if not await until(func(): return p("props")==2): await finish(1,"spread target admission"); return
	if game.dev_status(1,1)<=0: await finish(1,"primer"); return
	if not await until(func(): return p("fx_mask") & (1<<1)): await finish(1,"primer applied"); return
	if game.dev_status(1,6)<=0: await finish(1,"spread trigger"); return
	if not await until(func(): return arcs().size()==2): await finish(1,"two visible spread hops"); return
	for arc in arcs():
		print("RSY_ARC_VIEW position=",arc.position," color=",ViewProbe.tint(arc)," points=",ViewProbe.vertices(arc).size())
		if ViewProbe.vertices(arc).size()!=8 or arc.z_index!=8 or arc.position.distance_to(source)>0.01 or not Vector3(ViewProbe.tint(arc).r,ViewProbe.tint(arc).g,ViewProbe.tint(arc).b).is_equal_approx(Vector3(0.75,0.85,1)) or ViewProbe.tint(arc).a>0.8001:
			await finish(1,"arc geometry/color/origin"); return
		var point: Vector2=(ViewProbe.vertices(arc)[3]+ViewProbe.vertices(arc)[4])/2
		var end: Vector2=(arc.transform.x*point.x+arc.transform.y*point.y)/arc.transform.y.length()
		if absf(end.y)>0.01 or (absf(end.x-60)>0.01 and absf(end.x-110)>0.01): await finish(1,"recorded arc destination"); return
	await picture("spread")
	if not await until(func(): return arcs().is_empty(),600): await finish(1,"arc expiry"); return
	print("REPLAY_CAST_PATH_VIEW_OK cone=true five=true centered=true flight=true expiry=true spread=true recorded_targets=true")
	await finish(0)
