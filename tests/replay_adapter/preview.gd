extends SceneTree
func _initialize():run.call_deferred()
func run():
	var node:Node=load("res://dev/stormcaller_view.tscn").instantiate()
	var sample:Resource=node.preview_state.duplicate(true)
	sample.definition.id=7;sample.definition.pulse.radius=195;sample.fraction=.6
	node.preview_state=sample
	root.add_child(node);await process_frame;await process_frame
	assert(node.get_node("Charge").visible)
	assert(abs(node.get_node("Telegraph").scale.x-195.0/180.0)<.002)
	var before:float=node.get_node("Charge").rotation
	await create_timer(.15).timeout
	assert(node.get_node("Charge").rotation!=before)
	node.queue_free();node=null;sample=null;await process_frame;await process_frame
	print("REPLAY_ADAPTER_PREVIEW_OK added_id=7 authored_radius=195 independent=true")
	quit()
