extends SceneTree
func _initialize():run.call_deferred()
func run():
	var path:String=OS.get_environment("RSY_DRAFT_PREVIEW")
	var packed:PackedScene=load(path)
	if packed==null:quit(1);return
	var node:Node=packed.instantiate();root.add_child(node)
	await process_frame;await process_frame
	if not node.has_method("preview_refresh") or not node.preview_refresh():printerr("REPLAY_DRAFT_INVALID ",path);quit(1);return
	node.queue_free();node=null;packed=null;await process_frame;await process_frame
	print("REPLAY_DRAFT_VALIDATED ",path);quit()
