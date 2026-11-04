extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size()!=1 or FileAccess.file_exists(arguments[0]):
		push_error("ROUND_DEFINITION_FAIL fresh output required")
		quit(1)
		return
	var source: Node=load("res://main.tscn").instantiate()
	var world: Node=source.get_node("AuthoredWorld")
	var definition: String=world.call("box3d_definition_json")
	if definition.is_empty():
		source.free()
		push_error("ROUND_DEFINITION_FAIL actual authored export")
		quit(1)
		return
	var file := FileAccess.open(arguments[0],FileAccess.WRITE)
	if file==null:
		source.free()
		push_error("ROUND_DEFINITION_FAIL write")
		quit(1)
		return
	file.store_string(definition)
	file.close()
	source.free()
	print("ROUND_DEFINITION_OK ",definition.length())
	quit()
