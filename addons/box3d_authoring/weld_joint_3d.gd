@tool
class_name Box3DWeldJoint3D
extends Box3DJoint3D

func _init() -> void:
	settings=Box3DWeldJointSettings3D.new()
func _joint_kind() -> String:return "weld"
