extends SceneTree
# Source conversion: preserve authored geometry, tint, hierarchy and physics.
# The resulting meshes are ordinary scene resources, not a runtime workaround.
func _initialize():
 var args:=OS.get_cmdline_user_args()
 if args.size()!=2:quit(2);return
 var source:=args[0];var output:=args[1]
 DirAccess.make_dir_recursive_absolute(output+"/meshes")
 var receipts:=[]
 for path:String in ["slopball.tscn","views/ball.tscn","views/kicker.tscn"]:
  var text:=FileAccess.get_file_as_string(source+"/"+path)
  var blocks:=text.split("\n[node ")
  var resources:=""
  for i in range(1,blocks.size()):
   var block:=blocks[i]
   if not block.get_slice("\n",0).contains('type="Polygon2D"'):continue
   var name:=block.get_slice('name="',1).get_slice('"',0)
   var lines:=block.split("\n");var points:=PackedVector2Array();var tint:=Color.WHITE
   for line in lines:
    if line.begins_with("polygon = "):points=str_to_var(line.trim_prefix("polygon = "))
    if line.begins_with("color = "):tint=str_to_var(line.trim_prefix("color = "))
   var indices:=Geometry2D.triangulate_polygon(points)
   assert(points.size()>=3 and indices.size()==(points.size()-2)*3)
   var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);var vertices:=PackedVector3Array()
   for point in points:vertices.append(Vector3(point.x,point.y,0))
   arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_INDEX]=indices
   var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   var file:="meshes/"+path.get_file().get_basename().to_snake_case()+"_"+name.to_snake_case()+".tres"
   assert(ResourceSaver.save(mesh,output+"/"+file)==OK)
   var loaded:ArrayMesh=load(output+"/"+file)
   var readback:=loaded.surface_get_arrays(0)
   assert(readback[Mesh.ARRAY_VERTEX]==vertices and readback[Mesh.ARRAY_INDEX]==indices)
   var id:="mesh_"+str(i)
   resources+='[ext_resource type="ArrayMesh" path="res://'+file+'" id="'+id+'"]\n'
   for j in lines.size():
    if j==0:lines[j]=lines[j].replace('type="Polygon2D"','type="MeshInstance2D"')
    elif lines[j].begins_with("color = "):lines[j]=lines[j].replace("color = ","self_modulate = ")
    elif lines[j].begins_with("polygon = "):lines[j]='mesh = ExtResource("'+id+'")'
   blocks[i]="\n".join(lines)
   receipts.append({"scene":path,"node":name,"resource":file,"vertices":points.size(),"indices":indices.size(),"tint":str(tint),"readback_exact":true})
  var header:=blocks[0].split("\n")
  # Godot computes dependency counts; omit the now-outdated optional load_steps.
  var count:=RegEx.new();count.compile(" load_steps=[0-9]+")
  header[0]=count.sub(header[0],"")
  header.insert(1,"\n"+resources)
  blocks[0]="\n".join(header)
  var writer:=FileAccess.open(output+"/"+path,FileAccess.WRITE);assert(writer!=null);writer.store_string("\n[node ".join(blocks));writer.close()
 print("RSL_MESH_CONVERSION ",JSON.stringify(receipts));quit(0)
