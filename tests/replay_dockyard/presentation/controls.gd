extends SceneTree

# Exercise the production view and Input events without a physics or network
# runtime. Only the copied presentation and the control sink are supplied here.
class Driver extends Node3D:
	var role := "host"
	var value := {"phase":"Working","delivered":[false,false,false],"lost":[false,false,false]}
	var positions := {
		"robot_a":Vector3(0,.5,0),"robot_b":Vector3(8,.5,0),
		"cargo_a":Vector3(1,.5,0),"cargo_b":Vector3(3,.5,0),"cargo_long":Vector3(7,.5,0)}
	var command: Dictionary = {}
	func status() -> String:
		return JSON.stringify({"role":role})
	func online_status() -> String:
		return JSON.stringify({"enabled":true,"go":true})
	func presentation() -> String:
		var copy := value.duplicate(true)
		copy["bodies"]=[]
		for key in positions:
			var at: Vector3=positions[key]
			copy.bodies.append({"key":key,"position":[at.x,at.y,at.z],"rotation":[0,0,0,1]})
		return JSON.stringify(copy)
	func control(x: int, z: int, aim_x: int, aim_y: int, aim_z: int, grab: bool, pulse: bool) -> void:
		command={"move":Vector2i(x,z),"aim":Vector3i(aim_x,aim_y,aim_z),"grab":grab,"pulse":pulse}
	func visuals_ready() -> void:
		pass

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("exercise")

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)

func mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func aimed_at(driver: Driver, cargo: String) -> bool:
	var at: Vector3=driver.positions[cargo]*100
	return driver.command.grab and driver.command.aim==Vector3i(roundi(at.x),roundi(at.y),roundi(at.z))

func exercise() -> void:
	var driver := Driver.new()
	root.add_child(driver)
	var source: Node=load("res://content/world.tscn").instantiate()
	driver.add_child(source)
	var view: Node=load("res://view.gd").new()
	driver.add_child(view)
	view.set_process(false)
	view._process(0.0)
	check(not driver.command.grab,"idle does not grab")
	mouse(true)
	view._process(0.0)
	check(aimed_at(driver,"cargo_a"),"host grabs nearest cargo without number keys or mouse aiming")
	driver.positions.cargo_a=Vector3(2,.9,1)
	driver.positions.cargo_b=Vector3(.5,.5,0)
	view._process(0.0)
	check(aimed_at(driver,"cargo_a"),"hold follows the same moving load when another becomes nearer")
	key(KEY_3,true)
	view._process(0.0)
	check(aimed_at(driver,"cargo_a"),"number keys do not switch loads")
	key(KEY_3,false)
	mouse(false)
	view._process(0.0)
	check(not driver.command.grab and driver.command.aim==Vector3i.ZERO,"release clears magnet input")
	mouse(true)
	view._process(0.0)
	check(aimed_at(driver,"cargo_b"),"new hold selects the current nearest load")
	driver.value.lost[1]=true
	view._process(0.0)
	check(not driver.command.grab,"lost held load releases without switching to another load")
	mouse(false)
	view._process(0.0)
	driver.value.delivered[0]=true
	mouse(true)
	view._process(0.0)
	check(aimed_at(driver,"cargo_long"),"selection skips delivered and lost loads")
	driver.value.delivered[2]=true
	view._process(0.0)
	check(not driver.command.grab,"delivered held load releases")
	mouse(false)
	view._process(0.0)
	mouse(true)
	view._process(0.0)
	check(not driver.command.grab,"no available cargo produces no grab")
	mouse(false)
	view._process(0.0)
	driver.value.delivered=[false,false,false]
	driver.value.lost=[false,false,false]
	driver.role="client"
	mouse(true)
	view._process(0.0)
	check(aimed_at(driver,"cargo_long"),"client uses its own coral robot for nearest selection")
	view.menu_open=true
	view._process(0.0)
	check(not driver.command.grab,"crew menu suppresses grab")
	view.menu_open=false
	driver.positions.cargo_b=Vector3(8,.5,1)
	driver.positions.cargo_long=Vector3(5,.5,0)
	view._process(0.0)
	check(aimed_at(driver,"cargo_b"),"returning from crew menu clears the previous selection")
	view.settings_box.get_parent().show()
	view._process(0.0)
	check(not driver.command.grab,"settings suppress grab")
	view.settings_box.get_parent().hide()
	driver.role="observer"
	view._process(0.0)
	check(not driver.command.grab,"observer cannot grab")
	driver.role="host"
	driver.value.phase="Results"
	view._process(0.0)
	check(not driver.command.grab,"results clear selection")
	driver.value.phase="Working"
	key(KEY_D,true)
	key(KEY_SPACE,true)
	view._process(0.0)
	check(aimed_at(driver,"cargo_a"),"new job picks nearest cargo")
	check(driver.command.move!=Vector2i.ZERO and driver.command.pulse,"movement and boost remain available while hauling")
	key(KEY_D,false)
	key(KEY_SPACE,false)
	mouse(false)
	view._process(0.0)
	view.last_positions.clear()
	driver.positions.clear()
	mouse(true)
	view._process(0.0)
	check(not driver.command.grab,"missing presentation poses do not grab")
	mouse(false)
	# The longer grab instruction must still fit beside the crew controls.
	view.party_box.get_parent().show()
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(1024,768),Vector2i(800,600),Vector2i(3440,1440),Vector2i(720,1280)]:
		root.size=dimensions
		for _frame in range(4):
			await process_frame
		var help: Rect2=view.help_panel.get_global_rect()
		var crew: Rect2=view.party_box.get_parent().get_global_rect()
		check(root.get_visible_rect().grow(.5).encloses(help),"grab instructions fit viewport %s" % dimensions)
		check(not help.intersects(crew),"grab instructions do not overlap crew controls %s" % dimensions)
	driver.queue_free()
	await process_frame
	print("DOCKYARD_CONTROLS_TEST ",JSON.stringify({"result":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
