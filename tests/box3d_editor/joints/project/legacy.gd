extends SceneTree

func _initialize() -> void:
	for label in ["shared", "dockyard"]:
		var packed: PackedScene = load("res://legacy/" + label + "/world.tscn")
		var world: Box3DWorld3D = packed.instantiate()
		var definition := world.box3d_definition()
		if definition.is_empty():
			push_error("LEGACY_JOINT_FAIL: " + str(world.box3d_diagnostics()))
			world.free(); quit(1); return
		var count := 0
		for node in Box3DEditorIdentity._nodes(world, true):
			if not node is Box3DJoint3D: continue
			var errors: Array = []
			var actual: Dictionary = node.box3d_joint_definition(world, "joint", errors)
			var expected_a := Box3DAuthoringData.pose(node.local_frame_a, "a", errors)
			var expected_b := Box3DAuthoringData.pose(node.local_frame_b, "b", errors)
			if node.frame_mode != Box3DJoint3D.FrameMode.BODY_LOCAL or not errors.is_empty() or actual.local_frame_a != expected_a or actual.local_frame_b != expected_b:
				push_error("LEGACY_JOINT_FAIL: local-frame contract changed")
				world.free(); quit(1); return
			count += 1
		if count == 0:
			push_error("LEGACY_JOINT_FAIL: no migrated joint found")
			world.free(); quit(1); return
		world.free(); packed = null
	print("BOX3D_JOINT_LEGACY_OK")
	quit()
