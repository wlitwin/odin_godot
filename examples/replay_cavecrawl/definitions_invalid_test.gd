extends SceneTree
var game:Node
var started:=0
func _initialize():run.call_deferred()
func run():
	started=Time.get_ticks_msec()
	game=load("res://cave.tscn").instantiate()
	var resource:Resource=game.floor1_def.duplicate(true)
	match OS.get_environment("DEFINITION_INVALID"):
		"counts":resource.wave_counts=PackedInt32Array([1,2,3]);resource.wave_rests=PackedInt32Array([1])
		"stock":resource.gems=100
		"geometry":resource.rift_min=Vector2(800,60)
		"scene":resource.scene=Resource.new()
		"root":
			var scene:Node2D=resource.scene.instantiate();scene.position=Vector2(1,0)
			var packed:=PackedScene.new();packed.pack(scene);scene.free();resource.scene=packed
		"marker":
			var scene:Node=resource.scene.instantiate();scene.get_node("Den1").free()
			var packed:=PackedScene.new();packed.pack(scene);scene.free();resource.scene=packed
	game.floor1_def=resource;root.add_child(game)
	# The real ready hook must reject before a runner is opened.
	if game.probe_ready():print("CAVE_DEFINITION_INVALID_ACCEPTED");quit(2)

func _process(_dt:float)->bool:
	if started>0 and Time.get_ticks_msec()-started>5000:
		print("CAVE_DEFINITION_INVALID_ACCEPTED timeout waiting for rejection");quit(2);return true
	return false
