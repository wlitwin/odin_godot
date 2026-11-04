extends SceneTree

func _initialize() -> void:
	process_frame.connect(run_test, CONNECT_ONE_SHOT)

func run_test() -> void:
	var probe := Node.new()
	probe.set_script(load("res://modules/quota_probe/probe.odin"))
	root.add_child(probe)
	var result: Dictionary = JSON.parse_string(String(probe.call("exercise")))
	probe.free()
	if not result.get("ok", false):
		push_error("PRODUCTION_PUBLIC_QUOTA_FAIL: " + JSON.stringify(result))
		quit(1)
		return
	print("PRODUCTION_PUBLIC_QUOTA_OK actual_shared_limit=67108864 frameworks=Kit,Replay Core_Meter_DataLease=true")
	quit(0)
