@tool
class_name Box3DMotorJoint3D
extends Box3DJoint3D

func _init() -> void:
	settings=Box3DMotorJointSettings3D.new()
func _joint_kind() -> String:return "motor"
