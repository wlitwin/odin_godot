extends Node
func _ready():
	var enemy=load("res://dev/enemy_view.tscn").instantiate();enemy.position=Vector2(320,240)
	enemy.appearance=enemy.appearance.duplicate(true);enemy.appearance.tint=Color(0.4,0.8,0.6,1);enemy.get_node("Body").position=Vector2(9,-5)
	var runner=load("res://dev/runner_view.tscn").instantiate();runner.position=Vector2(620,240);runner.get_node("Gun").position=Vector2(8,3)
	var hud=load("res://dev/hud_view.tscn").instantiate()
	add_child(enemy);add_child(runner);add_child(hud)
	await get_tree().process_frame;await get_tree().process_frame
	var first:int=enemy.get_node("Body").frame
	await get_tree().create_timer(0.25).timeout
	assert(enemy.get_node("Body").frame!=first)
	assert(enemy.get_node("Body").position==Vector2(9,-5))
	assert(enemy.get_node("Body").modulate.is_equal_approx(Color(0.4,0.8,0.6,1)))
	assert(runner.get_node("Gun").position==Vector2(8,3))
	assert(runner.get_node("Reload").visible)
	assert(hud.get_node("Vitals/Text").text=="5/10")
	runner.preview_down=true;await get_tree().process_frame;await get_tree().process_frame
	assert(runner.get_node("Beacon").visible and not runner.get_node("Gun").visible)
	print("REPLAY_EDITOR_BROWSER_OK enemy=true runner=true hud=true authored=true process=true")
