extends "res://workbench_test.gd"
const ViewProbe = preload("res://view_probe.gd")

func rig() -> Node2D: return game.get_node("World/Runner1")
func heavy() -> Sprite2D:
	for child in game.get_node("World").get_children():
		var sprite := child.get_node_or_null("Body") as Sprite2D
		if sprite != null and child.visible and sprite.visible and sprite.texture != null and "zombie_heavy" in sprite.texture.resource_path: return sprite
	return null
func picture(name: String):
	var directory := OS.get_environment("RSY_ACTOR_CAPTURE")
	if directory == "": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(directory + "/" + name + ".png") != OK: await finish(1, "actor capture"); return
	image = null

func run():
	root.size = Vector2i(1280, 704)
	bench = load("res://dev/workbench.tscn").instantiate(); bench.open_shop = true
	root.add_child(bench); game = bench.game_node()
	if not await until(func(): return bench.is_staged() and p("stage") == 2): await finish(1, "actor staging"); return
	bench.open_shop = false
	var body := rig().get_node("Body") as Sprite2D
	var gun := rig().get_node("Gun") as Sprite2D
	var flash := gun.get_node("Flash") as Sprite2D
	var reload := rig().get_node("Reload") as Sprite2D
	var beacon := rig().get_node("Beacon") as Node2D
	if body.rotation != 0 or not gun.visible or beacon.visible or flash.visible or reload.visible: await finish(1, "initial pose"); return
	if game.dev_hurt(1, 3) <= 0: await finish(1, "hurt setup"); return
	if not await until(func(): return p("hp") == 7 and rig().modulate.r > 1.1): await finish(1, "runner hit flash"); return
	await picture("hurt")
	if not await until(func(): return rig().modulate.r <= 1.001): await finish(1, "hit flash did not fade"); return
	game.dev_aim(1.0, 0.0, true)
	if not await until(func(): return flash.visible and p("shots") > 0): await finish(1, "muzzle flash"); return
	await picture("muzzle")
	if not await until(func(): return p("gun_mode") == 1 and reload.visible): await finish(1, "overhead reload flag"); return
	game.dev_aim(1.0, 0.0, false)
	if reload.region_rect != Rect2(96, 0, 32, 16): await finish(1, "reload atlas"); return
	await picture("reload")
	if game.dev_hurt(1, 255) <= 0: await finish(1, "down setup"); return
	if not await until(func(): return p("hp") == 0 and abs(body.rotation - 1.4) < 0.01 and beacon.visible): await finish(1, "downed pose"); return
	if gun.visible or reload.visible or flash.visible or abs(rig().modulate.a - 0.45) > 0.01: await finish(1, "downed equipment/tint"); return
	var frame := body.frame; await create_timer(0.25).timeout
	if body.frame != frame: await finish(1, "downed animation advanced"); return
	await picture("downed")
	if not await until(func(): return p("run") == 1 and p("hp") == 10 and body.rotation == 0 and gun.visible and not beacon.visible): await finish(1, "respawn pose"); return
	if flash.visible or reload.visible: await finish(1, "old equipment cue on respawn"); return
	if game.dev_spawn(1, 1, 30.0, 0.0) <= 0: await finish(1, "enemy setup"); return
	if not await until(func(): return heavy() != null and heavy().frame_coords.y == 1): await finish(1, "enemy attack row"); return
	var enemy := heavy(); var enemy_id := enemy.get_instance_id()
	if not enemy.flip_h: await finish(1, "enemy did not face nearby prey"); return
	await picture("attacking")
	var shots := p("shots"); game.dev_aim(1.0, 0.0, true)
	if not await until(func(): return p("shots") > shots): await finish(1, "enemy shot"); return
	game.dev_aim(1.0, 0.0, false)
	if not await until(func(): return heavy() != null and heavy().modulate.r > 1.1 and abs(heavy().rotation) > 0.001): await finish(1, "enemy hit/wobble"); return
	if game.dev_smite(1) <= 0: await finish(1, "enemy death setup"); return
	if not await until(func(): return heavy() != null and heavy().frame_coords.y == 3): await finish(1, "enemy death row"); return
	await picture("death")
	if not await until(func(): return heavy() == null): await finish(1, "enemy reap"); return
	if game.dev_spawn(5, 1, 30.0, 0.0) <= 0: await finish(1, "pooled prop setup"); return
	var prop: Sprite2D
	if not await until(func():
		for child in game.get_node("World").get_children():
			var sprite := child.get_node_or_null("Body") as Sprite2D
			if sprite != null and child.visible and sprite.visible and sprite.region_enabled and sprite.texture != null and sprite.texture.resource_path.ends_with("objects.png"): return true
		return false): await finish(1, "replacement prop binding"); return
	for child in game.get_node("World").get_children():
		var sprite := child.get_node_or_null("Body") as Sprite2D
		if sprite != null and child.visible and sprite.visible and sprite.region_enabled and sprite.texture != null and sprite.texture.resource_path.ends_with("objects.png"): prop = sprite; break
	if prop == null or prop.get_instance_id() == enemy_id or prop.flip_h or prop.rotation != 0 or prop.modulate != Color.WHITE: await finish(1, "old lifetime/pose leaked into prop"); return
	if is_instance_valid(enemy): await finish(1, "old enemy view was not retired"); return
	print("REPLAY_ACTOR_VIEW_OK down=true respawn=true hit=true muzzle=true reload=true attack=true death=true reuse=true")
	await finish(0)
