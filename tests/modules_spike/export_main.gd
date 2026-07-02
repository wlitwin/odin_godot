extends Node

# Export-mode smoke for MULTI-MODULE scripts — the main scene of the EXPORTED spike
# game (run.sh phase 4). The scene attaches BOTH modules' classes:
#   Player -> res://scripts/player.odin        (main module,   libodinscripts.dylib)
#   Enemy  -> res://modules/enemies/enemy.odin (enemies module, libodinscripts_enemies.dylib)
# and this script asserts both dlls are LIVE in the exported process — lifecycle ran,
# a module method returns its compiled-in value, and a cross-module engine call works.
# Prints EXPORT_MODULE_ENEMY_RAN + MODULES_EXPORT_ASSERT_OK; run.sh greps for both.

func _fail(reason: String) -> void:
	print("MODULES_EXPORT_FAIL: ", reason)
	get_tree().quit(1)

func _ready() -> void:
	# Children readied before us, but give _process a couple of frames too.
	await get_tree().process_frame
	await get_tree().process_frame
	var player := $Player
	var enemy := $Enemy

	# Lifecycle in BOTH dlls.
	if int(player.get("ready_mark")) != 1:
		_fail("Player _ready did not run (main module dll not live in the export)")
		return
	if int(enemy.get("ready_mark")) != 1:
		_fail("Enemy _ready did not run (enemies MODULE dll not live in the export)")
		return

	# A module method returning a compiled-in constant (v1 STEP): proves the exported
	# game is calling INTO the freshly export-built enemies dll.
	if int(enemy.call("get_step")) != 10:
		_fail("Enemy get_step()=%s, expected 10 (enemies module)" % str(enemy.call("get_step")))
		return
	if int(player.call("get_brand")) != 1007:
		_fail("Player get_brand()=%s, expected 1007 (main module)" % str(player.call("get_brand")))
		return

	# Cross-module call via the engine, in the exported game.
	enemy.set("hp", 50)
	player.call("attack", enemy, 3)
	if int(enemy.get("hp")) != 47:
		_fail("cross-module attack in export: enemy hp=%d, expected 47" % int(enemy.get("hp")))
		return

	print("EXPORT_MODULE_ENEMY_RAN step=", int(enemy.call("get_step")))
	print("MODULES_EXPORT_ASSERT_OK")
	get_tree().quit(0)
