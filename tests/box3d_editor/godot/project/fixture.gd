class_name Box3DEditorFixture
extends RefCounted
static func make_world() -> Box3DWorld3D:
	var world:=Box3DWorld3D.new();world.name="EditorWorld";world.stable_key="editor.world";world.gravity=Vector3.ZERO
	var box:=Box3DBoxShape3D.new();box.stable_key="box"
	var sphere:=Box3DSphereShape3D.new();sphere.stable_key="sphere"
	var capsule:=Box3DCapsuleShape3D.new();capsule.stable_key="capsule";capsule.centers_a=Vector3(-0.25,-0.5,0);capsule.centers_b=Vector3(0.25,0.75,0)
	var hull:=Box3DHullShape3D.new();hull.stable_key="hull";hull.points=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP,Vector3.BACK])
	var mesh:=Box3DMeshShape3D.new();mesh.stable_key="mesh";mesh.vertices=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.BACK]);mesh.indices=PackedInt32Array([0,1,2])
	var terrain:=Box3DHeightfieldShape3D.new();terrain.stable_key="terrain";terrain.heights=PackedFloat32Array([0,0.25,0.5,0])
	var shapes: Array[Box3DShape3D]=[box,sphere,capsule,hull,mesh,terrain]
	for i in range(shapes.size()):
		var body:=Box3DBody3D.new();body.name="Body%d"%i;body.stable_key="body.%d"%i;body.body_type=2 if i==0 else 0
		body.shapes.append(shapes[i]);world.add_child(body);body.owner=world;body.position=Vector3(i*3,0,0)
	var sensor:=Box3DSensor3D.new();sensor.name="Sensor";sensor.stable_key="sensor";sensor.shapes.append(sphere);world.add_child(sensor);sensor.owner=world;sensor.position=Vector3(0,3,0)
	var character:=Box3DCharacterMover3D.new();character.name="Character";character.stable_key="character";character.position=Vector3(0,5,0);world.add_child(character);character.owner=world
	var joint:=Box3DHingeJoint3D.new();joint.name="Joint";joint.stable_key="joint";joint.body_a="body.0";joint.body_b="body.1";joint.local_frame_a.origin=Vector3(3,0,0);world.add_child(joint);joint.owner=world
	return world
