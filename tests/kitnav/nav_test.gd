extends SceneTree

# kit/nav driver: instantiate the U-corridor scene and wait for the Odin
# script's verdict (it re-queries until the nav map syncs).

var nav: Node = null
var t0 := 0

func _initialize() -> void:
	var scene: PackedScene = load("res://nav.tscn")
	if scene == null:
		print("NAVTEST_FAIL: could not load nav.tscn")
		quit(1); return
	nav = scene.instantiate()
	get_root().add_child(nav)
	t0 = Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	if nav == null or not nav.is_inside_tree():
		return false
	var state := int(nav.call("state"))
	if state == 1:
		print("NAVTEST_DONE")
		quit(0); return true
	if state == -1 or Time.get_ticks_msec() - t0 > 15000:
		print("NAVTEST_TIMEOUT state=", state)
		quit(1); return true
	return false
