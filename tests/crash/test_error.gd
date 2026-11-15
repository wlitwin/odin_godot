extends SceneTree

func _initialize() -> void:
	call_deferred("exercise")

func exercise() -> void:
	var target := root.get_node_or_null("CrashTarget")
	if target == null:
		print("CRASH_DRIVER_FAIL: missing CrashTarget for nonfatal error")
		quit(1)
		return
	if int(target.call("report_error")) != 1:
		print("CRASH_DRIVER_FAIL: nonfatal Odin error did not return normally")
		quit(1)
		return
	await process_frame
	print("NONFATAL_STACK_OK")
	quit(0)
