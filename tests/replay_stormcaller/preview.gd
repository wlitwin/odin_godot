extends SceneTree
func _initialize():run.call_deferred()
func run():
	var enemy=load("res://dev/stormcaller_view.tscn").instantiate();root.add_child(enemy)
	await process_frame;await process_frame
	assert(enemy.get_node("Charge").visible and enemy.get_node("Telegraph").visible)
	assert(abs(enemy.get_node("Telegraph").scale.x-140.0/180.0)<.002)
	var before:float=enemy.get_node("Charge").rotation
	await create_timer(.2).timeout
	assert(enemy.get_node("Charge").rotation!=before)
	enemy.queue_free();enemy=null;await process_frame;await process_frame
	print("STORMCALLER_PREVIEW_OK composed=true full_radius=true local_animation=true")
	quit(0)
