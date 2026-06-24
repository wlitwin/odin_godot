extends SceneTree

# ----------------------------------------------------------------------------
# Custom-resource (Odin `//gd:extends Resource`) end-to-end test. Headless, non-editor.
#
# 1. Construct a Resource, attach the Odin ItemData script -> a REAL instance is created
#    (RefCounted owner; no _ready). Verify base type, @export get/set, a method call.
# 2. .tres ROUND-TRIP: ResourceSaver.save -> ResourceLoader.load(CACHE_MODE_IGNORE) and
#    assert the @export values AND a method result survived, and the loaded resource still
#    has the Odin script attached (so methods dispatch). The .tres text is printed as
#    evidence that the script ref + @export values are serialized into it.
# 3. Resource-typed @export: assign the loaded ItemData to a Node's `data` slot (hinted to
#    ItemData) and read it back + call a method off it.
#
# Run:  $GODOT --headless --path tests/resources --script test_resources.gd
# ----------------------------------------------------------------------------

const TRES_PATH := "res://item.tres"

func _fail(msg: String) -> void:
	print("RESOURCES_FAIL: ", msg)
	quit(1)

func _initialize() -> void:
	var script: Script = load("res://scripts/item_data.odin")
	if script == null:
		_fail("could not load item_data.odin script"); return
	if script.get_instance_base_type() != &"Resource":
		_fail("base type got '%s' want 'Resource'" % str(script.get_instance_base_type())); return
	print("  ok  script base type == Resource")

	# --- 1. construct + attach script -> real instance ---
	var item := Resource.new()
	item.set_script(script)
	if item.get_script() != script:
		_fail("script did not attach to the resource"); return

	item.set("name", "Sword")
	item.set("value", 10)
	if String(item.get("name")) != "Sword":
		_fail("name @export round-trip: got %s" % str(item.get("name"))); return
	if int(item.get("value")) != 10:
		_fail("value @export round-trip: got %s" % str(item.get("value"))); return
	print("  ok  @export set/get round-trip on live instance")

	var total = item.call("item_total")
	if int(total) != 110:
		_fail("item_total() got %s want 110" % str(total)); return
	print("  ok  item_total() method call -> %d" % int(total))

	# --- 2. .tres save + load round-trip ---
	var save_err := ResourceSaver.save(item, TRES_PATH)
	if save_err != OK:
		_fail("ResourceSaver.save failed: %d" % save_err); return

	# Print the .tres contents as evidence (script ref + @export values).
	var f := FileAccess.open(TRES_PATH, FileAccess.READ)
	if f == null:
		_fail("could not reopen saved .tres"); return
	print("----- BEGIN item.tres -----")
	print(f.get_as_text())
	print("----- END item.tres -----")
	f.close()

	# Load FRESH from disk (CACHE_MODE_IGNORE bypasses the in-memory cache, so this is a
	# genuine deserialization, NOT a handback of the object we just saved).
	var loaded := ResourceLoader.load(TRES_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null:
		_fail("ResourceLoader.load returned null"); return
	if loaded == item:
		_fail("loaded resource is the SAME object (cache not bypassed)"); return
	if loaded.get_script() != script:
		_fail("loaded resource lost its Odin script"); return
	if String(loaded.get("name")) != "Sword":
		_fail(".tres name not restored: got %s" % str(loaded.get("name"))); return
	if int(loaded.get("value")) != 10:
		_fail(".tres value not restored: got %s" % str(loaded.get("value"))); return
	var loaded_total = loaded.call("item_total")
	if int(loaded_total) != 110:
		_fail("method on loaded resource got %s want 110" % str(loaded_total)); return
	print("  ok  .tres round-trip: name='Sword' value=10 item_total()=%d, script re-bound" % int(loaded_total))

	# --- 3. resource-typed @export on a Node ---
	var holder_script: Script = load("res://scripts/holder.odin")
	if holder_script == null:
		_fail("could not load holder.odin"); return
	var node := Node.new()
	node.set_script(holder_script)
	# the typed-resource @export slot must report a Texture2D-style picker hint.
	var found_data := false
	for p in node.get_property_list():
		if p.get("name", "") == "data":
			found_data = true
			if int(p.get("hint", -1)) != PROPERTY_HINT_RESOURCE_TYPE:
				_fail("data export hint got %d want RESOURCE_TYPE" % int(p.get("hint", -1))); return
			if String(p.get("hint_string", "")) != "ItemData":
				_fail("data export hint_string got '%s' want 'ItemData'" % String(p.get("hint_string", ""))); return
	if not found_data:
		_fail("Holder.data resource @export missing from property list"); return
	node.set("data", loaded)
	var got = node.get("data")
	if got != loaded:
		_fail("resource-typed @export did not store/return the resource"); return
	if int(got.call("item_total")) != 110:
		_fail("method off resource-typed @export got %s" % str(got.call("item_total"))); return
	print("  ok  resource-typed @export stores ItemData + method dispatch works")

	node.free()
	print("RESOURCES_OK")
	quit(0)
