extends "res://workbench_test.gd"
func run():
	var pulse:Resource=load("res://data/attacks/storm_pulse.tres")
	var radius:float=pulse.radius;var wind:int=pulse.windup_ticks
	pulse.radius=160; pulse.windup_ticks=60
	bench=load("res://dev/stormcaller.tscn").instantiate();root.add_child(bench);game=bench.game_node()
	if not await until(func():return bench.is_staged() and game.storm_probe("left")>0):await finish(1,"authored storm encounter");return
	if game.storm_probe("radius")!=160 or game.storm_probe("wind")!=60:await finish(1,"PulseDef edit did not bake");return
	pulse.radius=200
	if game.storm_probe("radius")!=160:await finish(1,"live Resource changed World");return
	pulse.radius=radius;pulse.windup_ticks=wind;pulse=null
	print("STORMCALLER_WORKBENCH_OK admitted_spawn=true resource_edit=true immutable=true")
	await finish(0)
