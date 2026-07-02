extends SceneTree

# Drives the PANIC path: calls the Odin autoload's do_panic(), which panics with a
# known message. The process dies (the assertion proc traps after reporting); run.sh
# asserts on this process's captured output, so all this driver does is get there.

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	var target = root.get_node_or_null("CrashTarget")
	if target == null:
		print("CRASH_DRIVER_FAIL: /root/CrashTarget not found")
		quit(1)
		return
	print("CRASH_DRIVER_CALLING do_panic")
	target.call("do_panic")
	# Unreachable: the panic traps. Reaching here means the panic path did NOT fire.
	print("CRASH_DRIVER_FAIL: do_panic returned (no trap)")
	quit(1)
