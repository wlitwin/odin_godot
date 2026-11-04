@tool
class_name Box3DCharacterConfig3D
extends Resource

@export_range(1,8) var max_slides: int=4
@export var center1: Vector3=Vector3(0,0.5,0)
@export var center2: Vector3=Vector3(0,1.5,0)
@export var radius: float=0.5
@export var up: Vector3=Vector3.UP
@export_range(0,1) var floor_cosine: float=0.70710677
@export var category_bits: int=1
@export var mask_bits: int=4294967295
@export var include_sensors: bool=false
func box3d_character_config(path: String,errors: Array) -> Dictionary:
	var d:=Box3DAuthoringData
	d.scalar(radius,path+".capsule.radius",errors);d.scalar(floor_cosine,path+".floor_cosine",errors)
	if max_slides<1 or max_slides>8:d.issue(errors,path+".max_slides","Capacity","Character max_slides must be1..8.")
	if radius<=0.0 or center1.distance_squared_to(center2)<=0.0:d.issue(errors,path+".capsule","Dimension","Capsule requires distinct endpoints and positive radius.")
	if not up.is_finite() or absf(up.length_squared()-1.0)>d.EPS:d.issue(errors,path+".up","Pose","Up must be finite and unit.")
	if floor_cosine<0.0 or floor_cosine>1.0:d.issue(errors,path+".floor_cosine","Dimension","Floor cosine must be0..1.")
	if category_bits<0 or mask_bits<0:d.issue(errors,path+".filter","Dimension","Filter fields must be nonnegative; no unsigned reinterpretation.")
	return {"max_slides":max_slides,"capsule":{"center1":d.vector(center1,path+".capsule.center1",errors),"center2":d.vector(center2,path+".capsule.center2",errors),"radius":radius},"up":d.vector(up,path+".up",errors),"floor_cosine":floor_cosine,"category_bits":category_bits,"mask_bits":mask_bits,"include_sensors":include_sensors}
