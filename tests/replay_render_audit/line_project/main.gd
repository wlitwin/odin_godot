extends Node2D
var line:Line2D
var polygon:Polygon2D
var mesh_node:MeshInstance2D
var frames:=0
var mode:="points"
func _ready():
 if OS.has_feature("web"):mode=str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('mode')||'points'",true))
 line=Line2D.new();line.points=PackedVector2Array([Vector2.ZERO,Vector2(100,0)]);line.width=8;line.default_color=Color(1,0.65,0.2,1);line.position=Vector2(80,180);add_child(line)
 if mode.begins_with("polygon"):
  line.visible=false;polygon=Polygon2D.new();polygon.polygon=PackedVector2Array([Vector2.ZERO,Vector2(100,0),Vector2(100,100),Vector2(0,100)]);polygon.color=Color(1,0.65,0.2,1);polygon.position=Vector2(80,100);add_child(polygon)
  if mode=="polygon_modulate":polygon.color=Color.WHITE
 if mode=="mesh_modulate":
  line.visible=false
  var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3(100,0,0),Vector3(100,100,0),Vector3(0,100,0)]);arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
  var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  mesh_node=MeshInstance2D.new();mesh_node.mesh=mesh;mesh_node.position=Vector2(80,100);add_child(mesh_node)
func _process(_delta):
 frames+=1
 var length:=100.0+float(frames%2)*100.0
 if mode=="points":line.set_point_position(1,Vector2(length,0))
 elif mode=="transform":line.scale=Vector2(length/100.0,1)
 elif mode=="polygon_color":polygon.color=Color(1,0.65,0.2,1.0 if frames%2==0 else 0.5)
 elif mode=="polygon_modulate":polygon.self_modulate=Color(1,0.65,0.2,1.0 if frames%2==0 else 0.5)
 elif mode=="polygon_points":polygon.polygon=PackedVector2Array([Vector2.ZERO,Vector2(length,0),Vector2(length,100),Vector2(0,100)])
 elif mode=="mesh_modulate":mesh_node.self_modulate=Color(1,0.65,0.2,1.0 if frames%2==0 else 0.5)
 if frames==119:
  JavaScriptBridge.eval("globalThis.lineAudit="+JSON.stringify({"mode":mode,"frames":frames,"length":length})+";0",true)
  set_process(false)
