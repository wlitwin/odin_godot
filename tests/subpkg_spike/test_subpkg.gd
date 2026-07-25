extends SceneTree

# Headless spike test for SCRIPT SUBPACKAGES (annotated classes in subfolders of a
# module). Run: $GODOT --headless --path tests/subpkg_spike --script test_subpkg.gd
#
# Asserts, in order:
#   1. A script in a SUBFOLDER is attachable: res://scripts/ui/hud.odin loads, reports
#      its base type, attaches, and runs its lifecycle — which only happens if the
#      generated `@(init)` registration in ui/odin_godot_scripts.gen.odin actually ran,
#      i.e. if the root guard's `import _ "ui"` manifest linked the package.
#   2. The engine-native surface works from a subpackage: `gd:"export"` fields round
#      trip through the Inspector API, @(gd_method) trampolines answer Object::call,
#      and a typed signal declared there emits.
#   3. One dll, three packages: the module root reads the subpackage class TYPED via
#      rt.script_of(node, ui.Hud) — no engine round trip — and the class check still
#      returns nil for the wrong class across packages.
#   4. A pure helper subpackage (util/) is shared by BOTH the root and ui/.
#   5. RELOAD of a subpackage script: rebuilding with -define:HUD_V=2 and reloading the
#      SUBFOLDER script swaps the module's dll — new behavior, instance state preserved,
#      package globals reset — and the root class keeps its own state and keeps ticking.
#
# Prints SUBPKG_SPIKE_MAIN_OK on success (run.sh adds the generated-layout assertions
# and the four negative scriptgen phases, then prints the sentinel SUBPKG_SPIKE_OK).

var done := false

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _fail(reason: String) -> void:
	if done:
		return
	done = true
	print("SUBPKG_SPIKE_FAIL: ", reason)
	quit(1)

func _run() -> void:
	if done:
		return

	# ---- load the root class and the SUBFOLDER class ----
	var game_script = load("res://scripts/game.odin")
	if game_script == null:
		_fail("game.odin failed to load")
		return
	var hud_script = load("res://scripts/ui/hud.odin")
	if hud_script == null:
		_fail("res://scripts/ui/hud.odin failed to load (subfolder script not attachable)")
		return
	if hud_script.get_instance_base_type() != "Node":
		_fail("Hud base type is %s, expected Node" % str(hud_script.get_instance_base_type()))
		return

	# ---- attach both ----
	var game := Node.new()
	game.set_script(game_script)
	root.add_child(game)
	var hud := Node.new()
	hud.set_script(hud_script)
	root.add_child(hud)

	# ===== 1. the subpackage class is REGISTERED (the import manifest linked it) =====
	await process_frame
	await process_frame
	if int(game.get("ready_mark")) != 1:
		_fail("Game _ready did not run (module root lifecycle)")
		return
	if int(hud.get("ready_mark")) != 1:
		_fail("Hud _ready did not run — the subpackage's registration never linked")
		return

	# ===== 2. engine-native surface from a subpackage =====
	hud.set("shown", 0)
	if int(hud.call("bump")) != 10:
		_fail("Hud.bump()=%s, expected 10 (v1 GAIN)" % str(hud.call("bump")))
		return
	if int(hud.get("shown")) != 10:
		_fail("Hud exported field did not round trip: shown=%d" % int(hud.get("shown")))
		return
	var seen := []
	hud.connect("bumped", func(v): seen.append(int(v)))
	hud.call("bump")
	if seen != [20]:
		_fail("typed signal declared in a subpackage did not emit 20: %s" % str(seen))
		return

	# ===== 3. one dll, three packages: TYPED cross-package access =====
	if int(game.call("read_hud", hud)) != 20:
		_fail("rt.script_of(node, ui.Hud) from the module root read %s, expected 20" % str(game.call("read_hud", hud)))
		return
	if int(game.call("probe", hud)) != 1:
		_fail("script_of class check across packages violated (cross non-nil or self nil)")
		return

	# ===== 4. the pure helper subpackage is shared by root and ui/ =====
	if int(game.call("step")) != 7 or int(hud.call("base")) != 7:
		_fail("util/ not shared: game.step()=%s hud.base()=%s, both expected 7" % [str(game.call("step")), str(hud.call("base"))])
		return

	# ===== 5. reload of a SUBFOLDER script =====
	hud.set("shown", 505)
	game.set("score", 55)
	var ticks_before := int(game.get("ticks"))
	if int(hud.call("updates_count")) <= 0:
		_fail("subpackage package global did not record the bumps")
		return

	var out := []
	var code := OS.execute("bash", [ProjectSettings.globalize_path("res://rebuild_hud_v2.sh")], out, true)
	if code != 0:
		_fail("HUD v2 rebuild failed (exit %d): %s" % [code, "\n".join(out)])
		return

	var err = hud_script.reload(true)
	if err != OK:
		_fail("hud_script.reload(true) returned %s" % str(err))
		return

	if int(hud.call("gain")) != 100:
		_fail("after reload Hud gain()=%s, expected 100 (v2 not live)" % str(hud.call("gain")))
		return
	if int(hud.get("shown")) != 505:
		_fail("Hud state NOT preserved across the reload: shown=%d, expected 505" % int(hud.get("shown")))
		return
	if int(hud.call("bump")) != 605:
		_fail("v2 Hud did not step preserved state by 100: %s" % str(hud.get("shown")))
		return
	# Documented semantics: the swapped dll's package globals reset — including a
	# SUBPACKAGE's, which lives in the same dll.
	if int(hud.call("updates_count")) != 1:
		_fail("subpackage global expected to reset on the module reload, updates=%s" % str(hud.call("updates_count")))
		return
	if int(game.get("score")) != 55:
		_fail("Game state lost across the reload: score=%d, expected 55" % int(game.get("score")))
		return
	await process_frame
	if int(game.get("ticks")) <= ticks_before:
		_fail("Game stopped ticking after the reload")
		return

	print("SUBPKG_SPIKE_MAIN_OK")
	done = true
	quit(0)
