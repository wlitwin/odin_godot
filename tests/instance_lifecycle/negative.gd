extends SceneTree
func fail(message):
	push_error("INSTANCE_NEGATIVE_FAIL: "+message)
	quit(1)
func make_probe(id: int) -> Node:
	var node := Node.new()
	node.set_script(load("res://scripts/probe.odin"))
	node.set("case_id",id)
	var payload := Resource.new()
	payload.resource_name="retained"
	node.set("payload",payload)
	var child := Node.new()
	child.name="Child"
	node.add_child(child)
	return node
func _initialize(): call_deferred("run")
func run():
	var observer = make_probe(0)
	# Detached wrong-thread deletion cannot be canceled without native child
	# teardown. Quarantine the source, then let native destruction complete.
	var node = make_probe(12)
	var first_payload = weakref(node.get("payload"))
	var worker := Thread.new()
	print("EXPECTED_FINALIZE_PREDELETE_BEGIN")
	worker.start(func(): node.free())
	worker.wait_to_finish()
	print("EXPECTED_FINALIZE_PREDELETE_END")
	if is_instance_valid(node) or observer.audit(12,0)!=0 or first_payload.get_ref()==null:
		fail("wrong-thread PREDELETE was not quarantined")
		return
	node=make_probe(13)
	var payload = weakref(node.get("payload"))
	print("EXPECTED_FINALIZE_QUARANTINE_BEGIN")
	worker=Thread.new()
	worker.start(func(): node.set_script(null))
	worker.wait_to_finish()
	print("EXPECTED_FINALIZE_QUARANTINE_END")
	node.free()
	if observer.audit(13,0)!=0 or payload.get_ref()==null:
		fail("quarantine ran cleanup or released owned storage")
		return
	observer.free()
	print("INSTANCE_QUARANTINE_OK")
	quit()
