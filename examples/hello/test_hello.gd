extends SceneTree

# Headless ABI smoke test for the Odin-authored OdinHello GDExtension class.
# Run: $GODOT --headless --path examples/hello --script test_hello.gd

var _signal_fired := false
var _signal_value := -1

func _on_value_changed(v: int) -> void:
	_signal_fired = true
	_signal_value = v

func _init() -> void:
	var fail := func(reason: String) -> void:
		print("HELLO_FAIL: ", reason)
		quit(1)

	# 1. Construct the Odin-authored class.
	if not ClassDB.class_exists("OdinHello"):
		fail.call("OdinHello class not registered")
		return
	var obj = ClassDB.instantiate("OdinHello")
	if obj == null:
		fail.call("OdinHello.new() returned null")
		return

	# 2. Custom bound method: add(2, 3) == 5
	var sum = obj.add(2, 3)
	if sum != 5:
		fail.call("add(2,3) returned %s, expected 5" % str(sum))
		return

	# 3. Connect the signal before mutating the property.
	obj.value_changed.connect(_on_value_changed)

	# 4. Property round-trip: set then get.
	obj.value = 42
	var got = obj.value
	if got != 42:
		fail.call("property round-trip got %s, expected 42" % str(got))
		return

	# 5. Signal should have fired with the new value during the set.
	if not _signal_fired:
		fail.call("value_changed signal did not fire")
		return
	if _signal_value != 42:
		fail.call("value_changed delivered %s, expected 42" % str(_signal_value))
		return

	print("HELLO_OK")
	quit(0)
