extends Node

func _ready() -> void:
	var good: bool = $Pickup.refresh()
	var report := {"ok": good, "message": "Pickup definition and scene are valid." if good else "Pickup definition needs attention.", "issues": []}
	if not good:
		report.issues.append({"source": $Pickup.validation_source(), "path": $Pickup.validation_path(), "message": $Pickup.validation_issue()})
	var destination := OS.get_environment("REPLAY_AUTHORING_REPORT")
	if not destination.is_empty():
		var file := FileAccess.open(destination, FileAccess.WRITE)
		if file == null:
			get_tree().quit(2)
			return
		file.store_string(JSON.stringify(report))
		file.close()
	print("PICKUP_VALIDATION_OK" if good else "PICKUP_VALIDATION_FAILED")
	await get_tree().process_frame
	get_tree().quit(0 if good else 1)
