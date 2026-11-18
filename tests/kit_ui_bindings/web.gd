extends Node
func need(ok: bool, message: String) -> bool:
	if not ok:
		push_error("KIT_UI_WEB_FAIL: " + message)
		get_tree().quit(1)
	return ok
func _ready():
	if not need(ClassDB.class_exists("OdinKitUIBindings"),"native component missing"): return
	var probe := Node.new()
	probe.set_script(load("res://scripts/probe.odin"))
	add_child(probe)
	var lobby: PackedScene = load("res://templates/lobby.tscn")
	var chat: PackedScene = load("res://templates/chat.tscn")
	var score: PackedScene = load("res://templates/scoreboard.tscn")
	var root_grid := GridContainer.new()
	var root_bindings = ClassDB.instantiate("OdinKitUIBindings")
	root_grid.add_child(root_bindings)
	root_bindings.owner = root_grid
	root_bindings.set("widget",2)
	root_bindings.set("grid",NodePath(".."))
	if not need(probe.validate(root_grid,2)=="","widget root binding"): return
	root_grid.free()
	var node := lobby.instantiate()
	if not need(probe.validate(node,0)=="","template resolution"): return
	node.get_node("Column/Host").free()
	var wrong := Label.new()
	wrong.name = "Host"
	node.get_node("Column").add_child(wrong)
	wrong.owner = node
	node.get_node("Bindings").set("host",NodePath("../Column/Host"))
	var diagnostic: String = probe.validate(node,0)
	if not need(diagnostic.contains("must be Button; found Label"),diagnostic): return
	node.free()
	if not need(probe.attach(lobby,chat,score)==0,"standard widget startup"): return
	await get_tree().process_frame
	await get_tree().process_frame
	if not need(probe.get_child_count()==0,"widget cleanup"): return
	probe.free()
	print("KIT_UI_WEB_PASS")
	get_tree().quit()
