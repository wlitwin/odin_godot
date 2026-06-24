extends SceneTree

# Headless milestone test for Phase 3 of odin_godot: the full GDScript-parity surface.
# Run: $GODOT --headless --path tests/phase3 --script test_phase3.gd
#
# Drives the compiled `.odin` scripts (Ping / Counter / ToolProbe) and asserts:
#   1. @export    : an exported var round-trips GDScript<->Odin (set/get + Odin reads it).
#   2. method     : custom methods (multi-arg int + float arg/return) reach Odin and return.
#   3. signal     : an Odin-declared signal connects from GDScript and delivers a payload.
#   4. extends    : a non-Node2D base (RefCounted) constructs + calls.
#   5. @tool      : a //gd:tool script reports is_tool() == true.
#
# Prints PHASE3_OK on success, or PHASE3_FAIL: <reason>.

var done := false
var pinged_value := -1
var pinged_count := 0

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _fail(reason: String) -> void:
	if done:
		return
	done = true
	print("PHASE3_FAIL: ", reason)
	quit(1)

func _on_pinged(value: int) -> void:
	pinged_value = value
	pinged_count += 1

func _run() -> void:
	if done:
		return

	# ---- load scripts ----
	if not ResourceLoader.exists("res://scripts/ping.odin"):
		_fail("ResourceLoader does not recognize res://scripts/ping.odin")
		return
	var ping_script = load("res://scripts/ping.odin")
	var counter_script = load("res://scripts/counter.odin")
	var tool_script = load("res://scripts/tool_probe.odin")
	if ping_script == null or counter_script == null or tool_script == null:
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
	# Odin must observe the GDScript-written value (get_speed() reads the struct field).
	var odin_sees = node.call("get_speed")
	if not is_equal_approx(odin_sees, 3.5):
		_fail("Odin did not see GDScript-written @export: get_speed()=%s" % str(odin_sees))
		return
	# Bonus: the export appears in the property list.
	var found_speed := false
	var found_count := false
	for p in node.get_property_list():
		if p["name"] == "speed":
			found_speed = true
		if p["name"] == "count":
			found_count = true
	var prop_list_note := "" if (found_speed and found_count) else " (note: get_property_list missing exports)"

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

	print("PHASE3_OK", prop_list_note)
	done = true
	quit(0)
