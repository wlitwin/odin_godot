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
	var victim_script = load("res://scripts/reload_victim.odin")
	if victim_script == null:
		_fail("reload_victim.odin failed to load")
		return
	var removed_script = load("res://scripts/removed_class.odin")
	if removed_script == null:
		_fail("removed_class.odin failed to load")
		return
	var proc_holder_script = load("res://scripts/proc_holder.odin")
	if proc_holder_script == null:
		_fail("proc_holder.odin failed to load")
		return

	# ---- build the live instance ----
	var node := Node.new()
	node.set_script(script)
	root.add_child(node)
	var toggle := Node.new()
	toggle.set_script(toggle_script)
	root.add_child(toggle)
	var victim := Node.new()
	victim.set_script(victim_script)
	root.add_child(victim)
	var removed := Node.new()
	removed.set_script(removed_script)
	root.add_child(removed)

	# ===== 1. assert v1 behavior =====
	var step_v1 = node.call("get_step")
	if int(step_v1) != 10:
		_fail("v1 get_step()=%s, expected 10" % str(step_v1))
		return
	if int(node.call("get_cached_step")) != 10:
		_fail("v1 cached procedure did not return 10")
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

	# ===== 3. rebuild scripts dll as v2 (edit-save simulation) =====
	var out := []
	var code := OS.execute("bash", [ProjectSettings.globalize_path("res://rebuild_v2.sh")], out, true)
	if code != 0:
		_fail("v2 rebuild failed (exit %d): %s" % [code, "\n".join(out)])
		return

	# ===== 4. trigger reload through the engine =====
	# `Script.reload(keep_state)` routes to OdinScript._reload, which swaps the dll
	# and re-binds this live instance in place. Hold an old-generation method open on a
	# worker thread first: reload must drain that call rather than racing its trampoline.
	var worker := Thread.new()
	var thread_err := worker.start(Callable(node, "hold_reload_reader").bind(500))
	if thread_err != OK:
		_fail("could not start reload reader thread: %s" % str(thread_err))
		return
	await create_timer(0.075).timeout
	# Set the preservation sentinel AFTER the await (the v1 process callback ticks while
	# the timer runs), immediately before the synchronous swap.
	node.set("position", 1005)
	if int(node.get("position")) != 1005:
		worker.wait_to_finish()
		_fail("could not set position=1005 (got %d)" % int(node.get("position")))
		return
	var reload_started := Time.get_ticks_msec()
	var err = script.reload(true)
	var reload_elapsed := Time.get_ticks_msec() - reload_started
	worker.wait_to_finish()
	if err != OK:
		_fail("script.reload(true) returned error %s" % str(err))
		return
	if reload_elapsed < 250:
		_fail("reload did not drain the in-flight script call (returned in %dms)" % reload_elapsed)
		return
	print("RELOAD_READER_DRAINED (%dms)" % reload_elapsed)
	if is_instance_valid(victim):
		_fail("reload victim survived its synchronous reload-hook free")
		return
	print("RELOAD_SNAPSHOT_FREE_SAFE")

	# ===== 5a. v2 behavior is now live (method returns the new value) =====
	var step_v2 = node.call("get_step")
	if int(step_v2) != 100:
		_fail("after reload get_step()=%s, expected 100 (v2 not live)" % str(step_v2))
		return
	if int(toggle.call("get_mode")) != 2:
		_fail("lifecycle fixture did not rebind to process-only v2")
		return
	if int(node.call("get_cached_step")) != 100:
		_fail("reload hook did not refresh the cached procedure to v2")
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

	# ===== 6. a second generation: removed class + unacknowledged proc state =====
	# Instantiate the no-reload-hook callback holder from v2. It must remain callable
	# on v2 after v3 arrives instead of being rebound with a stale proc pointer.
	var proc_holder := Node.new()
	proc_holder.set_script(proc_holder_script)
	root.add_child(proc_holder)
	if int(proc_holder.call("cached_value")) != 200:
		_fail("v2 proc holder did not initialize its cached callback")
		return

	var out_v3 := []
	var code_v3 := OS.execute("bash", [ProjectSettings.globalize_path("res://rebuild_v3_remove.sh")], out_v3, true)
	if code_v3 != 0:
		_fail("v3/remove rebuild failed (exit %d): %s" % [code_v3, "\n".join(out_v3)])
		return
	var err_v3 = script.reload(true)
	if err_v3 != OK:
		_fail("second script.reload(true) returned error %s" % str(err_v3))
		return

	# The acknowledged callback state moved to v3 and was refreshed by its hook.
	if int(node.call("get_step")) != 1000 or int(node.call("get_cached_step")) != 1000:
		_fail("reload-safe callback state did not move to v3")
		return
	# The deleted class still runs from v2 while its live instance owns that image.
	if int(removed.call("value")) != 4242:
		_fail("removed live class lost its owning generation")
		return
	# No reload hook means no rebind: both method and cached callback stay coherently v2.
	if int(proc_holder.call("compiled_value")) != 200 or int(proc_holder.call("cached_value")) != 200:
		_fail("callback-bearing class without reload hook did not remain coherently on v2")
		return

	var native_ext := ".dylib"
	if OS.get_name() == "Windows":
		native_ext = ".dll"
	elif OS.get_name() == "Linux":
		native_ext = ".so"
	var v2_copy := ProjectSettings.globalize_path("res://bin/libodinscripts%s.r1%s" % [native_ext, native_ext])
	if not FileAccess.file_exists(v2_copy):
		_fail("v2 reload copy disappeared while removed/callback instances still owned it")
		return

	# Releasing the final two v2 owners collects the retired image immediately at the
	# execution writer gate and removes its unique on-disk copy.
	removed.free()
	proc_holder.free()
	if FileAccess.file_exists(v2_copy):
		_fail("v2 reload copy remained after its final generation owners were freed")
		return
	print("RELOAD_GENERATION_OWNERSHIP_OK")

	print("PHASE4_OK")
	done = true
	quit(0)
