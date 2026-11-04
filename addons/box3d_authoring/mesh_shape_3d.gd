@tool
class_name Box3DMeshShape3D
extends Box3DShape3D

@export var vertices: PackedVector3Array = PackedVector3Array()
@export var indices: PackedInt32Array = PackedInt32Array()
func _init() -> void:
	enable_sensor_events=false
func _shape_kind() -> String:
	return "mesh"
func _geometry(path: String, errors: Array) -> Dictionary:
	var out_vertices: Array = []
	var out_indices: Array = []
	if vertices.size()<3 or vertices.size()>Box3DAuthoringData.MAX_VERTICES or indices.size()<3 or indices.size()>Box3DAuthoringData.MAX_INDICES or indices.size()%3!=0:
		Box3DAuthoringData.issue(errors,path+".vertices/indices","Capacity","Mesh needs3..4096 vertices and triangle indices within24576 entries.")
	for i in range(mini(vertices.size(),Box3DAuthoringData.MAX_VERTICES)):
		out_vertices.append(Box3DAuthoringData.vector(vertices[i],path+".vertices[%d]"%i,errors))
	for i in range(mini(indices.size(),Box3DAuthoringData.MAX_INDICES)):
		if indices[i]<0 or indices[i]>=vertices.size():
			Box3DAuthoringData.issue(errors,path+".indices[%d]"%i,"Reference","Index is outside the authored vertex array.")
		out_indices.append(indices[i])
	return {"vertices":out_vertices,"indices":out_indices}
