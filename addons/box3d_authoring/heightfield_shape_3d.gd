@tool
class_name Box3DHeightfieldShape3D
extends Box3DShape3D

@export_range(2,64) var width: int = 2
@export_range(2,64) var depth: int = 2
@export var cell_spacing: Vector2 = Vector2.ONE
@export var heights: PackedFloat32Array = PackedFloat32Array([0.0,0.0,0.0,0.0])
func _init() -> void:
	enable_sensor_events=false
func _shape_kind() -> String:
	return "heightfield"
func _geometry(path: String, errors: Array) -> Dictionary:
	if width<2 or depth<2 or width>64 or depth>64 or heights.size()!=width*depth:
		Box3DAuthoringData.issue(errors,path+".width/depth/heights","Dimension","Height count must equal width*depth; each side2..64.")
	if not cell_spacing.is_finite() or cell_spacing.x<=0.0 or cell_spacing.y<=0.0:
		Box3DAuthoringData.issue(errors,path+".cell_spacing","Dimension","Cell spacing must be finite and positive.")
	var values: Array = []
	for i in range(mini(heights.size(),4096)):
		Box3DAuthoringData.scalar(heights[i],path+".heights[%d]"%i,errors)
		values.append(heights[i])
	# Triangulation is exclusively the shared Odin baker's job.
	return {"columns":width,"rows":depth,"spacing":[cell_spacing.x,cell_spacing.y],"heights":values}
