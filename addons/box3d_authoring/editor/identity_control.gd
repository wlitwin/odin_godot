@tool
class_name Box3DIdentityControl
extends VBoxContainer

var controller: EditorPlugin
var target: WeakRef
var field := LineEdit.new()
var message := Label.new()

func _init(owner: EditorPlugin = null, object: Object = null) -> void:
	controller = owner
	target = weakref(object)
	var title := Label.new()
	title.text = "Stable ID"
	add_child(title)
	var row := HBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.tooltip_text = "Saved automatically. Changing a body's ID updates references in its World as one undoable edit."
	row.add_child(field)
	var fresh := Button.new()
	fresh.text = "New ID"
	fresh.tooltip_text = "Generate a new stable identity. Undo restores the previous identity and references."
	row.add_child(fresh)
	add_child(row)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.hide()
	add_child(message)
	field.text_submitted.connect(_commit)
	field.focus_exited.connect(func(): _commit(field.text))
	fresh.pressed.connect(func():
		var edited := get_edited_object()
		if edited != null: _commit(Box3DIdentityKey.fresh(Box3DEditorIdentity.kind(edited))))
	if object != null: field.text = String(object.stable_key)
	if object is Node and owner != null and not Box3DEditorIdentity.editable(object, owner.get_editor_interface().get_edited_scene_root()):
		field.editable = false
		fresh.disabled = true
		message.text = "Edit the source scene or enable Editable Children to change this ID."
		message.show()

func get_edited_object() -> Object:
	return target.get_ref() if target != null else null

func _commit(value: String) -> void:
	var object := get_edited_object()
	if not is_instance_valid(controller) or object == null or value == String(object.stable_key): return
	var result: Dictionary = controller.rekey_object(object, value)
	message.text = String(result.get("error", ""))
	message.visible = not result.get("ok", false)
	field.text = String(object.stable_key)
