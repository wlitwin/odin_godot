extends SceneTree

# Headless milestone test for Phase 2 of odin_godot.
# Run: $GODOT --headless --path tests/phase2 --script test_phase2.gd
#
# Verifies the compiled-dispatch heart: a Node2D with an attached `.odin` script has
# its Odin `_ready` run (sets initial position) and its Odin `_process(delta)` run
# every frame (moves the node), by stepping the SceneTree and asserting the node's
# position advances as the Odin code dictates. Bonus: pressing "ui_right" makes it
# move faster (input-driven movement).
#
# Prints PHASE2_OK on success, or PHASE2_FAIL: <reason>.

var node: Node2D
var script_res
var frames := 0
var setup_done := false
var done := false

var ready_x := INF        # position.x captured right after _ready
var baseline_x := INF     # x at start of the no-input window
var pre_input_x := INF    # x at end of no-input window / before pressing ui_right
var baseline_dx := 0.0    # displacement over the no-input window

func _init() -> void:
	process_frame.connect(_on_frame)

func _fail(reason: String) -> void:
	if done:
		return
	done = true
	print("PHASE2_FAIL: ", reason)
	quit(1)

func _on_frame() -> void:
	if done:
		return
	frames += 1

	# Frame 1: build the node, attach the .odin script, add to the tree.
	if not setup_done:
		setup_done = true
		if not ResourceLoader.exists("res://scripts/player.odin"):
			_fail("ResourceLoader does not recognize res://scripts/player.odin")
			return
		script_res = load("res://scripts/player.odin")
		if script_res == null:
			_fail("load(res://scripts/player.odin) returned null")
			return
		if script_res.get_instance_base_type() != "Node2D":
			_fail("base type is %s, expected Node2D" % str(script_res.get_instance_base_type()))
			return
		node = Node2D.new()
		node.set_script(script_res)
		root.add_child(node)
		return

	if node == null:
		_fail("node was freed unexpectedly")
		return

	# Frame 2: _ready has run. The Odin code set the initial position to (100, 50);
	# _process only ever moves x, so y must still be exactly 50 (proves _ready ran and
	# the cross-dll engine call worked), and x must be >= 100 (started at 100, drifting
	# right). If _ready had NOT run, position would be (0,0) and y would read 0.
	if frames == 2:
		ready_x = node.position.x
		if not is_equal_approx(node.position.y, 50.0):
			_fail("_ready did not set initial y=50 (cross-dll _ready not dispatched?); got %s" % str(node.position))
			return
		if node.position.x < 100.0:
			_fail("_ready did not set initial x=100; got x=%f" % node.position.x)
			return
		baseline_x = node.position.x
		return

	# Frames 3..5: no input. _process should drift the node to the right.
	if frames == 5:
		pre_input_x = node.position.x
		baseline_dx = pre_input_x - baseline_x
		if baseline_dx <= 0.0:
			_fail("_process did not advance position (dx=%f over no-input window)" % baseline_dx)
			return
		# Now drive input: hold ui_right. The Odin _process reads is_action_pressed and
		# adds a large velocity, so the node should move markedly faster.
		Input.action_press("ui_right")
		return

	# Frames 6..8: with ui_right held, displacement should exceed the baseline.
	if frames == 8:
		var input_dx := node.position.x - pre_input_x
		Input.action_release("ui_right")
		print("baseline_dx=%f input_dx=%f ready_x=%f final_x=%f" % [baseline_dx, input_dx, ready_x, node.position.x])
		if input_dx <= baseline_dx:
			# Core milestone still met (process moved the node); note the bonus miss.
			print("PHASE2_OK (note: input-driven speed-up not observed: input_dx=%f <= baseline_dx=%f)" % [input_dx, baseline_dx])
		else:
			print("PHASE2_OK")
		done = true
		quit(0)
		return
