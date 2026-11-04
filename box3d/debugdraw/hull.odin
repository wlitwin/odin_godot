package box3d_debugdraw

import "core:math"
import p "godot:box3d/presentation"

@(private)
DVec3 :: [3]f64
@(private)
Hull_Face :: struct{a,b,c:int,normal:DVec3,offset:f64}
@(private)
Hull_Edge :: struct{a,b:int}
@(private)
HULL_FACES :: 2*MAX_HULL_POINTS
@(private)
Hull_Data :: struct{points:[MAX_HULL_POINTS]Vec3,count:int,faces:[HULL_FACES]Hull_Face,face_count:int,center:DVec3,epsilon:f64}
@(private)
dvec :: proc "contextless"(v:Vec3)->DVec3{return {f64(v.x),f64(v.y),f64(v.z)}}
@(private)
dcross :: proc "contextless"(a,b:DVec3)->DVec3{return {a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x}}
@(private)
dot :: proc "contextless"(a,b:DVec3)->f64{return a.x*b.x+a.y*b.y+a.z*b.z}
@(private)
point_less :: proc "contextless"(a,b:Vec3)->bool{
 for i in 0..<3{if a[i]<b[i]{return true};if a[i]>b[i]{return false}}
 return false
}
@(private)
face_make :: proc "contextless"(h:^Hull_Data,a,b,c:int)->(Hull_Face,bool){
 left,right:=b,c
 origin:=dvec(h.points[a]);normal:=dcross(dvec(h.points[b])-origin,dvec(h.points[c])-origin)
 magnitude:=math.sqrt(dot(normal,normal));if magnitude==0{return {},false};normal/=magnitude
 if dot(normal,h.center-origin)>0{left,right=right,left;normal=-normal}
 return {a,left,right,normal,dot(normal,origin)},true
}
@(private)
horizon_add :: proc "contextless"(edges:[]Hull_Edge,count:^int,a,b:int)->bool{
 for edge,i in edges[:count^]{if edge.a==b&&edge.b==a{count^-=1;edges[i]=edges[count^];return true};if edge.a==a&&edge.b==b{return false}}
 if count^==len(edges){return false};edges[count^]={a,b};count^+=1;return true
}
// Bounded incremental convex wireframe. This is presentation topology only:
// no native pointers, cooked geometry, physics hull or asset hash is produced.
@(private)
hull_build :: proc "contextless"(vertices:[]Vec3)->(h:Hull_Data,error:Error){
 if len(vertices)>MAX_HULL_POINTS{return {},.Capacity};if len(vertices)<4{return {},.Invalid}
 for vertex in vertices{
  if !vector_valid(vertex){return {},.Invalid}
  at:=h.count;for at>0&&point_less(vertex,h.points[at-1]){h.points[at]=h.points[at-1];at-=1};h.points[at]=vertex;h.count+=1
 }
 unique:=0;for vertex in h.points[:h.count]{if unique==0||vertex!=h.points[unique-1]{h.points[unique]=vertex;unique+=1}};h.count=unique
 if h.count<4{return {},.Invalid}
 a:=0;b,c,d:=-1,-1,-1;best:=f64(0);origin:=dvec(h.points[a]);scale:=f64(0)
 for vertex,i in h.points[:h.count]{delta:=dvec(vertex)-origin;length:=dot(delta,delta);if length>best{b=i;best=length};for value in delta{scale=max(scale,abs(value))}}
 h.epsilon=max(f64(1e-12),scale*1e-9);if b<0{return {},.Invalid}
 axis:=dvec(h.points[b])-origin;best=0
 for vertex,i in h.points[:h.count]{normal:=dcross(axis,dvec(vertex)-origin);area:=dot(normal,normal);if area>best{c=i;best=area}}
 if c<0{return {},.Invalid}
 normal:=dcross(axis,dvec(h.points[c])-origin);normal/=math.sqrt(dot(normal,normal));best=0
 for vertex,i in h.points[:h.count]{distance:=abs(dot(normal,dvec(vertex)-origin));if distance>best{d=i;best=distance}}
 if d<0||best<=h.epsilon{return {},.Invalid}
 h.center=(dvec(h.points[a])+dvec(h.points[b])+dvec(h.points[c])+dvec(h.points[d]))/4
 initial:=[4][3]int{{a,b,c},{a,d,b},{a,c,d},{b,d,c}}
 for tri in initial{face,ok:=face_make(&h,tri[0],tri[1],tri[2]);if !ok{return {},.Invalid};h.faces[h.face_count]=face;h.face_count+=1}
 for vertex,i in h.points[:h.count]{
  if i==a||i==b||i==c||i==d{continue}
  visible:[HULL_FACES]bool;any:=false
  for face,j in h.faces[:h.face_count]{visible[j]=dot(face.normal,dvec(vertex))-face.offset>h.epsilon;any=any||visible[j]}
  if !any{continue}
  horizon:[3*HULL_FACES]Hull_Edge;edge_count:=0;kept:=0
  for face,j in h.faces[:h.face_count]{
   if !visible[j]{h.faces[kept]=face;kept+=1;continue}
   if !horizon_add(horizon[:],&edge_count,face.a,face.b)||!horizon_add(horizon[:],&edge_count,face.b,face.c)||!horizon_add(horizon[:],&edge_count,face.c,face.a){return {},.Invalid}
  }
  h.face_count=kept;if edge_count<3{return {},.Invalid}
  if kept+edge_count>HULL_FACES{return {},.Capacity}
  for edge in horizon[:edge_count]{face,ok:=face_make(&h,edge.a,edge.b,i);if !ok{return {},.Invalid};h.faces[h.face_count]=face;h.face_count+=1}
 }
 return h,.None
}
@(private)
face_has_edge :: proc "contextless"(face:Hull_Face,a,b:int)->bool{
 return (face.a==a||face.b==a||face.c==a)&&(face.a==b||face.b==b||face.c==b)
}
@(private)
hull_lines :: proc "contextless"(w:^Writer,vertices:[]Vec3,pose:p.Pose,color:Color){
 h,error:=hull_build(vertices);if error!=.None{w.error=error;return}
 edges:[3*HULL_FACES]Hull_Edge;count:=0
 for face,i in h.faces[:h.face_count]{
  for pair in ([3][2]int{{face.a,face.b},{face.b,face.c},{face.c,face.a}}){
   a,b:=min(pair[0],pair[1]),max(pair[0],pair[1]);seen:=false
   for edge in edges[:count]{if edge.a==a&&edge.b==b{seen=true;break}}
   if seen{continue}
   adjacent:=-1
   for other,j in h.faces[:h.face_count]{if j!=i&&face_has_edge(other,a,b){if adjacent>=0{w.error=.Invalid;return};adjacent=j}}
   if adjacent<0{w.error=.Invalid;return}
   other:=h.faces[adjacent]
   // Omit face triangulation diagonals; retain actual convex creases only.
   if dot(face.normal,other.normal)>1-1e-9&&abs(face.offset-other.offset)<=h.epsilon{continue}
   if count>=len(edges){w.error=.Capacity;return};edges[count]={a,b};count+=1
  }
 }
 for i in 1..<count{edge:=edges[i];at:=i;for at>0&&(edges[at-1].a>edge.a||(edges[at-1].a==edge.a&&edges[at-1].b>edge.b)){edges[at]=edges[at-1];at-=1};edges[at]=edge}
 for edge in edges[:count]{local_line(w,pose,h.points[edge.a],h.points[edge.b],color)}
}
