@tool
class_name Box3DAxisJointSettings3D
extends Box3DJointSettings3D

@export_flags("Spring","Limit","Motor") var flags: int=0
@export var hertz: float=0.0
@export var damping_ratio: float=0.0
@export var target: float=0.0
@export var lower: float=0.0
@export var upper: float=0.0
@export var motor_speed: float=0.0
@export var max_motor: float=0.0
func settings_key() -> String:return "axis"
func accepts_kind(kind: String) -> bool:return kind in ["hinge","slider"]
func definition(_kind: String,path: String,errors: Array) -> Dictionary:
	Box3DMotionAuthoringData.flags(flags,7,path+".flags",errors)
	Box3DMotionAuthoringData.scalar_fields(self,["hertz","damping_ratio","target","lower","upper","motor_speed","max_motor"],path,errors)
	if hertz<0.0 or damping_ratio<0.0 or max_motor<0.0 or ((flags&2)!=0 and lower>upper):
		Box3DAuthoringData.issue(errors,path,"Dimension","Invalid spring/motor value or enabled lower/upper limit.")
	return {"flags":flags,"hertz":hertz,"damping_ratio":damping_ratio,"target":target,"lower":lower,"upper":upper,"motor_speed":motor_speed,"max_motor":max_motor}
