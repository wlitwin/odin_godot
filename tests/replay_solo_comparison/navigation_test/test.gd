extends SceneTree
var errors:=0
func check(value:bool,label:String):
 if not value:push_error(label);errors+=1
func _initialize():
 var script=load("res://navigation.gd");var nav=script.new()
 nav.covers=[Rect2(819,577,20,32)]
 var start:=Vector2(788,588);var targets:=[Vector2(938,588),Vector2(938,638)]
 check(nav.blocked(start,targets[0],0),"known first ray blocked")
 check(nav.blocked(start,targets[1],0),"known second ray blocked")
 check(not nav.shot_clear(start,targets),"blocked position cannot be firing goal")
 var route:Dictionary=nav.route(start,targets)
 check(route.found and not route.path.is_empty() and route.nodes<=192,"reachable firing position")
 var at:=start
 for point in route.path:
  check(not nav.blocked(at,point,nav.CLEARANCE),"route avoids expanded cover");at=point
 check(nav.shot_clear(at,targets),"route ends with safe visible shots")
 check(nav.route(Vector2(500,300),targets,Vector2(788,588)).found,"ordinary movement to obstruction test")
 check(not nav.walkable(Vector2(820,580)),"cover interior rejected")
 check(not nav.walkable(Vector2(0,0)),"world boundary rejected")
 check(not nav.blocked(Vector2(820,580),Vector2(780,580),0),"real inside-cover escape semantics")
 nav.covers=[Rect2(400,24,50,1040)]
 check(not nav.route(Vector2(300,300),[],Vector2(600,300)).found,"unreachable target refuses")
 if errors==0:print("SOLO_NAVIGATION_TEST_OK")
 quit(1 if errors else 0)
