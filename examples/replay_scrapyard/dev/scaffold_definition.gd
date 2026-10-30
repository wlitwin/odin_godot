extends SceneTree
func _initialize():run.call_deferred()
func run():
	var source:Resource=load(OS.get_environment("RSY_DRAFT_SOURCE"))
	if source==null:quit(1);return
	var candidate:Resource=source.duplicate(false)
	candidate.id=int(OS.get_environment("RSY_DRAFT_ID"));candidate.name=OS.get_environment("RSY_DRAFT_NAME")
	if ResourceSaver.save(candidate,OS.get_environment("RSY_DRAFT_OUTPUT"))!=OK:quit(1);return
	print("REPLAY_AUTHORING_DRAFT_DEFINITION_OK id=",candidate.id)
	candidate=null;source=null;quit(0)
