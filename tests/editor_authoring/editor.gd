@tool
extends Node

var root: Window

var dialog: ScriptCreateDialog

func _ready() -> void:
	root = get_tree().root
	call_deferred("run")

func make_script(base: String, filename: String, handle: String) -> Script:
	dialog.config(base, "res://scripts/" + filename + ".odin", false, false)
	for menu in dialog.find_children("*", "OptionButton", true, false):
		for index in menu.item_count:
			if menu.get_item_text(index) == "Odin":
				menu.select(index)
				menu.item_selected.emit(index)
	dialog.config(base, "res://scripts/" + filename + ".odin", false, false)
	dialog.popup_centered()
	await get_tree().process_frame
	assert(not dialog.get_ok_button().disabled, "Create Script rejected " + filename)
	var created: Array[Script] = []
	var receive := func(script: Script): created.append(script)
	dialog.script_created.connect(receive)
	dialog.get_ok_button().pressed.emit()
	dialog.script_created.disconnect(receive)
	assert(created.size() == 1, "Create Script did not create " + filename)
	var text := created[0].source_code
	assert(text.contains("owner: gd." + handle), text)
	assert(text.contains("package editor_fixture"), "Template must adopt the existing package")
	if base == "Resource" or base == "RefCounted":
		assert(not text.contains("_process"), "Resource templates must not imply node lifecycle")
	return created[0]

func editor_node() -> Node:
	var current: Node = EditorInterface.get_base_control()
	while current != null:
		if current.has_signal("script_add_function_request"):
			return current
		current = current.get_parent()
	return null

func declares(script: Script, method: String) -> bool:
	for entry in script.get_script_method_list():
		if entry.name == method:
			return true
	return false

func add_handler(target: Node, method: String, args: PackedStringArray, body: String, other: Script = null) -> void:
	if other != null:
		EditorInterface.edit_script(other)
		await get_tree().process_frame
		assert(EditorInterface.get_script_editor().get_current_script() == other)
	editor_node().emit_signal("script_add_function_request", target, method, args)
	await get_tree().process_frame
	var edit := EditorInterface.get_script_editor().get_current_editor().get_base_editor() as CodeEdit
	assert(edit.text.contains("gameplay_hud_" + method + " :: proc"), edit.text)
	edit.text = edit.text.replace("// Handle the signal.", body)
	var script: Script = target.get_script()
	script.source_code = edit.text
	assert(ResourceSaver.save(script) == OK)

func run() -> void:
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	dialog = ScriptCreateDialog.new()
	EditorInterface.get_base_control().add_child(dialog)
	var script: Script = await make_script("Node2D", "HUD_View", "Node2d")
	var item: Script = await make_script("Resource", "Item_Definition", "Resource")
	await make_script("CharacterBody3D", "Character", "Character_Body3d")
	await make_script("RefCounted", "Data", "Ref_Counted")
	await make_script("HTTPRequest", "Request", "Http_Request")
	var map_script: Script = await make_script("Node", "map", "Node")
	assert(map_script.source_code.contains("Map :: struct"), "Keyword filename needs a valid Odin type")
	var scene := Node2D.new()
	scene.name = "Game"
	scene.set_script(script)
	root.add_child(scene)
	EditorInterface.edit_script(script)
	await get_tree().process_frame
	var edit := EditorInterface.get_script_editor().get_current_editor().get_base_editor() as CodeEdit
	var code := edit.text.replace("HUD_View", "GameplayHUD").replace("hud_view_", "gameplay_hud_")
	code = code.replace("import gd ", "import g ").replace("gd.", "g.")
	var close := code.find("}", code.find("owner:"))
	code = code.insert(close, "hits: g.Int `gd:\"export\"`,\namount: g.Float `gd:\"export\"`,\nkind: g.Int `gd:\"export\"`,\n")
	code += "\n_on_helper :: proc() {}\n"
	edit.text = code # intentionally unsaved; callback must use this receiver/alias
	await add_handler(scene, "_on_button_pressed", [], "self.hits += 1")
	await add_handler(scene, "_on_value_changed", ["value:float"], "self.amount = value")
	await add_handler(scene, "_on_payload", ["value"], "self.kind = g.Int(value.type)", item)
	await add_handler(scene, "_on_body_entered", ["body:Node2D"], "if body != nil {self.hits += 10}")
	await add_handler(scene, "_on_helper", [], "self.hits += 100")
	var deadline := Time.get_ticks_msec() + 45000
	while not declares(script, "_on_helper"):
		assert(Time.get_ticks_msec() < deadline, "Generated callbacks did not build")
		await get_tree().process_frame
	# A second request navigates to the existing declaration, preserving source.
	var before := edit.text
	editor_node().emit_signal("script_add_function_request", scene, "_on_button_pressed", PackedStringArray())
	await get_tree().process_frame
	assert(edit.text == before, "Navigation duplicated the handler")
	var lines := edit.text.split("\n")
	var declaration := -1
	for index in lines.size():
		if lines[index].contains("gameplay_hud__on_button_pressed :: proc"):
			declaration = index
	assert(declaration >= 0 and edit.get_caret_line() == declaration + 1, "Callback navigation missed its body")
	var button := Button.new()
	button.name = "Button"
	scene.add_child(button)
	button.owner = scene
	button.pressed.connect(Callable(scene, "_on_button_pressed"), CONNECT_PERSIST)
	var value := SpinBox.new()
	value.name = "Value"
	scene.add_child(value)
	value.owner = scene
	value.value_changed.connect(Callable(scene, "_on_value_changed"), CONNECT_PERSIST)
	var emitter := Node.new()
	emitter.name = "Emitter"
	emitter.set_script(load("res://emitter.gd"))
	scene.add_child(emitter)
	emitter.owner = scene
	emitter.connect("payload", Callable(scene, "_on_payload"), CONNECT_PERSIST)
	emitter.connect("body_seen", Callable(scene, "_on_body_entered"), CONNECT_PERSIST)
	emitter.connect("helper", Callable(scene, "_on_helper"), CONNECT_PERSIST)
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	assert(ResourceSaver.save(packed, "res://game.tscn") == OK)
	dialog.queue_free()
	scene.queue_free()
	await get_tree().process_frame
	print("EDITOR_AUTHORING_UI_OK")
	get_tree().quit()
