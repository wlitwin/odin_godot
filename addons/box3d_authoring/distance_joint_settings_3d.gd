@tool
class_name Box3DDistanceJointSettings3D
extends Box3DJointSettings3D

@export var axis: Box3DAxisJointSettings3D=Box3DAxisJointSettings3D.new()
@export var length: float=1.0
@export var lower_spring_force: float=0.0
@export var upper_spring_force: float=0.0
func settings_key() -> String:return "distance"
func accepts_kind(kind: String) -> bool:return kind=="distance"
func definition(_kind: String,path: String,errors: Array) -> Dictionary:
	Box3DMotionAuthoringData.scalar_fields(self,["length","lower_spring_force","upper_spring_force"],path,errors)
	if length<0.0 or lower_spring_force>upper_spring_force:Box3DAuthoringData.issue(errors,path,"Dimension","Invalid distance/spring force interval.")
	var axis_data: Dictionary={}
	if axis==null:Box3DAuthoringData.issue(errors,path+".axis","Reference","Axis settings are missing.")
	else:axis_data=axis.definition("distance",path+".axis",errors)
	return {"axis":axis_data,"length":length,"lower_spring_force":lower_spring_force,"upper_spring_force":upper_spring_force}
