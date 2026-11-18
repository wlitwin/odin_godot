extends Node
var remove_parent_script := false
func _exit_tree():
	var parent := get_parent()
	if parent.has_method("unregister_child"):
		parent.unregister_child()
	if remove_parent_script:
		parent.set_script(null)
