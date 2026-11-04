@tool
class_name Box3DWeldJointSettings3D
extends Box3DJointSettings3D

@export var linear_hertz: float=0.0
@export var angular_hertz: float=0.0
@export var linear_damping_ratio: float=0.0
@export var angular_damping_ratio: float=0.0
func settings_key() -> String:return "weld"
func accepts_kind(kind: String) -> bool:return kind=="weld"
func definition(_kind: String,path: String,errors: Array) -> Dictionary:
	Box3DMotionAuthoringData.scalar_fields(self,["linear_hertz", "angular_hertz", "linear_damping_ratio", "angular_damping_ratio"],path,errors)
	if linear_hertz<0.0:Box3DAuthoringData.issue(errors,path+".linear_hertz","Dimension","Value must be nonnegative.")
	if angular_hertz<0.0:Box3DAuthoringData.issue(errors,path+".angular_hertz","Dimension","Value must be nonnegative.")
	if linear_damping_ratio<0.0:Box3DAuthoringData.issue(errors,path+".linear_damping_ratio","Dimension","Value must be nonnegative.")
	if angular_damping_ratio<0.0:Box3DAuthoringData.issue(errors,path+".angular_damping_ratio","Dimension","Value must be nonnegative.")
	return {"linear_hertz":linear_hertz,"angular_hertz":angular_hertz,"linear_damping_ratio":linear_damping_ratio,"angular_damping_ratio":angular_damping_ratio}
