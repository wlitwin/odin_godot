extends SceneTree
var probe: Node
func check(ok: bool, message: String) -> bool:
	if not ok:
		printerr("KIT_UI_RUNTIME_FAIL: " + message)
		quit(1)
	return ok
func _initialize():
	call_deferred("run")
func packed(node: Node) -> PackedScene:
	var scene = PackedScene.new()
	if scene.pack(node) != OK:
		printerr("KIT_UI_RUNTIME_FAIL: pack")
		quit(1)
	return scene
func new_probe() -> Node:
	var node := Node.new()
	node.set_script(load("res://scripts/probe.odin"))
	return node
func report(node: Node, kind: int = 0) -> String:
	return probe.validate(node, kind)
func run():
	# Custom SceneTree scripts start with a 64x64 headless window.
	root.size = Vector2i(640,480)
	if not check(ClassDB.class_exists("OdinKitUIBindings"), "native component unavailable"): return
	probe = new_probe()
	root.add_child(probe)
	var lobby: PackedScene = load("res://templates/lobby.tscn")
	var chat: PackedScene = load("res://templates/chat.tscn")
	var score: PackedScene = load("res://templates/scoreboard.tscn")
	for pair in [[lobby, 0], [chat, 1], [score, 2], [load("res://inherited.tscn"),0]]:
		var node: Node = pair[0].instantiate()
		if not check(report(node, pair[1]).is_empty(), report(node,pair[1])): return
		root.add_child(node)
		await process_frame
		if pair[1] == 0:
			var button := node.get_node("Column/Host") as Button
			if not check(button.get_global_rect().size.x > 0 and button.get_global_rect().size.y > 0 and root.get_visible_rect().encloses(button.get_global_rect()),"template host button is outside the viewport"): return
		var saved = packed(node)
		var path = "res://saved-%s.tscn" % node.name
		if not check(ResourceSaver.save(saved,path)==OK,"save template"): return
		node.free()
		var reopened = ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
		if not check(report(reopened,pair[1]).is_empty(),"saved binding references changed"): return
		reopened.free()
	# A GridContainer can be the scoreboard root; no wrapper node is required.
	var root_grid := GridContainer.new()
	var root_bindings = ClassDB.instantiate("OdinKitUIBindings")
	root_grid.add_child(root_bindings)
	root_bindings.owner = root_grid
	root_bindings.set("widget",2)
	root_bindings.set("grid",NodePath(".."))
	if not check(report(root_grid,2).is_empty(),"widget root cannot fill a compatible role"): return
	root_grid.free()
	var node: Node = lobby.instantiate()
	var bindings: Node = node.get_node("Bindings")
	for index in 20000:
		if not check(bindings.get("widget") == 0 and bindings.get("host") == NodePath("%Host"), "native property return slot"): return
	var host: Node = node.get_node("Column/Host")
	host.name = "Renamed"
	if not check(report(node).contains(".host:") and report(node).contains("missing"),"rename diagnostic: " + report(node)): return
	bindings.set("host", NodePath("../Column/Renamed"))
	if not check(report(node).is_empty(),"explicit renamed reference"): return
	host.name = "Host"
	bindings.set("host",NodePath("%Host"))
	var decoration = Control.new()
	decoration.name = "Decoration"
	node.add_child(decoration)
	decoration.owner = node
	var duplicate = Button.new()
	duplicate.name = "Host"
	decoration.add_child(duplicate)
	duplicate.owner = node
	if not check(report(node).contains("matches 2"),"ambiguous unique reference: "+report(node)): return
	bindings.set("host",NodePath("../Column/Host"))
	if not check(report(node).is_empty(),"explicit reference amid duplicate names"): return
	decoration.free()
	var other = ClassDB.instantiate("OdinKitUIBindings")
	node.add_child(other)
	other.owner = node
	if not check(report(node).contains("found 2"),"duplicate component"): return
	other.free()
	host.free()
	var wrong = Label.new()
	wrong.name = "Host"
	node.get_node("Column").add_child(wrong)
	wrong.owner = node
	if not check(report(node).contains("must be Button; found Label"),"type diagnostic: "+report(node)): return
	node.free()
	node = lobby.instantiate()
	bindings = node.get_node("Bindings")
	bindings.set("code",NodePath(""))
	node.get_node("Column/Code").free()
	if not check(report(node).is_empty(),"absent optional Code"): return
	bindings.set("code",NodePath("../Column/Title"))
	if not check(report(node).contains("must be LineEdit; found Label"),"invalid optional Code"): return
	bindings.set("code",NodePath(""))
	bindings.set("join",NodePath("%Host"))
	if not check(report(node).contains("already assigned"),"duplicate target"): return
	bindings.set("join",NodePath("/root/Outside"))
	if not check(report(node).contains("relative node path"),"absolute reference"): return
	node.free()
	var custom_root = lobby.instantiate()
	custom_root.set_script(load("res://custom_root.gd"))
	var custom_scene = packed(custom_root)
	custom_root.free()
	var bad_chat_node = chat.instantiate()
	bad_chat_node.get_node("Input").free()
	var bad_chat = packed(bad_chat_node)
	bad_chat_node.free()
	if not check(ResourceSaver.save(bad_chat,"res://bad_chat.tscn")==OK,"bad chat fixture save"): return
	bad_chat = ResourceLoader.load("res://bad_chat.tscn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
	var bad_score_node = score.instantiate()
	bad_score_node.get_node("Panel/Margin/Grid").free()
	var bad_score = packed(bad_score_node)
	bad_score_node.free()
	if not check(ResourceSaver.save(bad_score,"res://bad_score.tscn")==OK,"bad score fixture save"): return
	bad_score = ResourceLoader.load("res://bad_score.tscn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
	var before := probe.get_child_count()
	var diagnostic: String = probe.prepare(custom_scene,bad_chat,bad_score)
	if not check(diagnostic.contains("Chat.input") and diagnostic.contains("Scoreboard.grid"),"complete preflight report: "+diagnostic): return
	if not check(probe.get_child_count()==before,"preflight published a node"): return
	if not check(diagnostic.contains("res://bad_chat.tscn") and diagnostic.contains("res://bad_score.tscn"),"closed scene paths missing"): return
	if not check(int(root.get_meta("kit_ui_custom_ready_count",0))==0,"preflight ran custom ready"): return
	print("KIT_UI_EXPECTED_REJECTION_BEGIN")
	var rejected: int = probe.attach(custom_scene,bad_chat,bad_score)
	print("KIT_UI_EXPECTED_REJECTION_END")
	if not check(rejected==1 and probe.process_mode==Node.PROCESS_MODE_DISABLED,"failed boot published state or left processing enabled"): return
	if not check(int(root.get_meta("kit_ui_custom_ready_count",0))==0,"failed boot ran custom ready"): return
	var frames: int = probe.frames()
	for ignored in 3:
		await process_frame
		await physics_frame
	if not check(probe.frames()==frames,"gameplay continued after failure"): return
	# A new instance is the supported recovery after fixing a scene.
	probe.free()
	probe = new_probe()
	root.add_child(probe)
	if not check(probe.attach(custom_scene,chat,score)==0,"valid boot adoption"): return
	if not check(int(root.get_meta("kit_ui_custom_ready_count",0))==1,"valid custom root script did not run"): return
	await process_frame
	await process_frame
	if not check(probe.get_child_count()==0,"boot teardown retained widget nodes"): return
	probe.free()
	print("KIT_UI_RUNTIME_OK")
	quit()
