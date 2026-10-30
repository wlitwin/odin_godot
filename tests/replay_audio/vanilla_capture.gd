extends SceneTree
func _initialize():run.call_deferred()
func run():
	var capture:=AudioEffectCapture.new();capture.buffer_length=0.5;AudioServer.add_bus_effect(0,capture)
	var player:=AudioStreamPlayer.new();root.add_child(player);player.stream=load("res://tone.wav");player.play()
	var mixed:=false
	var deadline:=Time.get_ticks_msec()+3000
	while Time.get_ticks_msec()<deadline and not mixed:
		var frames:=capture.get_frames_available()
		if frames>0:
			for sample in capture.get_buffer(mini(frames,4096)):
				if absf(sample.x)+absf(sample.y)>0.0001:mixed=true;break
		await process_frame
	print("VANILLA_AUDIO_CAPTURE mixed=",mixed," since_last_mix=",AudioServer.get_time_since_last_mix())
	player.stop();player.stream=null;player.queue_free();AudioServer.remove_bus_effect(0,0);capture=null
	await process_frame;await create_timer(0.5).timeout;quit(0 if mixed else 1)
