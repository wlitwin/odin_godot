@tool
extends Node

# REBUILD-ON-SAVE for the SHARED tree, in ONE running editor process.
#
# Run through the acceptance EditorPlugin with SHARED_SPIKE_RELOAD=1.
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
var owned_nodes: Array[Node] = []

func _ready() -> void:
	_run.call_deferred()

func _fail(reason: String) -> void:
	if done:
		return
	done = true
	if original != "":
		_write(original)
	print("SHARED_RELOAD_FAIL: ", reason)
	_finish(1)

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
	get_tree().root.add_child(game)
	owned_nodes.append(game)
	var enemy := Node.new()
	enemy.set_script(enemy_script)
	get_tree().root.add_child(enemy)
	owned_nodes.append(enemy)
	await get_tree().process_frame

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
		await get_tree().process_frame
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
	done = true
	_finish(0)

func _finish(code: int) -> void:
	for node in owned_nodes:
		if is_instance_valid(node): node.queue_free()
	owned_nodes.clear()
	await get_tree().process_frame
	# Let the ordinary editor process detach script instances and finish any
	# source-restoration build before its normal shutdown path.
	var deadline := Time.get_ticks_msec() + 180000
	await get_tree().create_timer(0.25).timeout
	var services := get_tree().get_nodes_in_group("odin_editor")
	while not services.is_empty() and services[0].get_build_state() == 1 and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.1).timeout
	if not services.is_empty() and services[0].get_build_state() != 0:
		print("SHARED_RELOAD_FAIL: source restoration did not finish cleanly")
		code = 1
	if code == 0:
		print("SHARED_RELOAD_OK")
	get_tree().quit(code)
