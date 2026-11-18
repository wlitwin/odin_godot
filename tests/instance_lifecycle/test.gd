extends SceneTree
var observer: Node
func fail(message):
	push_error("INSTANCE_LIFETIME_FAIL: " + message)
	quit(1)
func make_probe(id: int, remove_during_exit := false) -> Node:
	var node := Node.new()
	node.set_script(load("res://scripts/probe.odin"))
	node.set("case_id",id)
	var resource := Resource.new()
	resource.resource_name = "retained"
	node.set("payload",resource)
	var child := Node.new()
	child.name="Child"
	child.set_script(load("res://child.gd"))
	child.remove_parent_script = remove_during_exit
	node.add_child(child)
	return node
func verify(id: int, exits: int, unregisters: int) -> bool:
	if observer.audit(id,0)!=1 or observer.audit(id,1)!=exits or observer.audit(id,2)!=unregisters or observer.audit(id,3)!=1 or observer.audit(id,4)!=1:
		fail("wrong final state for "+str(id))
		return false
	return true
func _initialize(): call_deferred("run")
func run():
	var source := Node.new()
	source.name="Source"
	source.set_script(load("res://source.gd"))
	root.add_child(source)
	observer=make_probe(0)
	root.add_child(observer)
	var parent := Node.new()
	root.add_child(parent)
	var node := make_probe(1)
	parent.add_child(node)
	await process_frame
	node.reparent(root)
	if observer.audit(1,0)!=0:
		fail("reparent finalized live instance")
		return
	node.free()
	if not verify(1,2,2): return
	# Script replacement has no tree-exit event; finalization still sees exports/children.
	node=make_probe(2)
	root.add_child(node)
	node.set_script(null)
	if not verify(2,0,0): return
	node.free()
	# A child exit removes its parent's script during predelete propagation.
	node=make_probe(3,true)
	root.add_child(node)
	node.free()
	if not verify(3,0,1): return
	# Never-entered nodes still own their exported resource and child nodes.
	node=make_probe(4)
	node.free()
	if not verify(4,0,0): return
	# Property accessors may retire the script and still finish using pinned storage.
	node=make_probe(0)
	node.set("case_id",5)
	if node.get("value")!=42 or observer.audit(5,5)!=42 or not verify(5,0,0): return
	node.free()
	node=make_probe(0)
	var old_ref = weakref(node.get("payload"))
	node.set("case_id",6)
	var next_resource := Resource.new()
	next_resource.resource_name="retained"
	var new_ref = weakref(next_resource)
	node.set("payload",next_resource)
	next_resource=null
	if observer.audit(6,5)!=1 or not verify(6,0,0): return
	if old_ref.get_ref()!=null or new_ref.get_ref()!=null:
		fail("retired resource setter retained an exported reference")
		return
	node.free()
	# Owned links disappear on replacement; pre-existing scene links remain.
	for id in [7,8]:
		node=make_probe(id)
		if id==7: source.connect("ping",Callable(node,"on_ping"))
		root.add_child(node)
		source.ping.emit(1)
		if observer.audit(id,6)!=1:
			fail("declared signal was not connected")
			return
		node.set_script(load("res://replacement.gd"))
		source.ping.emit(1)
		if node.hits!=(1 if id==7 else 0):
			fail("signal connection ownership mismatch")
			return
		node.free()
	if not observer.manual_policy():
		fail("manual/automatic ownership metadata")
		return
	var automatic := Node.new()
	automatic.set_script(load("res://scripts/automatic.odin"))
	root.add_child(automatic)
	var old_button = automatic.button()
	automatic.set_script(load("res://replacement.gd"))
	old_button.pressed.emit()
	if automatic.hits!=0 or not observer.auto_order():
		fail("automatic cleanup order or stale UI connection")
		return
	await process_frame
	if automatic.get_child_count()!=0:
		fail("automatic stack left child nodes after replacement")
		return
	automatic.free()
	var manual := Node.new()
	manual.set_script(load("res://scripts/manual.odin"))
	root.add_child(manual)
	manual.close()
	manual.close()
	manual.free()
	# The optional Steam adapter owns only the connections it created.
	Engine.register_singleton("Steam",source)
	source.connect("lobby_created",Callable(observer,"on_created"))
	if not observer.steam_open():
		fail("Steam subscription")
		return
	observer.steam_close()
	observer.steam_close()
	source.lobby_created.emit(1,2)
	source.lobby_joined.emit(1,2,false,0)
	source.join_requested.emit(1,2)
	if observer.audit(9,6)!=1 or observer.audit(10,6)!=0 or observer.audit(11,6)!=0:
		fail("Steam subscription destroyed borrowed or retained owned links")
		return
	source.disconnect("lobby_created",Callable(observer,"on_created"))
	Engine.unregister_singleton("Steam")
	observer.free()
	parent.free()
	source.free()
	print("INSTANCE_LIFETIME_OK")
	quit()
