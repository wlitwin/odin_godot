extends Control

func _ready():
	print("RSY_YARD_CLOSED")
	if not OS.has_feature("web"):
		$Message.text = "Leaving the yard…"
		# The previous scene has exited. Allow queued frees/audio retirement to
		# run before ending the engine, as opposed to quitting inside a button.
		await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
		get_tree().quit()
