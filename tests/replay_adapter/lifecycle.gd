extends "res://workbench_test.gd"
func run():
	bench=load("res://dev/workbench.tscn").instantiate();root.add_child(bench);game=bench.game_node()
	if not await until(func():return bench.is_staged()):await finish(1,"adapter staging");return
	if not game.adapter_check():await finish(1,"adapter lifecycle and ownership");return
	await process_frame;await process_frame
	print("REPLAY_ADAPTER_LIFECYCLE_OK")
	await finish(0)
