extends SceneTree

# ----------------------------------------------------------------------------
# Headless E2E for the pure-Odin coin-collector showcase.
#
# The scene `showcase.tscn` is pure data: every node (Player / Coin1 / Coin2 / Hud)
# carries a `.odin` script and there is NO GDScript glue. This driver instantiates it,
# then exercises the real game loop entirely through the compiled Odin scripts:
#   1. base types       — Player=CharacterBody2D, Coin=Area2D, Hud=Label (from //gd:extends).
#   2. @export           — player `speed`, coin `value` round-trip from the scene data.
#   3. input -> _process — pressing ui_right makes the Odin `_process` walk the player.
#   4. REAL-physics collect — the player is moved ONTO a coin and PHYSICS is stepped so the
#      Area2D's `body_entered` fires NATURALLY -> Odin `collect` -> bumps the shared score,
#      emits the script-declared `collected` signal, and frees the coin. Coin1 is collected
#      with NO listener connected (the exact path that used to crash); Coin2 is collected
#      with a `collected` listener connected, whose payload is asserted.
#   5. cross-script HUD  — the Label's Odin `_process` reads game_state and updates its text.
#
# Two regression guards are deliberately baked in:
#   - The PackedScene is NOT retained (`load(...).instantiate()` drops it immediately), so the
#     instantiated nodes must keep their `.odin` script resources alive on their own. A
#     script-lifetime regression re-introduces a use-after-free here.
#   - Collection is driven by a real `body_entered` physics overlap (not a manual
#     `emit_signal`), and Coin1 has no pre-connected `collected` listener — the precise
#     collide -> collect -> emit path that previously segfaulted.
#
# Prints SHOWCASE_OK on success, or SHOWCASE_FAIL: <reason>.
# ----------------------------------------------------------------------------

var done := false
var collected_value := -1
var collected_count := 0

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _fail(reason: String) -> void:
	if done:
		return
	done = true
	print("SHOWCASE_FAIL: ", reason)
	quit(1)

func _on_collected(value: int) -> void:
	collected_value = value
	collected_count += 1

# Move `player` ONTO `coin` and step PHYSICS so the coin's Area2D `body_entered` fires
# naturally. Returns true once the coin has been collected (freed) within `max_frames`.
func _overlap_and_collect(player, coin, max_frames := 30) -> bool:
	player.global_position = coin.global_position
	for _i in range(max_frames):
		await physics_frame
		if not is_instance_valid(coin):
			return true
	return false

func _run() -> void:
	if done:
		return

	if not ResourceLoader.exists("res://showcase.tscn"):
		_fail("res://showcase.tscn not found"); return
	# Deliberately DO NOT retain the PackedScene — `load(...).instantiate()` releases it
	# right away, so the live nodes alone must keep their `.odin` scripts referenced.
	var scene = load("res://showcase.tscn").instantiate()
	if scene == null:
		_fail("failed to instantiate showcase.tscn"); return
	root.add_child(scene)

	var player = scene.get_node_or_null("Player")
	var coin1 = scene.get_node_or_null("Coin1")
	var coin2 = scene.get_node_or_null("Coin2")
	var hud = scene.get_node_or_null("Hud")
	if player == null or coin1 == null or coin2 == null or hud == null:
		_fail("a showcase node is missing (Player/Coin1/Coin2/Hud)"); return

	# ===== 1. base types from //gd:extends =====
	if player.get_script().get_instance_base_type() != "CharacterBody2D":
		_fail("Player base = %s, expected CharacterBody2D" % str(player.get_script().get_instance_base_type())); return
	if coin1.get_script().get_instance_base_type() != "Area2D":
		_fail("Coin base = %s, expected Area2D" % str(coin1.get_script().get_instance_base_type())); return
	if hud.get_script().get_instance_base_type() != "Label":
		_fail("Hud base = %s, expected Label" % str(hud.get_script().get_instance_base_type())); return

	# ===== 2. @export values from the scene =====
	var speed = player.get("speed")
	if not (speed is float) or speed <= 0.0:
		_fail("player.speed export bad: %s" % str(speed)); return
	var v1 := int(coin1.get("value"))
	var v2 := int(coin2.get("value"))
	if v1 <= 0 or v2 <= 0:
		_fail("coin value exports bad: v1=%d v2=%d" % [v1, v2]); return

	# Let _ready (coin connects its body_entered) + first _process settle.
	await process_frame
	await process_frame

	# HUD starts at zero.
	if String(hud.text) != "Score: 0":
		_fail("HUD initial text = %s, expected 'Score: 0'" % str(hud.text)); return

	# ===== 3. input drives the Odin _process =====
	var x0: float = player.position.x
	Input.action_press("ui_right")
	for _i in range(12):
		await process_frame
	Input.action_release("ui_right")
	if player.position.x <= x0 + 1.0:
		_fail("player did not move on ui_right: x0=%.2f x1=%.2f" % [x0, player.position.x]); return

	# ===== 4a. collect coin1 via a REAL physics overlap, NO pre-connected listener =====
	# This is the exact body_entered -> Odin collect -> emit('collected') path that used
	# to segfault when the script-declared signal was emitted with zero listeners.
	if not coin1.has_signal("collected"):
		_fail("coin has no script signal 'collected'"); return
	if not await _overlap_and_collect(player, coin1):
		_fail("coin1 was not collected by physics overlap (body_entered did not fire/collect)"); return
	if is_instance_valid(coin1):
		_fail("coin1 still alive after collect (queue_free did not run)"); return
	await process_frame # let the HUD's _process pick up the new score
	if String(hud.text) != ("Score: %d" % v1):
		_fail("HUD after coin1 = %s, expected 'Score: %d'" % [str(hud.text), v1]); return

	# ===== 4b. collect coin2 via a REAL physics overlap, WITH a 'collected' listener =====
	# Same natural collide path, but now a listener is connected — its payload must arrive.
	coin2.connect("collected", _on_collected)
	if not await _overlap_and_collect(player, coin2):
		_fail("coin2 was not collected by physics overlap"); return
	if is_instance_valid(coin2):
		_fail("coin2 still alive after collect"); return
	if collected_count != 1 or collected_value != v2:
		_fail("'collected' listener payload wrong: count=%d value=%d (expected 1, %d)" % [collected_count, collected_value, v2]); return
	await process_frame
	if String(hud.text) != ("Score: %d" % (v1 + v2)):
		_fail("HUD final = %s, expected 'Score: %d'" % [str(hud.text), v1 + v2]); return

	print("SHOWCASE: physics-collected 2 coins; score %d; listener got value=%d; HUD='%s'" % [v1 + v2, collected_value, hud.text])
	print("SHOWCASE_OK")
	done = true
	quit(0)
