extends SceneTree

# Headless spike test for MULTI-MODULE scripts (one dll per script module).
# Run: $GODOT --headless --path tests/modules_spike --script test_modules.gd
#
# Asserts, in order:
#   1. Both modules' classes attach + run their lifecycle (ready/process) — the main
#      module (Player, libodinscripts.dylib) AND the enemies module (Enemy,
#      libodinscripts_enemies.dylib) are live in one process.
#   2. Cross-module communication through the ENGINE works: Player.attack calls
#      Enemy.take_hit by name (Object::call) and the enemy's exported hp changes.
#   3. script_of is MODULE-LOCAL: within a module it returns the typed struct; across
#      modules it returns nil by construction (no imports -> the other module's type
#      cannot even be named; the core's class check nils any same-name dodge).
#   4. PER-MODULE reload: rebuilding ONLY the enemies module (v2: STEP 10 -> 100) and
#      reloading the enemy script swaps ONLY that dll — Enemy behavior changes with
#      preserved instance state, while the Player instance keeps its state, keeps
#      ticking, keeps its module-global blackboard, and its reload hook never fires.
#
# Prints MODULES_SPIKE_MAIN_OK on success (run.sh adds log-level asserts + the
# collision/isolation phases, then prints the suite sentinel MODULES_SPIKE_OK).

var done := false

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _fail(reason: String) -> void:
	if done:
		return
	done = true
	print("MODULES_SPIKE_FAIL: ", reason)
	quit(1)

func _run() -> void:
	if done:
		return

	# ---- load both modules' scripts ----
	var player_script = load("res://scripts/player.odin")
	if player_script == null:
		_fail("player.odin failed to load")
		return
	var enemy_script = load("res://modules/enemies/enemy.odin")
	if enemy_script == null:
		_fail("enemy.odin failed to load")
		return
	if enemy_script.get_instance_base_type() != "Node":
		_fail("Enemy base type is %s, expected Node" % str(enemy_script.get_instance_base_type()))
		return

	# ---- attach both ----
	var player := Node.new()
	player.set_script(player_script)
	root.add_child(player)
	var enemy := Node.new()
	enemy.set_script(enemy_script)
	root.add_child(enemy)

	# ===== 1. lifecycle across both dlls =====
	await process_frame
	await process_frame
	if int(player.get("ready_mark")) != 1:
		_fail("Player _ready did not run (main module lifecycle)")
		return
	if int(enemy.get("ready_mark")) != 1:
		_fail("Enemy _ready did not run (enemies module lifecycle)")
		return
	var pos := int(enemy.get("position"))
	if pos <= 0 or (pos % 10) != 0:
		_fail("Enemy v1 process did not advance position by steps of 10: %d" % pos)
		return
	if int(player.get("ticks")) <= 0:
		_fail("Player process did not tick")
		return
	if int(player.call("get_brand")) != 1007:
		_fail("Player get_brand()=%s, expected 1007 (main module identity + blackboard)" % str(player.call("get_brand")))
		return
	if int(enemy.call("get_step")) != 10:
		_fail("Enemy v1 get_step()=%s, expected 10" % str(enemy.call("get_step")))
		return

	# ===== 2. cross-module call via the engine =====
	enemy.set("hp", 50)
	player.call("attack", enemy, 3)
	if int(enemy.get("hp")) != 47:
		_fail("cross-module attack: enemy hp=%d, expected 47" % int(enemy.get("hp")))
		return
	if int(enemy.call("get_kills")) != 1:
		_fail("enemies module-local global did not record the hit (kills=%s)" % str(enemy.call("get_kills")))
		return

	# ===== 3. script_of semantics (module-local; nil across modules) =====
	if int(player.call("probe", enemy)) != 1:
		_fail("script_of semantics from main module violated (cross non-nil or self nil)")
		return
	if int(enemy.call("probe", player)) != 1:
		_fail("script_of semantics from enemies module violated (cross non-nil or self nil)")
		return

	# ===== 4. per-module reload =====
	# Known state: values whose offsets can't be produced by v2 stepping alone.
	enemy.set("position", 1005)
	player.set("score", 55)
	player.call("add_bonus", 35) # main module blackboard: 7 + 35 -> brand 1042
	if int(player.call("get_brand")) != 1042:
		_fail("add_bonus did not reach the main module blackboard")
		return
	var ticks_before := int(player.get("ticks"))

	# Rebuild ONLY the enemies module as v2 (edit-save simulation).
	var out := []
	var code := OS.execute("bash", [ProjectSettings.globalize_path("res://rebuild_enemies_v2.sh")], out, true)
	if code != 0:
		_fail("enemies v2 rebuild failed (exit %d): %s" % [code, "\n".join(out)])
		return

	# Reload through the engine: routes to the module owning THIS script (enemies).
	var err = enemy_script.reload(true)
	if err != OK:
		_fail("enemy_script.reload(true) returned %s" % str(err))
		return

	# ---- enemies module: new behavior + preserved instance state ----
	if int(enemy.call("get_step")) != 100:
		_fail("after reload Enemy get_step()=%s, expected 100 (v2 not live)" % str(enemy.call("get_step")))
		return
	if int(enemy.get("position")) != 1005:
		_fail("Enemy state NOT preserved: position=%d, expected 1005" % int(enemy.get("position")))
		return
	# Documented semantics: the swapped module's OWN package globals reset (fresh dll).
	if int(enemy.call("get_kills")) != 0:
		_fail("enemies module global expected to RESET on its reload, kills=%s" % str(enemy.call("get_kills")))
		return

	# ---- main module: completely untouched ----
	if int(player.get("score")) != 55:
		_fail("Player state lost: score=%d, expected 55" % int(player.get("score")))
		return
	if int(player.call("get_brand")) != 1042:
		_fail("main module blackboard lost across enemies reload: brand=%s, expected 1042" % str(player.call("get_brand")))
		return

	# ---- both instances keep running: v2 stepping for Enemy, same ticking for Player ----
	await process_frame
	var after := int(enemy.get("position"))
	if after <= 1005 or ((after - 1005) % 100) != 0:
		_fail("Enemy v2 process did not advance preserved state by 100s: %d (was 1005)" % after)
		return
	if int(player.get("ticks")) <= ticks_before:
		_fail("Player stopped ticking after the enemies reload")
		return

	print("MODULES_SPIKE_MAIN_OK")
	done = true
	quit(0)
