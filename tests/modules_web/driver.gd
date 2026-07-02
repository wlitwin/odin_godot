extends Node

# ----------------------------------------------------------------------------
# In-BROWSER driver for the MULTI-MODULE web test. Runs as the main scene of the web
# export, so it executes inside the wasm build in a real browser (Godot routes `print`
# to the JS console, which drive.mjs captures).
#
# The scene carries a main-module node (Player, res://scripts/player.odin) and a module
# node (Enemy, res://modules/enemies/enemy.odin) — both classes compiled into the ONE
# composed wasm. This driver asserts, in-browser:
#   1. both lifecycles ran (ready_mark exports; the Odin _ready procs also print
#      MODWEB_MAIN_RAN / MODWEB_MODULE_RAN to the console),
#   2. a CROSS-MODULE call through the engine works: Player.attack invokes
#      Enemy.take_hit by name (Object::call) and the enemy's exported hp changes.
# The deliberate duplicate-class collision (Contested, declared by BOTH modules) is
# asserted by drive.mjs from the console — its error is pushed by the core's error
# drain, not printable from here.
#
# Prints MODWEB_DRIVER_OK on success, MODWEB_FAIL: <reason> otherwise.
# ----------------------------------------------------------------------------

func _ready() -> void:
	# Defer so the engine finishes its first frame/boot before we drive.
	call_deferred("_run")

func _fail(reason: String) -> void:
	print("MODWEB_FAIL: ", reason)

func _run() -> void:
	var player := $Player
	var enemy := $Enemy
	if player == null or enemy == null:
		_fail("Player/Enemy node missing"); return

	# Let both _ready lifecycles run.
	await get_tree().process_frame
	await get_tree().process_frame

	if int(player.get("ready_mark")) != 1:
		_fail("Player _ready did not run (main module)"); return
	if int(enemy.get("ready_mark")) != 1:
		_fail("Enemy _ready did not run (enemies module)"); return

	# Cross-module call via the engine: Player.attack -> Enemy.take_hit by name.
	enemy.set("hp", 50)
	player.call("attack", enemy, 3)
	if int(enemy.get("hp")) != 47:
		_fail("cross-module attack: enemy hp=%d, expected 47" % int(enemy.get("hp"))); return
	print("MODWEB_CROSS_OK")

	print("MODWEB_DRIVER_OK")
