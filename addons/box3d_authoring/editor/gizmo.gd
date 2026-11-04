@tool
class_name Box3DAuthoringGizmoPlugin
extends EditorNode3DGizmoPlugin

var services: Box3DEditorServices
var redraw_count: int=0
var last_status: Dictionary={}
func _init(value: Box3DEditorServices=null) -> void:services=value
func _get_gizmo_name() -> String:return "Box3D authoring"
func _has_gizmo(node: Node3D) -> bool:return node is Box3DWorld3D or node is Box3DBody3D or node is Box3DJoint3D or node is Box3DCharacterMover3D
func _get_priority() -> int:return 1
func world_of(node: Node) -> Box3DWorld3D:
	var current: Node=node
	while current!=null:
		if current is Box3DWorld3D:return current
		current=current.get_parent()
	return null
func transform_from(value: Dictionary) -> Transform3D:
	var q: Array=value.rotation;var p: Array=value.position
	return Transform3D(Basis(Quaternion(q[0],q[1],q[2],q[3])),Vector3(p[0],p[1],p[2]))
func _line(points: PackedVector3Array,colors: PackedColorArray,a: Vector3,b: Vector3,color: Color) -> void:
	points.append(a);points.append(b);colors.append(color)
func _capsule(points: PackedVector3Array,colors: PackedColorArray,a: Vector3,b: Vector3,radius: float) -> void:
	var axis: Vector3=(b-a).normalized();var right: Vector3=axis.cross(Vector3.RIGHT if absf(axis.x)<0.8 else Vector3.UP).normalized();var forward: Vector3=axis.cross(right)
	for i in range(16):
		var angle: float=TAU*float(i)/16.0;var next: float=TAU*float(i+1)/16.0
		var edge: Vector3=radius*(right*cos(angle)+forward*sin(angle));var following: Vector3=radius*(right*cos(next)+forward*sin(next))
		_line(points,colors,a+edge,a+following,Color.ORANGE);_line(points,colors,b+edge,b+following,Color.ORANGE)
		if i%4==0:_line(points,colors,a+edge,b+edge,Color.ORANGE)
	for radial in [right,forward]:
		for i in range(16):
			var angle: float=PI*float(i)/16.0;var next: float=PI*float(i+1)/16.0
			_line(points,colors,a+radius*(radial*cos(angle)-axis*sin(angle)),a+radius*(radial*cos(next)-axis*sin(next)),Color.ORANGE)
			_line(points,colors,b+radius*(radial*cos(angle)+axis*sin(angle)),b+radius*(radial*cos(next)+axis*sin(next)),Color.ORANGE)
func geometry_for(node: Node3D) -> Dictionary:
	var world: Box3DWorld3D=world_of(node)
	if world==null:return {"ok":false,"error":"MissingWorld"}
	var errors: Array=world.box3d_diagnostics()
	if not errors.is_empty():return {"ok":false,"error":"AuthoringInvalid","diagnostics":errors}
	var definition: Dictionary=world.box3d_definition()
	var points:=PackedVector3Array();var colors:=PackedColorArray()
	if node is Box3DWorld3D or node is Box3DBody3D:
		var selected: Dictionary=definition.duplicate(true)
		if node is Box3DBody3D:
			var bodies: Array=[]
			for body in selected.bodies:
				if body.stable_key==node.stable_key:bodies.append(body)
			selected.bodies=bodies;selected.schema_version=1;selected.erase("joints");selected.erase("characters")
		var inspected: Dictionary=services.inspect_definition(selected) if services!=null else {"ok":false}
		if not inspected.get("ok",false):return {"ok":false,"error":"SharedPreviewUnavailable","diagnostic":inspected.get("diagnostic",{})}
		var preview: Dictionary=inspected.get("preview",{})
		if not preview.get("available",false) or preview.get("scope","")!="AUTHORED_SHAPES_ONLY_NO_FRAME_NO_STAMP":return {"ok":false,"error":preview.get("error","PreviewUnavailable"),"required":preview.get("required",0)}
		if preview.lines.size()>8192:return {"ok":false,"error":"Capacity"}
		for line in preview.lines:
			points.append(Vector3(line.a[0],line.a[1],line.a[2]));points.append(Vector3(line.b[0],line.b[1],line.b[2]));colors.append(Color(line.color[0],line.color[1],line.color[2],line.color[3]))
	var pending: Array[Node]=[]
	pending.append(world if node is Box3DWorld3D else node)
	while not pending.is_empty():
		var current: Node=pending.pop_back()
		if current!=world and current is Box3DWorld3D:continue
		if current is Box3DJoint3D:
			var a_body: Box3DBody3D=null;var b_body: Box3DBody3D=null
			var search: Array[Node]=[world]
			while not search.is_empty():
				var child: Node=search.pop_back()
				if child!=world and child is Box3DWorld3D:continue
				if child is Box3DBody3D:
					if child.stable_key==current.body_a:a_body=child
					if child.stable_key==current.body_b:b_body=child
				for next_child in child.get_children():search.append(next_child)
			if a_body==null or b_body==null:return {"ok":false,"error":"MissingBody"}
			var a_pose: Transform3D=transform_from(Box3DAuthoringData.relative_pose(a_body,world,"joint.a",errors))*current.local_frame_a
			var b_pose: Transform3D=transform_from(Box3DAuthoringData.relative_pose(b_body,world,"joint.b",errors))*current.local_frame_b
			_line(points,colors,a_pose.origin,b_pose.origin,Color.MAGENTA)
			for frame in [a_pose,b_pose]:
				_line(points,colors,frame.origin,frame.origin+frame.basis.x*0.3,Color.RED);_line(points,colors,frame.origin,frame.origin+frame.basis.y*0.3,Color.GREEN);_line(points,colors,frame.origin,frame.origin+frame.basis.z*0.3,Color.BLUE)
		if current is Box3DCharacterMover3D:
			var character: Dictionary=current.box3d_character_definition(world,"character",errors)
			var p: Array=character.initial.position;var position:=Vector3(p[0],p[1],p[2]);var capsule: Dictionary=character.config.capsule
			_capsule(points,colors,position+Vector3(capsule.center1[0],capsule.center1[1],capsule.center1[2]),position+Vector3(capsule.center2[0],capsule.center2[1],capsule.center2[2]),capsule.radius)
		if node is Box3DWorld3D:
			for child in current.get_children():pending.append(child)
	if not errors.is_empty():return {"ok":false,"error":"Pose","diagnostics":errors}
	if points.size()>16384:return {"ok":false,"error":"Capacity","required":points.size()>>1}
	var local_from_world: Transform3D=transform_from(Box3DAuthoringData.relative_pose(node,world,"gizmo",errors)).affine_inverse() if node!=world else Transform3D.IDENTITY
	for i in range(points.size()):points[i]=local_from_world*points[i]
	return {"ok":true,"points":points,"colors":colors,"lines":points.size()>>1,"scope":"authored_only_no_frame_no_native"}
func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear();redraw_count+=1
	last_status=geometry_for(gizmo.get_node_3d())
	if not last_status.get("ok",false):return
	var points: PackedVector3Array=last_status.points;var colors: PackedColorArray=last_status.colors
	if points.is_empty():return
	var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(points.size()):mesh.surface_set_color(colors[i>>1]);mesh.surface_add_vertex(points[i])
	mesh.surface_end()
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.vertex_color_use_as_albedo=true
	gizmo.add_mesh(mesh,material);gizmo.add_collision_segments(points)
