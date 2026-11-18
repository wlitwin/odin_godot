extends Node2D

func _ready() -> void:
	show_result()

func refresh() -> void:
	$Pickup.definition = ResourceLoader.load("res://data/pickup.tres", "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	$Pickup.refresh()
	show_result()

func show_result() -> void:
	var issue: String = $Pickup.validation_issue()
	$Status.text = "Pickup reach: %d pixels. Edit and save data/pickup.tres, then refresh." % $Pickup.preview_reach() if issue.is_empty() else issue
