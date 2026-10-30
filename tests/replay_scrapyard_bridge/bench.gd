extends "res://workbench_test.gd"
func count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children(): count += count_nodes(child)
	return count
func run():
	bench = load("res://dev/workbench.tscn").instantiate(); bench.open_shop = true
	root.add_child(bench); game = bench.game_node()
	if not await until(func(): return bench.is_staged() and p("stage") == 2): await finish(1,"benchmark staging"); return
	await create_timer(0.2).timeout
	print("SCRAP_BRIDGE_NODE_COUNT ", count_nodes(game.get_node("World")))
	if not game.bridge_benchmark(int(OS.get_environment("SCRAP_BRIDGE_COUNT"))): await finish(1,"presentation mutated world"); return
	await finish(0)
