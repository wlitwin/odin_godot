extends SceneTree

# ----------------------------------------------------------------------------
# Headless E2E for the ergonomic helper layer (godot/Ergonomics*.odin).
#
# `ergonomics.tscn` is a Node2D "Main" carrying tester.odin + a "Target" Label child. On
# _ready the Odin Tester runs EVERY non-signal helper against the real running scene and
# records a per-helper pass bitmask in its `result` @export. This driver:
#   1. instantiates the scene into the live tree (so _ready runs in-tree),
#   2. asserts the Odin-recorded bitmask has every bit set,
#   3. INDEPENDENTLY re-verifies the observable engine outcomes from GDScript
#      (Target.z_index/visible/text, the spawned Bullet child, group membership),
#   4. connects to the script-declared signals, then asks the Odin script to emit them
#      (emit_args WITH payload, emit zero-payload) and asserts the listeners fired.
#
# Prints ERGONOMICS_OK on success, or ERGONOMICS_FAIL: <which>.
# ----------------------------------------------------------------------------

var done := false
var pinged_value := -1
var pinged_count := 0
var triggered_count := 0
var scored_count := 0
var scored_args := []

const BIT_GET_NODE := 1 << 0
const BIT_GET_PARENT := 1 << 1
const BIT_GET_TREE := 1 << 2
const BIT_GROUP := 1 << 3
const BIT_SPAWN := 1 << 4
const BIT_INT := 1 << 5
const BIT_FLOAT := 1 << 6
const BIT_BOOL := 1 << 7
const BIT_STRING := 1 << 8
const BIT_NODES_IN_GROUP := 1 << 9
const BIT_FIRST_IN_GROUP := 1 << 10
const BIT_SCRIPTS_IN_GROUP := 1 << 11
const BIT_FIRST_SCRIPT := 1 << 12
const BIT_ARRAY_SLICE := 1 << 13

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _fail(reason: String) -> void:
	if done:
		return
	done = true
	print("ERGONOMICS_FAIL: ", reason)
	quit(1)

func _on_pinged(value: int) -> void:
	pinged_value = value
	pinged_count += 1

func _on_triggered() -> void:
	triggered_count += 1

func _on_scored(points: int, combo: int, streak: bool, mult: float, pos: Vector2) -> void:
	scored_count += 1
	scored_args = [points, combo, streak, mult, pos]

