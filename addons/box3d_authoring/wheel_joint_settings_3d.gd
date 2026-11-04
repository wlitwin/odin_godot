@tool
class_name Box3DWheelJointSettings3D
extends Box3DJointSettings3D

@export_flags("SuspensionSpring","SuspensionLimit","SpinMotor","Steering","SteeringLimit") var flags: int=0
@export var suspension_hertz: float=0.0
@export var suspension_damping_ratio: float=0.0
@export var lower_suspension: float=0.0
@export var upper_suspension: float=0.0
@export var max_spin_torque: float=0.0
@export var spin_speed: float=0.0
@export var steering_hertz: float=0.0
@export var steering_damping_ratio: float=0.0
@export var target_steering_angle: float=0.0
@export var max_steering_torque: float=0.0
@export var lower_steering: float=0.0
@export var upper_steering: float=0.0
func settings_key() -> String:return "wheel"
func accepts_kind(kind: String) -> bool:return kind=="wheel"
func definition(_kind: String,path: String,errors: Array) -> Dictionary:
	Box3DMotionAuthoringData.scalar_fields(self,["suspension_hertz", "suspension_damping_ratio", "lower_suspension", "upper_suspension", "max_spin_torque", "spin_speed", "steering_hertz", "steering_damping_ratio", "target_steering_angle", "max_steering_torque", "lower_steering", "upper_steering"],path,errors)
	Box3DMotionAuthoringData.flags(flags,31,path+".flags",errors)
	if ((flags&2)!=0 and lower_suspension>upper_suspension) or ((flags&16)!=0 and lower_steering>upper_steering):Box3DAuthoringData.issue(errors,path,"Dimension","Enabled Wheel limit interval is reversed.")
	if suspension_hertz<0.0:Box3DAuthoringData.issue(errors,path+".suspension_hertz","Dimension","Value must be nonnegative.")
	if suspension_damping_ratio<0.0:Box3DAuthoringData.issue(errors,path+".suspension_damping_ratio","Dimension","Value must be nonnegative.")
	if max_spin_torque<0.0:Box3DAuthoringData.issue(errors,path+".max_spin_torque","Dimension","Value must be nonnegative.")
	if steering_hertz<0.0:Box3DAuthoringData.issue(errors,path+".steering_hertz","Dimension","Value must be nonnegative.")
	if steering_damping_ratio<0.0:Box3DAuthoringData.issue(errors,path+".steering_damping_ratio","Dimension","Value must be nonnegative.")
	if max_steering_torque<0.0:Box3DAuthoringData.issue(errors,path+".max_steering_torque","Dimension","Value must be nonnegative.")
	return {"flags":flags,"suspension_hertz":suspension_hertz,"suspension_damping_ratio":suspension_damping_ratio,"lower_suspension":lower_suspension,"upper_suspension":upper_suspension,"max_spin_torque":max_spin_torque,"spin_speed":spin_speed,"steering_hertz":steering_hertz,"steering_damping_ratio":steering_damping_ratio,"target_steering_angle":target_steering_angle,"max_steering_torque":max_steering_torque,"lower_steering":lower_steering,"upper_steering":upper_steering}
