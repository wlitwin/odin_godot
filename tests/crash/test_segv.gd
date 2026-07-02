extends SceneTree

# Drives the SIGNAL path: calls the Odin autoload's do_segv(), which dereferences nil.
# The process dies with SIGSEGV; run.sh asserts the fatal-signal reporter's output
# (ODIN_GODOT_CRASH + a symbolized frame) on this process's captured output.

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	var target = root.get_node_or_null("CrashTarget")
	if target == null:
		print("CRASH_DRIVER_FAIL: /root/CrashTarget not found")
		quit(1)
		return
	print("CRASH_DRIVER_CALLING do_segv")
	target.call("do_segv")
	# Unreachable: the deref kills the process. Reaching here means it did NOT crash.
	print("CRASH_DRIVER_FAIL: do_segv returned (no crash)")
	quit(1)
