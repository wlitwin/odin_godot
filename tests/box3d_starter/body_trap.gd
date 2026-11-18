extends Box3DBody3D
var target: Node
var armed := false
func _ready() -> void: set_notify_local_transform(true)
func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and armed:
		armed = false
		target.set_script(null)