func _run() -> void:
	if done:
		return

	if not ResourceLoader.exists("res://ergonomics.tscn"):
		_fail("res://ergonomics.tscn not found"); return
	var scene = load("res://ergonomics.tscn").instantiate()
	if scene == null:
		_fail("failed to instantiate ergonomics.tscn"); return
	root.add_child(scene)        # _ready runs here, in-tree -> helpers operate on a real tree

	# Let _ready (which runs all the non-signal helpers) settle.
	await process_frame
	await process_frame

	# ===== 1. base type from //gd:extends =====
	if scene.get_script().get_instance_base_type() != "Node2D":
		_fail("Tester base = %s, expected Node2D" % str(scene.get_script().get_instance_base_type())); return

	# ===== 2. Odin-recorded per-helper bitmask =====
	var r := int(scene.get("result"))
	var checks := {
		"get_node": BIT_GET_NODE, "get_parent": BIT_GET_PARENT, "get_tree": BIT_GET_TREE,
		"add_to_group/is_in_group": BIT_GROUP, "spawn/load_scene/instantiate/add_child": BIT_SPAWN,
		"set_int/get_int": BIT_INT, "set_float/get_float": BIT_FLOAT,
		"set_bool/get_bool": BIT_BOOL, "set_string/get_string": BIT_STRING,
		"nodes_in_group": BIT_NODES_IN_GROUP, "first_in_group": BIT_FIRST_IN_GROUP,
		"rt.scripts_in_group": BIT_SCRIPTS_IN_GROUP,
		"rt.first_script_in_group": BIT_FIRST_SCRIPT,
		"array_unpack": BIT_ARRAY_SLICE,
	}
	for name in checks:
		if (r & checks[name]) == 0:
			_fail("helper bit not set: %s (result=%d)" % [name, r]); return

	# ===== 3. independent re-verification of observable outcomes =====
	var target = scene.get_node_or_null("Target")
	if target == null:
		_fail("Target child missing after _ready"); return
	if int(target.z_index) != 7:
		_fail("set_int did not stick: Target.z_index=%d (expected 7)" % int(target.z_index)); return
	if target.visible != false:
		_fail("set_bool did not stick: Target.visible=%s (expected false)" % str(target.visible)); return
	if String(target.text) != "hello":
		_fail("set_string did not stick: Target.text=%s (expected 'hello')" % str(target.text)); return
	if abs(float(target.rotation) - 0.5) > 0.01:
		_fail("set_float did not stick: Target.rotation=%f (expected ~0.5)" % float(target.rotation)); return

	# spawn really added a Bullet scene instance as a child of Main.
	var bullet = scene.get_node_or_null("Bullet")
	if bullet == null:
		_fail("spawn did not add a 'Bullet' child to the tree"); return

	# group membership is observable through the SceneTree group index.
	if not scene.is_in_group("ergo"):
		_fail("add_to_group not observable: Main not in group 'ergo'"); return

	# the iteration-test group holds exactly the two nodes the Odin side enrolled
	# (Tester + the script-less Bullet) — the same population its queries walked.
	var iter_members := get_nodes_in_group("ergo_iter")
	if iter_members.size() != 2:
		_fail("group 'ergo_iter' has %d members (expected 2)" % iter_members.size()); return

	# ===== 4. signals: connect, then ask the Odin script to emit =====
	if not scene.has_signal("pinged"):
		_fail("script signal 'pinged' missing"); return
	if not scene.has_signal("triggered"):
		_fail("script signal 'triggered' missing"); return
	if not scene.has_signal("scored"):
		_fail("script signal 'scored' (gd.SignalN) missing"); return

	# The SignalN payload struct's FIELD NAMES must be the registered arg names, with the
	# right Variant types, visible through the engine's own signal reflection.
	var scored_info = {}
	for sig in scene.get_signal_list():
		if sig["name"] == "scored":
			scored_info = sig
			break
	if scored_info.is_empty():
		_fail("'scored' not in get_signal_list()"); return
	var want_args := [
		["points", TYPE_INT], ["combo", TYPE_INT], ["streak", TYPE_BOOL],
		["mult", TYPE_FLOAT], ["pos", TYPE_VECTOR2],
	]
	var got_args: Array = scored_info["args"]
	if got_args.size() != want_args.size():
		_fail("'scored' has %d args (expected %d)" % [got_args.size(), want_args.size()]); return
	for i in want_args.size():
		if String(got_args[i]["name"]) != want_args[i][0]:
			_fail("'scored' arg %d named %s (expected %s)" % [i, got_args[i]["name"], want_args[i][0]]); return
		if int(got_args[i]["type"]) != int(want_args[i][1]):
			_fail("'scored' arg %s has type %d (expected %d)" % [want_args[i][0], got_args[i]["type"], want_args[i][1]]); return

	scene.connect("pinged", _on_pinged)
	scene.connect("triggered", _on_triggered)
	scene.connect("scored", _on_scored)

	scene.do_emit(42)            # gd.emit_args -> 'pinged' WITH payload 42
	scene.do_trigger()           # gd.emit      -> 'triggered' zero-payload
	scene.do_score()             # typed SignalN helper -> 'scored' with 5 named args
	await process_frame

	if pinged_count != 1 or pinged_value != 42:
		_fail("emit_args payload wrong: count=%d value=%d (expected 1, 42)" % [pinged_count, pinged_value]); return
	if triggered_count != 1:
		_fail("emit (zero-payload) did not fire: triggered_count=%d (expected 1)" % triggered_count); return
	if scored_count != 1 or scored_args != [10, 3, true, 1.5, Vector2(2, 4)]:
		_fail("SignalN emit wrong: count=%d args=%s (expected 1, [10, 3, true, 1.5, (2, 4)])" % [scored_count, str(scored_args)]); return

	print("ERGONOMICS: bitmask=0x%x; Target z_index=7 visible=false text='hello' rot~0.5; spawned Bullet; pinged=%d triggered=%d scored=%s" % [r, pinged_value, triggered_count, str(scored_args)])
	print("ERGONOMICS_OK")
	done = true
	quit(0)
