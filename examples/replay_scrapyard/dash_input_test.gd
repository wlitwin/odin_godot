extends "res://workbench_test.gd"

func frames(count:int):
	for i in count:await process_frame

func run():
	bench=load("res://main.tscn").instantiate();root.add_child(bench);game=bench
	if not await until(func():return p("ready") and p("meta_claimed")):await finish(1,"dash lobby staging");return
	Input.action_press("rsy_dash");await frames(4)
	game.on_start()
	if not await until(func():return p("in_yard")):await finish(1,"dash yard entry");return
	await frames(12)
	if game.dash_probe("submitted")!=0:Input.action_release("rsy_dash");await finish(1,"lobby press leaked into yard");return
	Input.action_release("rsy_dash");await frames(2)
	Input.action_press("rsy_dash")
	if not await until(func():return game.dash_probe("confirmed")==1):await finish(1,"fresh dash verdict");return
	await create_timer(1.3).timeout
	if game.dash_probe("submitted")!=1:await finish(1,"held dash repeated");return
	Input.action_release("rsy_dash");await frames(2)
	game.on_menu();Input.action_press("rsy_dash");await frames(4)
	game.on_menu();await create_timer(1.3).timeout
	if game.dash_probe("submitted")!=1:await finish(1,"menu press leaked into yard");return
	Input.action_release("rsy_dash");await frames(2);Input.action_press("rsy_dash")
	if not await until(func():return game.dash_probe("confirmed")==2):await finish(1,"second fresh dash verdict");return
	Input.action_release("rsy_dash")
	if game.dash_probe("refused")!=0 or game.dash_probe("pending")!=0 or p("dashes")!=2:await finish(1,"dash result accounting");return
	print("REPLAY_DASH_INPUT_OK lobby_guard=true menu_guard=true held_once=true confirmed=2")
	await finish(0)
