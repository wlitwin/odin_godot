extends SceneTree

# Headless milestone test for Phase 3.5 of odin_godot: the CODEGEN pipeline.
# Run: $GODOT --headless --path tests/phase35 --script test_phase35.gd
#
# These scripts (Ping / Counter / ToolProbe / Mover) were authored in the NICE
# codegen form (struct tags + plain procs + //gd: markers); their registration was
# AUTO-EMITTED by scriptgen into odin_godot_scripts.gen.odin. This test asserts the SAME GDScript-
# parity surface Phase 3 did, proving codegen output == hand-written registration:
#   1. @export    : an exported var round-trips GDScript<->Odin (set/get + Odin reads it).
#   2. method     : custom @(gd_method) procs (multi-arg int + float arg/return) work.
#   3. signal     : an Odin-declared //gd:signal connects + delivers a payload.
#   4. extends    : a non-Node2D base (RefCounted) constructs + calls.
#   5. @tool      : a //gd:tool script reports is_tool() == true.
#   6. lifecycle  : a Node2D `process` proc (codegen-wrapped) runs each frame.
#   7. path identity: two marker-less Node scripts bind independently, with no global alias.
#
# Prints PHASE35_OK on success, or PHASE35_FAIL: <reason>.

var done := false
var pinged_value := -1
var pinged_count := 0

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _fail(reason: String) -> void:
	if done:
		return
	done = true
	print("PHASE35_FAIL: ", reason)
	quit(1)

func _on_pinged(value: int) -> void:
	pinged_value = value
	pinged_count += 1

func _run() -> void:
	if done:
		return

	if not ResourceLoader.exists("res://scripts/ping.odin"):
		_fail("ResourceLoader does not recognize res://scripts/ping.odin")
		return
	var ping_script = load("res://scripts/ping.odin")
	var counter_script = load("res://scripts/counter.odin")
	var tool_script = load("res://scripts/tool_probe.odin")
	var mover_script = load("res://scripts/mover.odin")
	var alpha_script = load("res://scripts/path_alpha.odin")
	var beta_script = load("res://scripts/path_beta.odin")
	if ping_script == null or counter_script == null or tool_script == null or mover_script == null or alpha_script == null or beta_script == null:
		_fail("a script resource failed to load")
		return

	if ping_script.get_instance_base_type() != "Node":
		_fail("ping base type is %s, expected Node" % str(ping_script.get_instance_base_type()))
		return

	# ---- build the Ping instance (Node base) ----
	var node := Node.new()
	node.set_script(ping_script)
	root.add_child(node)

	# ===== 1. @export round-trip =====
	node.set("speed", 3.5)
	var read_speed = node.get("speed")
	if not (read_speed is float) or not is_equal_approx(read_speed, 3.5):
		_fail("@export speed round-trip failed: set 3.5, got %s" % str(read_speed))
		return
	node.set("count", 7)
	if int(node.get("count")) != 7:
		_fail("@export count round-trip failed: set 7, got %s" % str(node.get("count")))
		return
	var odin_sees = node.call("get_speed")
	if not is_equal_approx(odin_sees, 3.5):
		_fail("Odin did not see GDScript-written @export: get_speed()=%s" % str(odin_sees))
		return

	# ===== 2. custom methods (multi-arg int + float arg/return) =====
	var add_res = node.call("add", 2, 3)
	if int(add_res) != 5:
		_fail("method add(2,3) returned %s, expected 5" % str(add_res))
		return
	var addf_res = node.call("addf", 1.5, 2.25)
	if not (addf_res is float) or not is_equal_approx(addf_res, 3.75):
		_fail("method addf(1.5,2.25) returned %s, expected 3.75" % str(addf_res))
		return

	# ===== 3. signal connect + emit with payload =====
	if not node.has_signal("pinged"):
		_fail("Object.has_signal('pinged') is false (script signal not exposed)")
		return
	var cerr := node.connect("pinged", _on_pinged)
	if cerr != OK:
		_fail("connect('pinged') failed with error %d" % cerr)
		return
	node.call("emit_ping", 42)
	if pinged_count != 1 or pinged_value != 42:
		_fail("signal not received correctly: count=%d value=%d (expected 1, 42)" % [pinged_count, pinged_value])
		return

	# ===== 4. extends a non-Node2D base (RefCounted) =====
	var c := RefCounted.new()
	c.set_script(counter_script)
	if counter_script.get_instance_base_type() != "RefCounted":
		_fail("counter base type is %s, expected RefCounted" % str(counter_script.get_instance_base_type()))
		return
	var inc1 = c.call("increment")
	if int(inc1) != 1:
		_fail("RefCounted-based Counter.increment() returned %s, expected 1" % str(inc1))
		return
	c.set("count", 10)
	if int(c.get("count")) != 10:
		_fail("Counter @export count round-trip failed: set 10, got %s" % str(c.get("count")))
		return
	var inc2 = c.call("increment")
	if int(inc2) != 11:
		_fail("Counter.increment() after set(10) returned %s, expected 11" % str(inc2))
		return

	# ===== 5. @tool =====
	if not tool_script.is_tool():
		_fail("//gd:tool script reports is_tool() == false")
		return
	if ping_script.is_tool():
		_fail("non-tool script reports is_tool() == true")
		return

	# ===== 6. Node2D base + codegen-wrapped `process` lifecycle =====
	if mover_script.get_instance_base_type() != "Node2D":
		_fail("mover base type is %s, expected Node2D" % str(mover_script.get_instance_base_type()))
		return
	var mover := Node2D.new()
	mover.set_script(mover_script)
	root.add_child(mover)
	# Let a few frames run so `process` (auto-wrapped by codegen) ticks.
	await process_frame
	await process_frame
	await process_frame
	if int(mover.get("ticks")) < 1:
		_fail("Node2D `process` lifecycle did not run: ticks=%s" % str(mover.get("ticks")))
		return

	# ===== 7. marker-less, same-base scripts bind by authored path =====
	if alpha_script.get_global_name() != &"" or beta_script.get_global_name() != &"":
		_fail("marker-less scripts unexpectedly entered the global class namespace")
		return
	var alpha := Node.new()
	alpha.set_script(alpha_script)
	root.add_child(alpha)
	var beta := Node.new()
	beta.set_script(beta_script)
	root.add_child(beta)
	if int(alpha.call("identity")) != 101:
		_fail("path_alpha.odin bound to the wrong descriptor")
		return
	if int(beta.call("identity")) != 202:
		_fail("path_beta.odin bound to the wrong descriptor")
		return

	print("PHASE35_OK")
	done = true
	quit(0)
