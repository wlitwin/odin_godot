@tool
class_name Box3DBoxShape3D
extends Box3DShape3D

@export var half_extents: Vector3 = Vector3(0.5,0.5,0.5)
func _shape_kind() -> String:
	return "box"
func _geometry(path: String, errors: Array) -> Dictionary:
	var values := Box3DAuthoringData.vector(half_extents,path+".half_extents",errors)
	if half_extents.x<=0.0 or half_extents.y<=0.0 or half_extents.z<=0.0:
		Box3DAuthoringData.issue(errors,path+".half_extents","Dimension","Half extents must be positive.")
	return {"half_extents":values}
