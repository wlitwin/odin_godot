extends Node

# This node outlives the failed game scene. Audio playback releases its last
# stream reference asynchronously; quit only after the exact streams retire.
var target_id: int

func _ready() -> void:
	var target := instance_from_id(target_id) as Node
	var audio_refs: Array[WeakRef] = []
	if is_instance_valid(target):
		for kind in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
			for player in target.find_children("*", kind, true, false):
				if player.stream != null: audio_refs.append(weakref(player.stream))
		target.set_process(false)
		target.queue_free()
		target = null
	await get_tree().process_frame
	await get_tree().process_frame
	var deadline := Time.get_ticks_msec() + 2000
	while audio_refs.any(func(ref: WeakRef) -> bool: return ref.get_ref() != null):
		if Time.get_ticks_msec() >= deadline:
			push_error("Failed game audio survived scene cleanup")
			get_tree().quit(1)
			return
		await get_tree().create_timer(.01).timeout
	print("RSY_FAILURE_CLEANUP_OK")
	get_tree().quit(1)
