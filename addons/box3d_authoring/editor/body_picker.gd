@tool
class_name Box3DBodyPicker
extends EditorProperty

var controller: EditorPlugin
var choices := OptionButton.new()
var rebuilding := false

func _init(owner: EditorPlugin = null) -> void:
	controller = owner
	add_child(choices)
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_focusable(choices)
	choices.item_selected.connect(_selected)
	choices.get_popup().about_to_popup.connect(_update_property)

func _update_property() -> void:
	var object := get_edited_object() as Node
	if object == null or not is_instance_valid(controller): return
	rebuilding = true
	choices.clear()
	var current := String(object.get(get_edited_property()))
	choices.add_item("None" if object is Box3DCharacterMover3D else "Choose a body…")
	choices.set_item_metadata(0, "")
	var root := controller.get_editor_interface().get_edited_scene_root()
	var world := Box3DEditorJoints.scope(object, root)
	var bodies := Box3DEditorJoints.bodies(object, root)
	var counts: Dictionary = {}
	for body in bodies: counts[body.stable_key] = counts.get(body.stable_key, 0) + 1
	var selected := 0
	var matched := current.is_empty()
	var other := ""
	if object is Box3DJoint3D: other = object.body_b if get_edited_property() == &"body_a" else object.body_a
	for body in bodies:
		var label := Box3DAuthoringData.relative_name(body, world)
		var errors: Array = []
		Box3DAuthoringData.key(body.stable_key, "body", errors)
		var invalid: bool = not errors.is_empty() or counts[body.stable_key] != 1
		if invalid: label += " (invalid or duplicate ID)"
		choices.add_item(label)
		var index := choices.item_count - 1
		choices.set_item_metadata(index, body.stable_key)
		choices.set_item_disabled(index, invalid or (not other.is_empty() and body.stable_key == other))
		if body.stable_key == current and not invalid:
			selected = index
			matched = true
	if not matched:
		choices.add_item(("Ambiguous body: " if counts.get(current, 0) > 1 else "Missing body: ") + current)
		selected = choices.item_count - 1
		choices.set_item_disabled(selected, true)
	choices.select(selected)
	choices.disabled = not Box3DEditorIdentity.editable(object, root)
	rebuilding = false

func _selected(index: int) -> void:
	if rebuilding or choices.is_item_disabled(index): return
	emit_changed(get_edited_property(), String(choices.get_item_metadata(index)))
