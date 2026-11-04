@tool
class_name Box3DHullShape3D
extends Box3DShape3D

@export var points: PackedVector3Array = PackedVector3Array()
func _shape_kind() -> String:
	return "hull"
func _geometry(path: String, errors: Array) -> Dictionary:
	var vertices: Array = []
	if points.size()<4 or points.size()>Box3DAuthoringData.MAX_HULL_POINTS:
		Box3DAuthoringData.issue(errors,path+".points","Capacity","Hull requires4..256 points (native limit256).")
	for i in range(mini(points.size(),Box3DAuthoringData.MAX_HULL_POINTS)):
		vertices.append(Box3DAuthoringData.vector(points[i],path+".points[%d]"%i,errors))
	return {"vertices":vertices}
