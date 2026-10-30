extends RefCounted
# Test controller only. It reads actual cover rectangles and uses normal input.
const BOUNDS = Rect2(24,24,1872,1040)
const CLEARANCE = 20.0
const MAX_NODES = 192
var covers: Array = []

func inside(p: Vector2, r: Rect2) -> bool:
 return p.x>r.position.x and p.y>r.position.y and p.x<r.end.x and p.y<r.end.y

func blocked(a: Vector2, b: Vector2, padding: float) -> bool:
 for raw in covers:
  var r:Rect2=raw.grow(padding)
  # The real movement/contact routines allow leaving a containing cover.
  if inside(a,r): continue
  var near:=0.0; var far:=1.0; var crosses:=true
  for axis in 2:
   var d:float=b[axis]-a[axis]
   if absf(d)<0.00001:
    if a[axis]<=r.position[axis] or a[axis]>=r.end[axis]: crosses=false;break
   else:
    var x:float=(r.position[axis]-a[axis])/d
    var y:float=(r.end[axis]-a[axis])/d
    near=maxf(near,minf(x,y));far=minf(far,maxf(x,y))
    if near>=far:crosses=false;break
  if crosses and near<1.0 and far>0.0:return true
 return false

func walkable(p: Vector2) -> bool:
 if not BOUNDS.has_point(p):return false
 for r in covers:
  if inside(p,r.grow(CLEARANCE)):return false
 return true

func shot_clear(p: Vector2, targets: Array) -> bool:
 if targets.is_empty():return false
 for t in targets:
  if p.distance_to(t)<100.0 or p.distance_to(t)>400.0 or blocked(p,t,2.0):return false
 return true

func append_node(nodes: Array, p: Vector2):
 if not walkable(p):return
 for n in nodes:
  if n.distance_squared_to(p)<1.0:return
 if nodes.size()<MAX_NODES:nodes.append(p)

func route(start: Vector2, targets: Array, destination = null) -> Dictionary:
 var nodes: Array=[start]
 for raw in covers:
  var r:Rect2=raw.grow(CLEARANCE)
  for p in [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]:append_node(nodes,p)
 if destination!=null:append_node(nodes,destination)
 else:
  for radius in [150.0,200.0,260.0]:
   for i in 16:append_node(nodes,targets[0]+Vector2.from_angle(TAU*float(i)/16.0)*radius)
 var costs:=[];var parents:=[];var visited:=[]
 for _i in nodes.size():costs.append(INF);parents.append(-1);visited.append(false)
 costs[0]=0.0
 for _step in nodes.size():
  var at:=-1
  for i in nodes.size():
   if not visited[i] and (at<0 or costs[i]<costs[at]):at=i
  if at<0 or is_inf(costs[at]):break
  var goal:bool=nodes[at].distance_to(destination)<1.0 if destination!=null else shot_clear(nodes[at],targets)
  if goal:
   var path:=[];var cursor:int=at
   while cursor>0:path.push_front(nodes[cursor]);cursor=parents[cursor]
   return {"found":true,"path":path,"nodes":nodes.size(),"distance":costs[at]}
  visited[at]=true
  for other in nodes.size():
   if visited[other] or blocked(nodes[at],nodes[other],CLEARANCE):continue
   var cost:float=costs[at]+nodes[at].distance_to(nodes[other])
   if cost<costs[other]:costs[other]=cost;parents[other]=at
 return {"found":false,"path":[],"nodes":nodes.size()}
