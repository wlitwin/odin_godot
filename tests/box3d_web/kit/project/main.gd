extends Node

func _ready() -> void:
	# Exercise normal engine frames before the short synchronous adapter case;
	# quit during the Web template's asynchronous audio startup is a separate race.
	for _frame in range(60):
		await get_tree().process_frame
	var result: Variant = JSON.parse_string($Probe.call("exercise"))
	if not result is Dictionary or result.get("ok") != true:
		push_error("KIT_WEB_FAIL actual SDK exercise")
		get_tree().quit(1)
		return
	print("KIT_WEB_PASS ", JSON.stringify(result))
	if OS.has_feature("web"):
		await RenderingServer.frame_post_draw
	get_tree().quit()
