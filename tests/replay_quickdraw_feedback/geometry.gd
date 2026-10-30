extends SceneTree
func _initialize():
 var report:=[]
 for name in ["gunner","drone","bullet"]:
  var old:Node=load("res://reference/"+name+".tscn").instantiate()
  var current:Node=load("res://views/"+name+".tscn").instantiate()
  for node in old.get_children():
   if not node is Polygon2D:continue
   var mesh:MeshInstance2D=current.get_node(NodePath(node.name))
   var arrays:=mesh.mesh.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   assert(vertices.size()==node.polygon.size())
   for i in range(vertices.size()):assert(Vector2(vertices[i].x,vertices[i].y)==node.polygon[i] and vertices[i].z==0)
   assert(mesh.self_modulate==node.color and mesh.transform==node.transform and mesh.visible==node.visible and mesh.z_index==node.z_index)
   assert(arrays[Mesh.ARRAY_INDEX]==Geometry2D.triangulate_polygon(node.polygon))
   report.append({"scene":name,"node":str(node.name),"vertices":vertices.size(),"color":str(mesh.self_modulate)})
  old.free();current.free()
 print("RQ_GEOMETRY_OK ",JSON.stringify(report));quit()
