extends SceneTree
var view:Node
func _initialize():run.call_deferred()
func run():
	view=load("res://dev/enemy_view.tscn").instantiate()
	# Inspector-style changes before _ready; no game, runner, or Session exists.
	view.appearance=view.appearance.duplicate(true);view.appearance.tint=Color(0.4,0.8,0.6,1)
	view.get_node("Body").position=Vector2(9,-5)
	view.get_node("Telegraph").default_color=Color(0.2,0.6,1,0.7)
	root.add_child(view)
	await process_frame;await process_frame
	var body:Sprite2D=view.get_node("Body")
	var first:=body.frame
	await create_timer(0.25).timeout
	assert(body.frame!=first,"independent scene animation")
	assert(body.position==Vector2(9,-5),"authored child offset")
	assert(body.modulate.is_equal_approx(Color(0.4,0.8,0.6,1)),"authored appearance resource")
	assert(body.hframes==11 and body.frame_coords.y==1,"authored atlas and attack")
	var scene:=PackedScene.new();assert(scene.pack(view)==OK)
	view.queue_free();await process_frame;await process_frame
	view=scene.instantiate();root.add_child(view)
	await process_frame;await process_frame
	assert(view.get_node("Body").position==Vector2(9,-5),"saved composition")
	view.queue_free();view=null;scene=null
	await process_frame;await process_frame
	print("REPLAY_EDITOR_ENEMY_PREVIEW_OK standalone=true animation=true authored_offset=true resource=true roundtrip=true")
	quit(0)
