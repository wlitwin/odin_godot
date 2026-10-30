extends "res://workbench_test.gd"
func hurt_voice() -> AudioStreamPlayer2D:
	for child in game.get_node("World").get_children():
		if child is AudioStreamPlayer2D and child.stream != null and child.stream.resource_path.ends_with("/ouch.wav"): return child
	return null
func run():
	bench = load("res://dev/workbench.tscn").instantiate(); bench.open_shop = true
	root.add_child(bench); game = bench.game_node()
	if not await until(func(): return bench.is_staged() and p("stage") == 2): await finish(1,"audio staging"); return
	await create_timer(0.5).timeout
	var before := p("sound_plays")
	if game.dev_hurt(1,1) <= 0: await finish(1,"audio hurt input"); return
	if not await until(func(): return p("hp") == 9 and hurt_voice() != null): await finish(1,"contextual wound sound"); return
	var voice := hurt_voice()
	var victim := Vector2(p("x"),p("y"))
	if voice.position.distance_to(victim) > 1 or voice.pitch_scale < 0.919 or voice.pitch_scale > 1.081: await finish(1,"wound position or event pitch"); return
	var played := p("sound_plays")
	if played != before+1 or p("sound_refused") != 0: await finish(1,"one wound should play once"); return
	await create_timer(0.3).timeout
	if p("sound_plays") != played: await finish(1,"confirmation restarted sound"); return
	print("REPLAY_SCRAP_BRIDGE_AUDIO_OK historical_position=true pitch=true once=true")
	await finish(0)
