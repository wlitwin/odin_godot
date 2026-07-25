extends SceneTree

# Headless spike test for the SHARED VOCABULARY tree (res://shared/<pkg>, importable by
# every script module).
#
# Run: $GODOT --headless --path tests/shared_spike --script test_shared.gd
#
# Asserts, in order:
#   1. All three classes attach and run: Game (main module), Hud (a SUBPACKAGE of the
#      main module) and Enemy (the `enemies` module — a separate dll).
#   2. BOTH DLLS CARRY THE SAME VOCABULARY: the shared constant, the shared enum and the
#      shared pure proc give identical answers from the main module and from the module,
#      and a value DERIVED from the shared constant in a subpackage agrees too.
#   3. The shared payload STRUCT round-trips through the shared proc on both sides.
#   4. Cross-module communication is unchanged: the shared tree adds a vocabulary, not a
#      back door — Game still reaches Enemy only through the engine (Object::call).
#
# Prints SHARED_SPIKE_MAIN_OK on success (run.sh adds the reload, negative and bash
# phases, then the suite sentinel SHARED_SPIKE_OK).

const STEP := 7 # res://shared/ids/ids.odin

var done := false

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _fail(reason: String) -> void:
	if done:
		return
	done = true
	print("SHARED_SPIKE_FAIL: ", reason)
	quit(1)

func _run() -> void:
	if done:
		return

	# ---- load all three classes (two dlls, three packages) ----
	var game_script = load("res://scripts/game.odin")
	if game_script == null:
		_fail("game.odin failed to load")
		return
	var hud_script = load("res://scripts/ui/hud.odin")
	if hud_script == null:
		_fail("ui/hud.odin failed to load")
		return
	var enemy_script = load("res://modules/enemies/enemy.odin")
	if enemy_script == null:
		_fail("modules/enemies/enemy.odin failed to load")
		return

	var game := Node.new()
	game.set_script(game_script)
	root.add_child(game)
	var hud := Node.new()
	hud.set_script(hud_script)
	root.add_child(hud)
	var enemy := Node.new()
	enemy.set_script(enemy_script)
	root.add_child(enemy)

	# ===== 1. lifecycle across both dlls =====
	await process_frame
	await process_frame
	if int(game.get("ready_mark")) != 1:
		_fail("Game _ready did not run (main module)")
		return
	if int(hud.get("ready_mark")) != 1:
		_fail("Hud _ready did not run (main module subpackage)")
		return
	if int(enemy.get("ready_mark")) != 1:
		_fail("Enemy _ready did not run (enemies module)")
		return

	# ===== 2. the same vocabulary in both dlls =====
	var g_step := int(game.call("shared_step"))
	var h_step := int(hud.call("shared_step"))
	var e_step := int(enemy.call("shared_step"))
	print("shared STEP: main=%d subpackage=%d module=%d" % [g_step, h_step, e_step])
	if g_step != STEP or h_step != STEP or e_step != STEP:
		_fail("the shared constant differs across dlls: main=%d sub=%d module=%d (expected %d)" % [g_step, h_step, e_step, STEP])
		return
	# The shared pure proc + enum: brand(kind) == kind*100 + STEP, computed in each dll.
	if int(game.call("brand")) != 100 + STEP:
		_fail("main module brand()=%d, expected %d" % [int(game.call("brand")), 100 + STEP])
		return
	if int(enemy.call("brand")) != 200 + STEP:
		_fail("enemies module brand()=%d, expected %d" % [int(enemy.call("brand")), 200 + STEP])
		return
	if int(hud.call("brand")) != STEP:
		_fail("subpackage brand()=%d, expected %d" % [int(hud.call("brand")), STEP])
		return
	# A subpackage constant DERIVED from the shared one, read back in-dll by the root.
	if int(hud.call("gain")) != STEP * 2 or int(game.call("ui_gain")) != STEP * 2:
		_fail("derived subpackage constant disagrees: hud=%d game=%d (expected %d)" % [int(hud.call("gain")), int(game.call("ui_gain")), STEP * 2])
		return

	# ===== 3. the shared payload struct, built on both sides =====
	if int(game.call("pack", 5)) != 100 + STEP + 5:
		_fail("main module pack(5)=%d, expected %d" % [int(game.call("pack", 5)), 100 + STEP + 5])
		return
	if int(enemy.call("pack", 5)) != 200 + STEP + 5:
		_fail("enemies module pack(5)=%d, expected %d" % [int(enemy.call("pack", 5)), 200 + STEP + 5])
		return

	# ===== 4. cross-module call still goes through the ENGINE =====
	enemy.set("hp", 50)
	game.call("attack", enemy, 3)
	if int(enemy.get("hp")) != 47:
		_fail("cross-module attack: enemy hp=%d, expected 47" % int(enemy.get("hp")))
		return
	if int(enemy.call("hits")) != 1:
		_fail("the enemies module's OWN global did not record the hit (hits=%s)" % str(enemy.call("hits")))
		return

	print("SHARED_SPIKE_MAIN_OK")
	done = true
	quit(0)
