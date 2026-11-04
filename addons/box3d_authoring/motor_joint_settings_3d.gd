@tool
class_name Box3DMotorJointSettings3D
extends Box3DJointSettings3D

@export var linear_velocity: Vector3=Vector3.ZERO
@export var angular_velocity: Vector3=Vector3.ZERO
@export var max_velocity_force: float=0.0
@export var max_velocity_torque: float=0.0
@export var linear_hertz: float=0.0
@export var linear_damping_ratio: float=0.0
@export var angular_hertz: float=0.0
@export var angular_damping_ratio: float=0.0
@export var max_spring_force: float=0.0
@export var max_spring_torque: float=0.0
func settings_key() -> String:return "motor"
func accepts_kind(kind: String) -> bool:return kind=="motor"
func definition(_kind: String,path: String,errors: Array) -> Dictionary:
	Box3DMotionAuthoringData.scalar_fields(self,["max_velocity_force", "max_velocity_torque", "linear_hertz", "linear_damping_ratio", "angular_hertz", "angular_damping_ratio", "max_spring_force", "max_spring_torque"],path,errors)
	if max_velocity_force<0.0:Box3DAuthoringData.issue(errors,path+".max_velocity_force","Dimension","Value must be nonnegative.")
	if max_velocity_torque<0.0:Box3DAuthoringData.issue(errors,path+".max_velocity_torque","Dimension","Value must be nonnegative.")
	if linear_hertz<0.0:Box3DAuthoringData.issue(errors,path+".linear_hertz","Dimension","Value must be nonnegative.")
	if linear_damping_ratio<0.0:Box3DAuthoringData.issue(errors,path+".linear_damping_ratio","Dimension","Value must be nonnegative.")
	if angular_hertz<0.0:Box3DAuthoringData.issue(errors,path+".angular_hertz","Dimension","Value must be nonnegative.")
	if angular_damping_ratio<0.0:Box3DAuthoringData.issue(errors,path+".angular_damping_ratio","Dimension","Value must be nonnegative.")
	if max_spring_force<0.0:Box3DAuthoringData.issue(errors,path+".max_spring_force","Dimension","Value must be nonnegative.")
	if max_spring_torque<0.0:Box3DAuthoringData.issue(errors,path+".max_spring_torque","Dimension","Value must be nonnegative.")
	return {"linear_velocity":Box3DMotionAuthoringData.native_vector(linear_velocity,path+".linear_velocity",errors),"angular_velocity":Box3DMotionAuthoringData.native_vector(angular_velocity,path+".angular_velocity",errors),"max_velocity_force":max_velocity_force,"max_velocity_torque":max_velocity_torque,"linear_hertz":linear_hertz,"linear_damping_ratio":linear_damping_ratio,"angular_hertz":angular_hertz,"angular_damping_ratio":angular_damping_ratio,"max_spring_force":max_spring_force,"max_spring_torque":max_spring_torque}
