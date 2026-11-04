extends SceneTree

# Calibrate the production widget's rectangle at the reference viewport. Only
# presentation text/visibility are set; no gameplay result or action is claimed.
func _initialize() -> void:
	call_deferred("inspect_layout")

func inspect_layout() -> void:
	var scene: Node=load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	var view: Node=scene.get_node("View")
	view.set_process(false)
	var result: Label=view.get("result")
	result.text="PERFECT HAUL!\n3 / 3 LOADS  ·  $1336"
	var next: Button=view.get("next_button")
	var retry: Button=view.get("retry_button")
	next.visible=true
	retry.visible=true
	next.get_parent().get_parent().visible=true
	await process_frame
	await process_frame
	var rect:=next.get_global_rect()
	print("Q1_BUTTON_LAYOUT ",JSON.stringify({"scope":"actual production UI layout only, no gameplay proof","viewport":[root.size.x,root.size.y],"next_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"next_center":[rect.get_center().x,rect.get_center().y],"visible":next.is_visible_in_tree()}))
	var closed: bool=bool(scene.call("close"))
	quit(0 if closed else 1)
