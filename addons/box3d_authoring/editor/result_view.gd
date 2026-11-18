@tool
class_name Box3DResultView
extends VBoxContainer

var summary := Label.new()
var details_toggle := CheckButton.new()
var details := TextEdit.new()
func _init() -> void:
	name = "Box3DResult"
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(summary)
	details_toggle.text = "Technical details"
	details_toggle.visible = false
	add_child(details_toggle)
	details.editable = false
	details.custom_minimum_size = Vector2(0, 180)
	details.visible = false
	add_child(details)
	details_toggle.toggled.connect(func(enabled: bool): details.visible = enabled)
func message(value: String) -> void: summary.text = value
func show_result(result: Dictionary, success: String = "Validation passed.") -> void:
	details.text = JSON.stringify(result, "  ", true, true)
	details_toggle.visible = true
	if result.get("ok", false):
		summary.text = success
		var counts: Dictionary = result.get("metadata", {}).get("counts", {})
		if not counts.is_empty():
			summary.text += "\n%d bodies · %d shapes · %d joints" % [counts.get("bodies", 0), counts.get("shapes", 0), counts.get("joints", 0)]
		return
	var problems: Array = result.get("diagnostics", result.get("errors", []))
	if problems.is_empty(): problems = [result.get("diagnostic", {"message": result.get("error", "Validation failed.")})]
	var lines: PackedStringArray = []
	for problem in problems.slice(0, 8):
		if not problem is Dictionary: lines.append(str(problem)); continue
		var field: String = problem.get("field", problem.get("path", ""))
		var explanation: String = problem.get("message", problem.get("code", problem.get("error", "Invalid value")))
		var definition: Dictionary = problem.get("definition", {})
		if problem.get("definition_available", false):
			explanation += " — " + str(definition.get("error", ""))
			if not String(definition.get("field", "")).is_empty(): field = String(definition.field)
		lines.append((field + ": " if not field.is_empty() else "") + explanation)
	if problems.size() > 8: lines.append("More issues are listed in Technical details.")
	summary.text = "\n".join(lines)
