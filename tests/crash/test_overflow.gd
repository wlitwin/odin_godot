extends SceneTree

# Drives the STACK-OVERFLOW path: calls the Odin autoload's do_overflow(), unbounded
# non-tail recursion until the stack guard page faults (SIGSEGV on a thread with no
# usable stack). Reporting at all requires the handler to run on its SIGALTSTACK —
# run.sh asserts the ODIN_GODOT_CRASH report on this process's captured output.

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	var target = root.get_node_or_null("CrashTarget")
	if target == null:
		print("CRASH_DRIVER_FAIL: /root/CrashTarget not found")
		quit(1)
		return
	print("CRASH_DRIVER_CALLING do_overflow")
	target.call("do_overflow")
	# Unreachable: the overflow kills the process. Reaching here means it did NOT crash.
	print("CRASH_DRIVER_FAIL: do_overflow returned (no crash)")
	quit(1)
