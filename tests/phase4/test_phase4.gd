extends SceneTree

# Headless milestone test for Phase 4 of odin_godot: the HOT-RELOAD dev loop.
# Run: $GODOT --headless --path tests/phase4 --script test_phase4.gd
#
# Flow:
#   1. Build scripts v1 (done by run.sh). Instantiate a Node with reloader.odin,
#      run frames, assert v1 behavior: get_step()==10 and `process` advances the
#      exported `position` by 10/frame.
#   2. Set a known state (position = 1005) — a value whose +5 offset cannot be
#      produced by v2's step-of-100 alone, so it uniquely proves preservation.
#   3. Rebuild the scripts dll as v2 (STEP -> 100) via OS.execute (edit-save sim).
#   4. Trigger reload through the engine: `script.reload(true)` -> OdinScript._reload
#      -> core swaps the dll + re-binds the LIVE instance in place.
#   5. Assert v2 behavior AND preserved state: get_step()==100, position still 1005
#      immediately after reload, then advances by 100/frame (-> 1005 + 100*k).
#
# Prints PHASE4_OK on success, or PHASE4_FAIL: <reason>.

var done := false

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _fail(reason: String) -> void:
	if done:
		return
	done = true
	print("PHASE4_FAIL: ", reason)
	quit(1)

func _run() -> void:
	if done:
		return

	if not ResourceLoader.exists("res://scripts/reloader.odin"):
		_fail("ResourceLoader does not recognize res://scripts/reloader.odin")
		return
	var script = load("res://scripts/reloader.odin")
	if script == null:
		_fail("reloader.odin failed to load")
		return
	if script.get_instance_base_type() != "Node":
		_fail("reloader base type is %s, expected Node" % str(script.get_instance_base_type()))
		return
	var toggle_script = load("res://scripts/lifecycle_toggle.odin")
	if toggle_script == null:
		_fail("lifecycle_toggle.odin failed to load")
		return

	# ---- build the live instance ----
	var node := Node.new()
	node.set_script(script)
	root.add_child(node)
	var toggle := Node.new()
	toggle.set_script(toggle_script)
	root.add_child(toggle)

	# ===== 1. assert v1 behavior =====
	var step_v1 = node.call("get_step")
	if int(step_v1) != 10:
		_fail("v1 get_step()=%s, expected 10" % str(step_v1))
		return

	# let `process` tick a few frames
	await process_frame
	await process_frame
	var moved = int(node.get("position"))
	if moved <= 0 or (moved % 10) != 0:
		_fail("v1 process did not advance position by steps of 10: position=%d" % moved)
		return

	# v1 exposes only _physics_process. Fresh-instance setup must enable it without
	# accidentally enabling the absent idle-process callback.
	await physics_frame
	await physics_frame
	if int(toggle.call("get_mode")) != 1:
		_fail("lifecycle fixture did not start in physics-only v1")
		return
	if int(toggle.get("physics_ticks")) <= 0:
		_fail("v1 physics callback was not enabled")
		return
	if int(toggle.get("process_ticks")) != 0:
		_fail("v1 absent process callback ran unexpectedly")
		return

	# ===== 2. set preserved state =====
	node.set("position", 1005)
	if int(node.get("position")) != 1005:
		_fail("could not set position=1005 (got %d)" % int(node.get("position")))
		return

	# ===== 3. rebuild scripts dll as v2 (edit-save simulation) =====
	var out := []
	var code := OS.execute("bash", [ProjectSettings.globalize_path("res://rebuild_v2.sh")], out, true)
	if code != 0:
		_fail("v2 rebuild failed (exit %d): %s" % [code, "\n".join(out)])
		return

	# ===== 4. trigger reload through the engine =====
	# `Script.reload(keep_state)` routes to OdinScript._reload, which swaps the dll
	# and re-binds this live instance in place. No frame elapses across this call.
	var err = script.reload(true)
	if err != OK:
		_fail("script.reload(true) returned error %s" % str(err))
		return

	# ===== 5a. v2 behavior is now live (method returns the new value) =====
	var step_v2 = node.call("get_step")
	if int(step_v2) != 100:
		_fail("after reload get_step()=%s, expected 100 (v2 not live)" % str(step_v2))
		return
	if int(toggle.call("get_mode")) != 2:
		_fail("lifecycle fixture did not rebind to process-only v2")
		return

	# ===== 5b. state preserved across the reload (no tick since the swap) =====
	var preserved = int(node.get("position"))
	if preserved != 1005:
		_fail("state NOT preserved across reload: position=%d, expected 1005" % preserved)
		return

	# ===== 5c. v2 `process` now runs on the SAME instance, off the preserved base =====
	await process_frame
	await process_frame
	var after = int(node.get("position"))
	# 1005 + 100*k proves: base 1005 preserved AND v2 step (100) applied.
	if after <= 1005 or ((after - 1005) % 100) != 0:
		_fail("v2 process did not advance preserved state by steps of 100: position=%d (was 1005)" % after)
		return

	# The same live node must now receive idle process and stop receiving physics.
	var physics_at_swap := int(toggle.get("physics_ticks"))
	await process_frame
	await process_frame
	if int(toggle.get("process_ticks")) <= 0:
		_fail("reload added _process but did not enable it on the live node")
		return
	await physics_frame
	await physics_frame
	if int(toggle.get("physics_ticks")) != physics_at_swap:
		_fail("reload removed _physics_process but left it enabled on the live node")
		return

	print("PHASE4_OK")
	done = true
	quit(0)
