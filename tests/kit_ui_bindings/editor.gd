@tool
extends Node
var plugin: EditorPlugin
func check(ok: bool, message: String) -> bool:
	if not ok:
		printerr("KIT_UI_EDITOR_FAIL: " + message)
		get_tree().quit(1)
	return ok
func settle():
	for ignored in 8:
		await get_tree().process_frame
func warnings() -> String:
	var found := ""
	for tree in EditorInterface.get_base_control().find_children("*","Tree",true,false):
		var item: TreeItem = tree.get_root()
		while item != null:
			if item.get_text(0) == "Bindings":
				for button in item.get_button_count(0):
					found += item.get_button_tooltip_text(0,button) + "\n"
			item = item.get_next_in_tree()
	return found
func tools_item():
	for menu in EditorInterface.get_base_control().find_children("*","PopupMenu",true,false):
		for index in menu.item_count:
			if menu.get_item_text(index) == "Create Kit UI Scenes":
				return [menu,index]
	return []
func _ready():
	call_deferred("run")
func run():
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	if not check(EditorInterface.get_editor_paths().is_self_contained(),"editor preferences are not isolated"): return
	var entry = tools_item()
	if not check(not entry.is_empty(),"Tools menu discovery"): return
	entry[0].index_pressed.emit(entry[1])
	await settle()
	while EditorInterface.get_resource_filesystem().is_scanning(): await get_tree().process_frame
	for filename in ["lobby","chat","scoreboard"]:
		if not check(FileAccess.file_exists("res://ui/kit_%s.tscn" % filename),"template creation "+filename): return
	var initial := FileAccess.get_file_as_string("res://ui/kit_chat.tscn") + "\n; user edit preserved\n"
	var file := FileAccess.open("res://ui/kit_chat.tscn",FileAccess.WRITE)
	file.store_string(initial)
	file.close()
	entry[0].index_pressed.emit(entry[1])
	await settle()
	if not check(FileAccess.get_file_as_string("res://ui/kit_chat.tscn")==initial,"template command overwrote edits"): return
	EditorInterface.open_scene_from_path("res://ui/kit_lobby.tscn")
	await settle()
	var scene := EditorInterface.get_edited_scene_root()
	if not check(scene != null and scene.scene_file_path=="res://ui/kit_lobby.tscn","open template"): return
	var binding := scene.get_node("Bindings")
	EditorInterface.edit_node(binding)
	await settle()
	var host_property: Dictionary = {}
	for property in binding.get_property_list():
		if property.name == "host": host_property=property
		if not check(property.name != "grid","irrelevant scoreboard field exposed"): return
	if not check(host_property.get("type")==TYPE_NODE_PATH and host_property.get("hint")==PROPERTY_HINT_NODE_PATH_VALID_TYPES and host_property.get("hint_string")=="Button","typed Inspector picker"): return
	if not check(not warnings().contains("Kit UI"),"valid initial warnings: "+warnings()): return
	var host := scene.get_node("Column/Host")
	var manager := plugin.get_undo_redo()
	manager.create_action("Break Kit UI host",UndoRedo.MERGE_DISABLE,scene)
	manager.add_do_property(host,"name","Renamed")
	manager.add_undo_property(host,"name","Host")
	manager.commit_action()
	await settle()
	if not check(warnings().contains(".host:") and warnings().contains("missing"),"live rename warning: "+warnings()): return
	var history := manager.get_history_undo_redo(manager.get_object_history_id(scene))
	history.undo()
	await settle()
	if not check(not warnings().contains("Kit UI"),"Undo did not repair warning: "+warnings()): return
	host.unique_name_in_owner = false
	await settle()
	if not check(warnings().contains(".host:") and warnings().contains("missing"),"unique toggle warning did not refresh: "+warnings()): return
	host.unique_name_in_owner = true
	await settle()
	if not check(not warnings().contains("Kit UI"),"unique toggle repair: "+warnings()): return
	var column := scene.get_node("Column")
	binding.reparent(column)
	binding.owner = scene
	await settle()
	if not check(warnings().contains("direct child"),"nested component appeared valid: "+warnings()): return
	binding.reparent(scene)
	binding.owner = scene
	await settle()
	if not check(not warnings().contains("Kit UI"),"placement repair: "+warnings()): return
	EditorInterface.save_scene_as(scene.scene_file_path, false)
	await settle()
	var saved: PackedScene = ResourceLoader.load("res://ui/kit_lobby.tscn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
	var detached = saved.instantiate()
	if not check(detached.get_node("Bindings").get("host")==NodePath("%Host"),"saved reference"): return
	detached.free()
	var callback: Callable
	for connection in get_tree().get_signal_connection_list("tree_changed"):
		if connection.callable.get_object_id()==binding.get_instance_id(): callback=connection.callable
	if not check(callback.is_valid(),"native callback not found"): return
	EditorInterface.edit_node(scene)
	binding.free()
	await settle()
	if not check(not callback.is_valid(),"retained callback outlived native node"): return
	print("KIT_UI_EDITOR_OK")
	get_tree().quit()
