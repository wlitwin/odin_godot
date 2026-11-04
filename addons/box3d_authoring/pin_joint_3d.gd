@tool
class_name Box3DPinJoint3D
extends Box3DJoint3D

func _init() -> void:
	settings=Box3DSphericalJointSettings3D.new()
func _joint_kind() -> String:return "pin"
