@tool
class_name Box3DHingeJoint3D
extends Box3DJoint3D

func _init() -> void:
	settings=Box3DAxisJointSettings3D.new()
func _joint_kind() -> String:return "hinge"
