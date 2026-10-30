extends "res://workbench_test.gd"
func run():
 bench=load("res://dev/workbench.tscn").instantiate();bench.open_shop=true;root.add_child(bench);game=bench.game_node()
 if not await until(func():return p("ready")):await finish(1,"mesh setup");return
 if not game.mesh_probe():await finish(1,"mesh ownership or atomic replacement");return
 print("REPLAY_MESH2_OWNERSHIP_OK")
 await finish(0)
