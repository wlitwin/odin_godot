@tool
class_name Box3DDistanceJoint3D
extends Box3DJoint3D

func _init() -> void:
	settings=Box3DDistanceJointSettings3D.new()
func _joint_kind() -> String:return "distance"
