extends SceneTree
func _initialize():run.call_deferred()
func run():
	var hud=load("res://dev/hud_view.tscn").instantiate()
	hud.get_node("Vitals").position=Vector2(60,40)
	root.add_child(hud);await process_frame;await process_frame
	assert(hud.visible and hud.get_node("Vitals/Text").text=="5/10")
	assert(hud.get_node("Ammo/Count").text=="2 / 8" and hud.get_node("Ammo/State").text=="low")
	assert(hud.get_node("Vitals").position==Vector2(60,40))
	hud.queue_free();hud=null;await process_frame;await process_frame
	print("REPLAY_EDITOR_HUD_PREVIEW_OK standalone=true layout=true values=true")
	quit(0)
