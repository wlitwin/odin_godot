@tool
class_name Box3DJointSettings3D
extends Resource

func settings_key() -> String:
	return ""
func accepts_kind(_kind: String) -> bool:
	return false
func definition(_kind: String,path: String,errors: Array) -> Dictionary:
	Box3DAuthoringData.issue(errors,path,"Unsupported","Choose settings for this joint family.")
	return {}
