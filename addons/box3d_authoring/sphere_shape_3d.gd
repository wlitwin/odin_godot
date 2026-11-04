@tool
class_name Box3DSphereShape3D
extends Box3DShape3D

@export var center: Vector3 = Vector3.ZERO
@export var radius: float = 0.5
func _shape_kind() -> String:
	return "sphere"
func _geometry(path: String, errors: Array) -> Dictionary:
	Box3DAuthoringData.scalar(radius,path+".radius",errors)
	if radius<=0.0:
		Box3DAuthoringData.issue(errors,path+".radius","Dimension","Radius must be positive.")
	return {"center":Box3DAuthoringData.vector(center,path+".center",errors),"radius":radius}
