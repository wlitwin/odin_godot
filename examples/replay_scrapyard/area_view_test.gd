extends "res://workbench_test.gd"
const ViewProbe = preload("res://view_probe.gd")

func discs(prefix: String) -> Array:
	var result := []
	for child in game.get_node("World").get_children():
		if ViewProbe.polygon(child) and child.visible and str(child.name).begins_with(prefix): result.append(child)
	return result
func bursts() -> Array:
	var result := []
	for child in game.get_node("World").get_children():
		if child is CPUParticles2D and ViewProbe.tint(child).is_equal_approx(Color(1,0.9,0.4,1)): result.append(child)
	return result
func unit_disc(node: Node2D, depth: int) -> bool:
	if ViewProbe.vertices(node).size() != 24 or node.z_index != depth: return false
	for i in range(24):
		var angle := float(i)/24 * TAU
		if not ViewProbe.vertices(node)[i].is_equal_approx(Vector2(cos(angle),sin(angle))): return false
	return node.scale.x == node.scale.y
func setup(left: int, right: int) -> bool:
	bench = load("res://dev/workbench.tscn").instantiate(); bench.open_shop = true; bench.set_process(false)
	root.add_child(bench); game = bench.game_node()
	if not await until(func(): return p("ready")): return false
	game.dev_abilities(left,right)
	if not await until(func(): return p("ability0") == left and p("ability1") == right): return false
	bench.set_process(true)
	if not await until(func(): return bench.is_staged() and p("stage") == 2): return false
	bench.open_shop = false
	return true
func picture(name: String):
	var directory := OS.get_environment("RSY_AREA_CAPTURE")
	if directory == "" or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(directory + "/" + name + ".png") != OK: await finish(1,"area capture"); return
	image = null
func run():
	root.size = Vector2i(1280,704)
	if not await setup(3,5): await finish(1,"area staging"); return
	if not game.dev_cast(0,0.0,0.0,false): await finish(1,"nova cast"); return
	if not await until(func(): return discs("Area").size() == 1): await finish(1,"nova view"); return
	var nova: Node2D = discs("Area")[0]
	if not unit_disc(nova,8) or nova.scale.x < 137.9 or nova.scale.x > 159.1 or not Vector3(ViewProbe.tint(nova).r,ViewProbe.tint(nova).g,ViewProbe.tint(nova).b).is_equal_approx(Vector3(0.5,0.75,1)) or ViewProbe.tint(nova).a > 0.5:
		await finish(1,"nova disc/radius/color"); return
	var scale_before: float = nova.scale.x; var alpha_before: float = ViewProbe.tint(nova).a
	await picture("nova")
	await process_frame; await process_frame; await process_frame
	if not nova.visible or nova.scale.x <= scale_before or ViewProbe.tint(nova).a >= alpha_before: await finish(1,"nova expansion/fade"); return
	if not await until(func(): return not nova.visible,500): await finish(1,"nova expiry"); return
	if not game.dev_cast(1,float(p("x")+100),float(p("y")+60),true): await finish(1,"zone cast"); return
	if not await until(func(): return discs("Zone").size() == 1): await finish(1,"zone view"); return
	var zone: Node2D = discs("Zone")[0]
	if not unit_disc(zone,2) or zone.scale != Vector2(90,90) or not ViewProbe.tint(zone).is_equal_approx(Color(0.5,1,0.6,0.22)): await finish(1,"zone fill"); return
	var at: Vector2 = zone.position
	await picture("zone")
	if not await until(func(): return p("zone_left") > 0 and p("zone_left") < 25,7000): await finish(1,"zone late life"); return
	if zone.position != at or zone.scale != Vector2(90,90) or not ViewProbe.tint(zone).is_equal_approx(Color(0.5,1,0.6,0.22)): await finish(1,"zone must stay constant until expiry"); return
	if not await until(func(): return p("zones") == 0 and not zone.visible,1000): await finish(1,"zone expiry"); return
	bench.queue_free(); game = null; bench = null; await process_frame; await process_frame
	if not await setup(4,1): await finish(1,"buff staging"); return
	if not game.dev_cast(0,0.0,0.0,false): await finish(1,"buff cast"); return
	if not await until(func(): return bursts().size() == 1): await finish(1,"buff burst"); return
	var burst: CPUParticles2D = bursts()[0]
	if burst.amount != 12 or not is_equal_approx(burst.lifetime,0.4) or not burst.one_shot or burst.position.distance_to(Vector2(p("x"),p("y"))) > 1 or not discs("Area").is_empty(): await finish(1,"buff wearer/configuration"); return
	await create_timer(0.10).timeout
	await picture("buff")
	await create_timer(0.15).timeout
	if bursts().size() != 1 or bursts()[0] != burst: await finish(1,"buff duplicate"); return
	if not await until(func(): return bursts().is_empty(),1200): await finish(1,"buff cleanup"); return
	if not game.dev_cast(1,float(p("x")+220),float(p("y")),true): await finish(1,"reaction setup lob"); return
	if not await until(func(): return discs("Area").size() == 1): await finish(1,"lob impact disc"); return
	var reaction: Node2D = discs("Area")[0]
	if not unit_disc(reaction,8) or reaction.scale.x < 73.5 or reaction.scale.x > 84.9 or ViewProbe.tint(reaction).a > 0.45 or not Vector3(ViewProbe.tint(reaction).r,ViewProbe.tint(reaction).g,ViewProbe.tint(reaction).b).is_equal_approx(Vector3(0.45,0.9,0.5)):
		await finish(1,"reaction disc/radius/color"); return
	await picture("reaction")
	if not await until(func(): return not reaction.visible,500): await finish(1,"reaction expiry"); return
	print("REPLAY_AREA_VIEW_OK nova=true expansion=true fade=true zone=true constant=true expiry=true buff=true once=true reaction=true")
	await finish(0)
