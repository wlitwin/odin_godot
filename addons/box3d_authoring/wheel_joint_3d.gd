@tool
class_name Box3DWheelJoint3D
extends Box3DJoint3D

func _init() -> void:
	settings=Box3DWheelJointSettings3D.new()
func _joint_kind() -> String:return "wheel"
