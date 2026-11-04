@tool
class_name Box3DCapsuleShape3D
extends Box3DShape3D

@export var centers_a: Vector3 = Vector3(0,-0.5,0)
@export var centers_b: Vector3 = Vector3(0,0.5,0)
@export var radius: float = 0.5
func _shape_kind() -> String:
	return "capsule"
func _geometry(path: String, errors: Array) -> Dictionary:
	Box3DAuthoringData.scalar(radius,path+".radius",errors)
	if radius<=0.0 or centers_a.distance_squared_to(centers_b)<=0.0:
		Box3DAuthoringData.issue(errors,path+".centers_a/centers_b/radius","Dimension","Distinct endpoints and positive radius are required.")
	return {"centers_a":Box3DAuthoringData.vector(centers_a,path+".centers_a",errors),"centers_b":Box3DAuthoringData.vector(centers_b,path+".centers_b",errors),"radius":radius}
