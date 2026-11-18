extends Box3DWorld3D
var target: Node
func box3d_definition_json() -> String:
	var result := super.box3d_definition_json()
	if target != null: target.set_script(null)
	return result
