@tool
class_name Box3DSphericalJointSettings3D
extends Box3DJointSettings3D

@export_flags("Spring","Cone","Twist","Motor") var flags: int=0
@export var hertz: float=0.0
@export var damping_ratio: float=0.0
@export var cone_angle: float=0.0
@export var lower_twist: float=0.0
@export var upper_twist: float=0.0
@export var max_motor_torque: float=0.0
@export var target_rotation: Quaternion=Quaternion.IDENTITY
@export var motor_velocity: Vector3=Vector3.ZERO
func settings_key() -> String:return "spherical"
func accepts_kind(kind: String) -> bool:return kind in ["pin","spherical"]
func definition(kind: String,path: String,errors: Array) -> Dictionary:
	Box3DMotionAuthoringData.flags(flags,15,path+".flags",errors)
	Box3DMotionAuthoringData.scalar_fields(self,["hertz","damping_ratio","cone_angle","lower_twist","upper_twist","max_motor_torque"],path,errors)
	if kind=="pin" and flags!=0:Box3DAuthoringData.issue(errors,path+".flags","Unsupported","Pin disables all angular spring/limit/motor features.")
	if hertz<0.0 or damping_ratio<0.0 or max_motor_torque<0.0 or cone_angle<0.0 or cone_angle>PI or ((flags&4)!=0 and lower_twist>upper_twist):Box3DAuthoringData.issue(errors,path,"Dimension","Invalid spherical spring/cone/twist/motor settings.")
	return {"flags":flags,"hertz":hertz,"damping_ratio":damping_ratio,"cone_angle":cone_angle,"lower_twist":lower_twist,"upper_twist":upper_twist,"max_motor_torque":max_motor_torque,"target_rotation":Box3DMotionAuthoringData.native_quaternion(target_rotation,path+".target_rotation",errors),"motor_velocity":Box3DMotionAuthoringData.native_vector(motor_velocity,path+".motor_velocity",errors)}
