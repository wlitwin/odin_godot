@tool
extends Node
var root: Window
var owner_script: Script
var source: String
var node: Node
func fail(message):
	push_error("INSTANCE_RELOAD_FAIL: "+message)
	get_tree().quit(1)
func _ready():
	root=get_tree().root
	call_deferred("run")
func create_node() -> Node:
	var result := Node.new()
	result.set_script(owner_script)
	root.add_child(result)
	return result
func update_source(text: String):
	var file := FileAccess.open("res://scripts/owner.odin",FileAccess.WRITE)
	file.store_string(text)
	file.close()
	owner_script.source_code=text
	owner_script.reload(true)
func wait_live(version: int) -> bool:
	var deadline := Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if node.version()==version: return true
	return false
func wait_candidate(version: int) -> Node:
	var deadline := Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline:
		await get_tree().create_timer(0.2).timeout
		var candidate := create_node()
		if candidate.version()==version: return candidate
		candidate.set("left",0)
		candidate.free()
	return null
func run():
	owner_script=load("res://scripts/owner.odin")
	source=FileAccess.get_file_as_string("res://scripts/owner.odin")
	node=create_node()
	if node.value()!=1122:
		fail("initial state")
		return
	update_source(source.replace("return 1} // BODY_VERSION","return 2} // BODY_VERSION"))
	if not await wait_live(2) or node.value()!=1122:
		fail("body-only reload lost state")
		return
	print("INSTANCE_SAME_LAYOUT_PRESERVED")
	update_source(source.replace("return 1} // BODY_VERSION","return 3} // BODY_VERSION").replace("left, right: i64","right, left: i64"))
	var candidate = await wait_candidate(3)
	if candidate==null or node.version()!=2 or node.value()!=1122 or candidate.value()!=1122:
		fail("owned private-layout pinning")
		return
	candidate.free()
	node.free()
	print("INSTANCE_PRIVATE_LAYOUT_PINNED")
	# Core must not finalize a deletion that native Godot vetoes.
	EditorInterface.open_scene_from_path("res://guard.tscn")
	for ignored in 8: await get_tree().process_frame
	var guard := EditorInterface.get_edited_scene_root()
	var before: int = guard.count()
	print("EXPECTED_EDITED_ROOT_VETO_BEGIN")
	guard.free()
	print("EXPECTED_EDITED_ROOT_VETO_END")
	if not is_instance_valid(guard) or guard.count()!=before or not guard.has_node("Child"):
		fail("edited scene root veto destroyed state")
		return
	print("INSTANCE_NATIVE_VETO_PRESERVED")
	print("INSTANCE_RELOAD_OK")
	get_tree().quit()
