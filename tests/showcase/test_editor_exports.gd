@tool
extends SceneTree

# Editor-context regression test for @export visibility in the Inspector.
#
# Runtime tests round-trip @export fine, but in the EDITOR a non-tool script gets a
# PlaceHolderScriptInstance whose properties come ONLY from
# placeholder_script_instance_update(props, values). A bug where the placeholder was
# created but never updated made @export vars INVISIBLE in the Inspector while every
# headless runtime test stayed green. The editor smoke test catches editor CRASHES but
# not missing Inspector CONTENT — this closes that gap.
#
# Run via:  $GODOT --editor --headless --path tests/showcase --script test_editor_exports.gd
# Asserts (in editor_hint context) that each scripted node's get_property_list() exposes
# its @export var with the correct Variant type, and that the scene's stored value applies.

func _fail(msg: String) -> void:
	print("EDITOR_EXPORTS_FAIL: ", msg)
	quit(1)

# Find a property entry by name in a node's property list; returns {} if absent.
func _prop(node: Object, pname: String) -> Dictionary:
	for p in node.get_property_list():
		if p.get("name", "") == pname:
			return p
	return {}

func _initialize() -> void:
	if not Engine.is_editor_hint():
		_fail("not running in editor context (is_editor_hint false)"); return

	var scene = load("res://showcase.tscn").instantiate()
	get_root().add_child(scene)

	# --- Player.speed must be a FLOAT export, and get() must round-trip it as a float ---
	# (We assert presence + Variant type, NOT a specific number: the scene value is data the
	# user can freely edit in the Inspector — a hardcoded expected would be brittle. typeof()
	# being TYPE_FLOAT proves the property resolves AND the placeholder get-fallback returns
	# the right type, i.e. it is not missing/null.)
	var player = scene.get_node("Player")
	var sp = _prop(player, "speed")
	if sp.is_empty():
		_fail("Player Inspector is missing the 'speed' @export"); return
	if int(sp.get("type", -1)) != TYPE_FLOAT:
		_fail("Player.speed wrong property type: got %d, want TYPE_FLOAT(%d)" % [int(sp.get("type", -1)), TYPE_FLOAT]); return
	if typeof(player.get("speed")) != TYPE_FLOAT:
		_fail("Player.speed get() did not round-trip as a float (got %s)" % str(player.get("speed"))); return

	# --- Coin.value must be an INT export that get() round-trips as an int ---
	var coin1 = scene.get_node("Coin1")
	var cv = _prop(coin1, "value")
	if cv.is_empty():
		_fail("Coin1 Inspector is missing the 'value' @export"); return
	if int(cv.get("type", -1)) != TYPE_INT:
		_fail("Coin1.value wrong property type: got %d, want TYPE_INT(%d)" % [int(cv.get("type", -1)), TYPE_INT]); return
	if typeof(coin1.get("value")) != TYPE_INT:
		_fail("Coin1.value get() did not round-trip as an int (got %s)" % str(coin1.get("value"))); return

	# --- Hud declares no exports: its Inspector must not invent one ---
	if not _prop(scene.get_node("Hud"), "speed").is_empty():
		_fail("Hud unexpectedly exposes a 'speed' property"); return

	print("EDITOR_EXPORTS_OK")
	quit(0)
