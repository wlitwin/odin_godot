extends Node2D

# ----------------------------------------------------------------------------
# In-BROWSER driver for the pure-Odin coin-collector showcase.
#
# This runs as the main scene of the web export, so it executes inside the wasm build in a
# real browser (Godot routes `print` to the JS console, which drive.mjs captures). Unlike
# the headless test_showcase.gd (a `--script` SceneTree), this is a live Node: it drives
# the SAME real game loop programmatically (no keyboard input, which is impractical
# headless) by moving the Player ONTO a Coin and stepping PHYSICS so the Area2D's
# `body_entered` fires NATURALLY -> Odin `collect` -> shared score increments ->
# `collected` signal emitted -> coin freed. It asserts the cross-script HUD reflects the
# new score.
#
# Prints `SHOWCASE_WEB_OK score=<n> value=<v>` on a real physics-driven collect with an
# incremented score, or `SHOWCASE_WEB_FAIL: <reason>` otherwise.
# ----------------------------------------------------------------------------

var done := false
var collected_value := -1
var collected_count := 0

func _on_collected(value: int) -> void:
	collected_value = value
	collected_count += 1

func _fail(reason: String) -> void:
	if done:
		return
	done = true
	print("SHOWCASE_WEB_FAIL: ", reason)

func _ready() -> void:
	# Defer so the engine finishes its first frame/boot before we drive.
	call_deferred("_run")

func _run() -> void:
	if done:
		return
	if not ResourceLoader.exists("res://showcase.tscn"):
		_fail("res://showcase.tscn not found"); return
	var scene = load("res://showcase.tscn").instantiate()
	if scene == null:
		_fail("failed to instantiate showcase.tscn"); return
	add_child(scene)

	var player = scene.get_node_or_null("Player")
	var coin1 = scene.get_node_or_null("Coin1")
	var hud = scene.get_node_or_null("Hud")
	if player == null or coin1 == null or hud == null:
		_fail("a showcase node is missing (Player/Coin1/Hud)"); return

	# Base types come from the Odin //gd:extends markers, compiled into the wasm.
	if player.get_script().get_instance_base_type() != "CharacterBody2D":
		_fail("Player base = %s, expected CharacterBody2D" % str(player.get_script().get_instance_base_type())); return
	if coin1.get_script().get_instance_base_type() != "Area2D":
		_fail("Coin base = %s, expected Area2D" % str(coin1.get_script().get_instance_base_type())); return

	# Let coin _ready (it wires body_entered -> Odin collect) + first HUD paint settle.
	await get_tree().process_frame
	await get_tree().process_frame

	if String(hud.text) != "Score: 0":
		_fail("HUD initial text = %s, expected 'Score: 0'" % str(hud.text)); return
	if not coin1.has_signal("collected"):
		_fail("coin has no script signal 'collected'"); return

	var v1 := int(coin1.get("value"))
	if v1 <= 0:
		_fail("coin value export bad: %d" % v1); return

	# REGRESSION: exercise core:math/rand on wasm via the Odin HUD's roll() method. Before the
	# web-context fix this trapped with `unreachable executed` (no random_generator seed on
	# freestanding_wasm32). Two calls must both succeed and advance (the shared PRNG state
	# persists across script calls). The HUD also calls rand every _process frame; if that
	# trapped we would never have reached this point at all. Printed EARLY (before the slow
	# physics loop) so the entropy probe across page loads is quick. r1 also doubles as the
	# per-load seed witness: the web context reseeds from Godot's entropy, so r1 differs across
	# loads (drive.mjs asserts non-determinism).
	var r1 := int(hud.call("roll"))
	var r2 := int(hud.call("roll"))
	if r1 == r2:
		_fail("rand did not advance across calls: r1=%d r2=%d" % [r1, r2]); return
	print("RAND_WEB_OK r1=%d r2=%d" % [r1, r2])

	# PANIC PHASE (opt-in via ?panic=1): trigger the deliberate Odin script panic and confirm
	# the web assertion_failure_proc surfaced a READABLE message (ODIN_SCRIPT_PANIC ...) in the
	# console instead of a bare `unreachable`. This traps the wasm, so it is the LAST thing we
	# do and only in this phase — the normal run never calls it, staying green.
	if _panic_mode():
		await get_tree().process_frame # let RAND_WEB_OK flush to the console first
		print("PANIC_PHASE: triggering deliberate Odin script panic")
		hud.call("panic_test") # panics -> ODIN_SCRIPT_PANIC printed, then traps
		return

	# Connect the script-declared 'collected' signal so we can assert its payload too.
	coin1.connect("collected", _on_collected)

	# REAL physics overlap: move the player onto the coin and step PHYSICS so body_entered
	# fires naturally -> Odin collect -> shared score += value -> emit('collected') -> free.
	player.global_position = coin1.global_position
	var collected := false
	for _i in range(180):
		await get_tree().physics_frame
		if not is_instance_valid(coin1):
			collected = true
			break
	if not collected:
		_fail("coin1 was not collected by physics overlap (body_entered did not fire/collect)"); return

	# Read the SHARED score directly from the game_state module via the Odin get_score
	# method — this proves the cross-script shared state incremented, independent of the
	# Label text rendering. Then wait (bounded) for the HUD's idle _process to reflect it:
	# the collect lands on a PHYSICS frame, so the Label catches up on a later idle tick.
	var score := int(hud.call("get_score"))
	var hud_text := String(hud.text)
	for _p in range(30):
		if hud_text == ("Score: %d" % v1):
			break
		await get_tree().process_frame
		score = int(hud.call("get_score"))
		hud_text = String(hud.text)

	print("SHOWCASE: physics-collected coin; shared get_score()=%d; listener value=%d; cross-script HUD='%s'" % [score, collected_value, hud_text])

	if collected_count != 1 or collected_value != v1:
		_fail("'collected' listener payload wrong: count=%d value=%d (expected 1, %d)" % [collected_count, collected_value, v1]); return
	if score != v1:
		_fail("shared game_state score did not increment: get_score()=%d expected %d" % [score, v1]); return
	if hud_text != ("Score: %d" % v1):
		_fail("cross-script HUD Label did not reflect score: '%s', expected 'Score: %d'" % [hud_text, v1]); return

	print("SHOWCASE_WEB_OK score=%d value=%d" % [score, collected_value])
	done = true

# _panic_mode — true when the page was loaded with ?panic=1 (drive.mjs's panic phase). Only
# meaningful on web; reads location.search via JavaScriptBridge.
func _panic_mode() -> bool:
	if not OS.has_feature("web"):
		return false
	var search = JavaScriptBridge.eval("location.search || ''", true)
	return search != null and str(search).find("panic=1") != -1
