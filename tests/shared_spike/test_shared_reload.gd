extends SceneTree

# REBUILD-ON-SAVE for the SHARED tree, in ONE running editor process.
#
# Run: $GODOT --editor --headless --path tests/shared_spike --script test_shared_reload.gd
#
# res://shared/<pkg> belongs to no module, so the reload coordinator's per-module content
# hashes (core/reload.odin) would miss an edit there entirely and rebuild NOTHING — the
# save would look like it did nothing until a manual full build. The fix folds a hash of
# the whole shared tree into EVERY module's hash, so a shared edit invalidates them all.
#
# This driver proves exactly that, end to end:
#   1. Baseline: the main module (Game) and the `enemies` module (Enemy) — two dlls —
#      both report the shared constant STEP == 7.
#   2. Edit res://shared/ids/ids.odin on disk (STEP 7 -> 70) and call reload() on that
#      shared file, which is what saving it does (OdinScript._reload -> reload_request).
#   3. Poll until BOTH modules report 70 in this same process: both were rebuilt and both
#      dlls were swapped. Without the shared hash fold, reload_request skips both modules
#      ("authored sources unchanged") and this never happens.
#   4. Restore the source.
# Prints SHARED_RELOAD_OK.

const SHARED := "res://shared/ids/ids.odin"
const OLD := "STEP :: 7\n"
const NEW := "STEP :: 70\n"

var done := false
var original := ""

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _fail(reason: String) -> void:
	if done:
		return
	done = true
	if original != "":
		_write(original)
	print("SHARED_RELOAD_FAIL: ", reason)
	quit(1)

func _write(text: String) -> void:
	var f := FileAccess.open(SHARED, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()

func _run() -> void:
	if done:
		return
	if not bool(Engine.is_editor_hint()):
		_fail("not running with editor hint (need --editor); the rebuild-on-save path won't engage")
		return

	var game_script = load("res://scripts/game.odin")
	var enemy_script = load("res://modules/enemies/enemy.odin")
	if game_script == null or enemy_script == null:
		_fail("module scripts failed to load")
		return
	var game := Node.new()
	game.set_script(game_script)
	root.add_child(game)
	var enemy := Node.new()
	enemy.set_script(enemy_script)
	root.add_child(enemy)
	await process_frame

	# ===== 1. baseline: both dlls carry STEP == 7 =====
	if int(game.call("shared_step")) != 7 or int(enemy.call("shared_step")) != 7:
		_fail("baseline shared STEP: main=%s module=%s (expected 7/7 — stale build?)" % [str(game.call("shared_step")), str(enemy.call("shared_step"))])
		return

	# ===== 2. edit the SHARED source and save it =====
	var rf := FileAccess.open(SHARED, FileAccess.READ)
	if rf == null:
		_fail("could not read %s" % SHARED)
		return
	original = rf.get_as_text()
	rf.close()
	if original.find(OLD) == -1:
		_fail("shared source does not contain %s" % OLD.strip_edges())
		return
	_write(original.replace(OLD, NEW))

	var shared_script = load(SHARED)
	if shared_script == null:
		_fail("the shared source did not load as an Odin script resource")
		return
	var err = shared_script.reload(true)
	if err != OK:
		_fail("shared_script.reload(true) returned %s" % str(err))
		return

	# ===== 3. BOTH modules must rebuild + swap =====
	var main_live := false
	var module_live := false
	for i in range(6000): # the two module builds take seconds; polled every frame
		await process_frame
		if not main_live and int(game.call("shared_step")) == 70:
			main_live = true
		if not module_live and int(enemy.call("shared_step")) == 70:
			module_live = true
		if main_live and module_live:
			break

	# ===== 4. restore before asserting, so a failure never leaves the tree edited =====
	_write(original)

	if not main_live:
		_fail("the MAIN module did not pick up the shared edit (still %s)" % str(game.call("shared_step")))
		return
	if not module_live:
		_fail("the ENEMIES module did not pick up the shared edit (still %s)" % str(enemy.call("shared_step")))
		return

	print("SHARED_RELOAD_BOTH_SWAPPED (main + enemies rebuilt from ONE shared edit)")
	print("SHARED_RELOAD_OK")
	done = true
	quit(0)
