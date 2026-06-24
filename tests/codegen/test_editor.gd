@tool
extends SceneTree

# ----------------------------------------------------------------------------
# Editor-context verification for the richer-authoring codegen.
#
# In the EDITOR a non-tool Odin script is NOT really instantiated — the engine builds a
# placeholder whose property list + values come from the core (make_property_info +
# placeholder_script_instance_update + the script-level default-value virtual). We assert:
#   (2) groups   — the property list carries GROUP markers "Movement" (before `speed`) and
#                  "Combat" (before `hp`), each with the PROPERTY_USAGE_GROUP usage bit.
#   (3) defaults — Script.get_property_default_value() (routes to _get_property_default_value)
#                  returns 200 for `speed`, 12.5 for `jump`, and NIL for the un-defaulted `hp`.
#                  The placeholder also surfaces the default as the property's shown value.
#
# Prints CODEGEN_EDITOR_OK, or CODEGEN_FAIL: <which>.
#
# Run:  $GODOT --editor --headless --path tests/codegen --script test_editor.gd
# ----------------------------------------------------------------------------

func _fail(which: String) -> void:
	print("CODEGEN_FAIL: ", which)
	quit(1)

# Index of the first property entry matching name (and, if usage_mask != 0, that usage bit).
func _index_of(props: Array, pname: String, usage_mask: int) -> int:
	for i in range(props.size()):
		var p = props[i]
		if String(p.get("name", "")) != pname:
			continue
		if usage_mask != 0 and (int(p.get("usage", 0)) & usage_mask) == 0:
			continue
		return i
	return -1

func _initialize() -> void:
	if not Engine.is_editor_hint():
		_fail("not running in editor context (is_editor_hint false)"); return

	var n = load("res://codegen.tscn").instantiate()
	get_root().add_child(n)

	var props = n.get_property_list()

	# --- (2) @export group markers, in order before their properties -----------
	var gi_move = _index_of(props, "Movement", PROPERTY_USAGE_GROUP)
	if gi_move < 0:
		_fail("groups: no 'Movement' GROUP marker in property list"); return
	var pi_speed = _index_of(props, "speed", 0)
	if pi_speed < 0:
		_fail("groups: 'speed' missing from property list"); return
	if gi_move >= pi_speed:
		_fail("groups: 'Movement' marker (%d) must precede 'speed' (%d)" % [gi_move, pi_speed]); return

	var gi_combat = _index_of(props, "Combat", PROPERTY_USAGE_GROUP)
	if gi_combat < 0:
		_fail("groups: no 'Combat' GROUP marker in property list"); return
	var pi_hp = _index_of(props, "hp", 0)
	if pi_hp < 0:
		_fail("groups: 'hp' missing from property list"); return
	if gi_combat >= pi_hp:
		_fail("groups: 'Combat' marker (%d) must precede 'hp' (%d)" % [gi_combat, pi_hp]); return
	print("  ok  (2) groups: 'Movement' before speed, 'Combat' before hp (usage=GROUP)")

	# --- (3) defaults via Script.get_property_default_value() ------------------
	var scr = n.get_script()
	if abs(float(scr.get_property_default_value("speed")) - 200.0) > 0.001:
		_fail("default: get_property_default_value(speed)=%s want 200" % str(scr.get_property_default_value("speed"))); return
	if abs(float(scr.get_property_default_value("jump")) - 12.5) > 0.001:
		_fail("default: get_property_default_value(jump)=%s want 12.5" % str(scr.get_property_default_value("jump"))); return
	if scr.get_property_default_value("hp") != null:
		_fail("default: hp has no default, expected null got %s" % str(scr.get_property_default_value("hp"))); return
	print("  ok  (3) defaults: get_property_default_value -> speed=200, jump=12.5, hp=<none>")

	# Placeholder also surfaces the default as the property's shown value.
	if abs(float(n.get("speed")) - 200.0) > 0.001:
		_fail("default: placeholder speed value got %s want 200" % str(n.get("speed"))); return
	print("  ok  (3) defaults: placeholder shows speed=200")

	print("CODEGEN_EDITOR_OK")
	quit(0)
