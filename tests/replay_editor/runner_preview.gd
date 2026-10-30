extends SceneTree
var view:Node
func _initialize():run.call_deferred()
func run():
	view=load("res://dev/runner_view.tscn").instantiate()
	view.get_node("Gun").position=Vector2(8,3)
	view.get_node("Gun/Flash").position=Vector2(29,-2)
	view.get_node("Reload").position=Vector2(0,-40)
	view.get_node("Beacon").position=Vector2(0,-52)
	root.add_child(view);await process_frame;await process_frame
	assert(view.get_node("Gun").position==Vector2(8,3))
	assert(view.get_node("Gun/Flash").position==Vector2(29,-2))
	var reload:Sprite2D=view.get_node("Reload");var first:=reload.position
	await create_timer(0.2).timeout
	assert(reload.visible and reload.position!=first and abs(reload.position.y+40)<2,"authored reload origin and local animation")
	view.preview_down=true;await process_frame;await process_frame
	var body:Sprite2D=view.get_node("Body");var frame:=body.frame
	await create_timer(0.2).timeout
	assert(abs(body.rotation-1.4)<0.01 and body.frame==frame,"downed local body")
	assert(not view.get_node("Gun").visible and not reload.visible and view.get_node("Beacon").visible)
	assert(abs(view.get_node("Beacon").position.y+52)<6,"authored beacon origin")
	view.queue_free();view=null;await process_frame;await process_frame
	print("REPLAY_EDITOR_RUNNER_PREVIEW_OK composition=true offsets=true animation=true downed=true")
	quit(0)
