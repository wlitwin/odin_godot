extends SceneTree
var game:Node
var role:=""
var folder:=""
var rows:=[]
var finished:=false
func _initialize():role=OS.get_environment("RQ_FEEDBACK_ROLE");folder=OS.get_environment("RQ_FEEDBACK_DIR");run.call_deferred()
func p(key:String,seat:int=1)->int:return int(game.probe(key,seat))
func f(key:String,seat:int=1)->float:return float(game.feedback_probe(key,seat))
func exists(name:String)->bool:return FileAccess.file_exists(folder+"/"+name+".json")
func write(name:String,value:Dictionary):
 var file:=FileAccess.open(folder+"/"+name+".json.tmp",FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close();file=null
 assert(DirAccess.rename_absolute(folder+"/"+name+".json.tmp",folder+"/"+name+".json")==OK)
func frames(n:int):
 for _i in range(n):await process_frame
func until(test:Callable,ms:int=15000)->bool:
 var deadline:=Time.get_ticks_msec()+ms
 while Time.get_ticks_msec()<deadline:
  if test.call():return true
  await process_frame
 return false
func color_equal(a:Color,b:Color)->bool:return abs(a.r-b.r)<.001 and abs(a.g-b.g)<.001 and abs(a.b-b.b)<.001 and abs(a.a-b.a)<.001
func skin(seat:int)->Color:
 var node:Node=game.feedback_view("gunner",seat)
 return node.get_node("Skin").self_modulate if node else Color(0,0,0,0)
func separate_tints()->bool:
 for seat in [1,2]:
  var node:Node=game.feedback_view("gunner",seat)
  if not node or not color_equal(node.modulate,Color.WHITE):return false
  if not color_equal(node.get_node("Gun").self_modulate,Color(.16,.14,.12,1)):return false
  if not color_equal(node.get_node("Beam").self_modulate,Color(1,.9,.45,.85)):return false
 return true
func record(name:String):
 var c:=skin(2);rows.append({"name":name,"head":p("head"),"hp":p("hp",2),"life":p("life",2),"hurt":f("hurt"),"left":f("left",2),"landed":f("landed"),"speculative":f("speculative"),"dropped":f("dropped"),"rings":f("rings"),"skin":[c.r,c.g,c.b,c.a]})
func finish(code:int,reason:String):
 if finished:return
 finished=true;record("final");write("result-"+role,{"pass":code==0,"reason":reason,"rows":rows})
 print("RQ_FEEDBACK_", "OK" if code==0 else "FAIL", " ",role," ",reason)
 game.queue_free();game=null;await frames(3);quit(code)
func barrier(name:String)->bool:return exists(name+"-host") and exists(name+"-client") and exists(name+"-observer")
func run():
 root.size=Vector2i(640,360);game=load("res://quickdraw.tscn").instantiate();root.add_child(game)
 if not await until(func():return p("steady") and p("players")==2 and game.feedback_view("gunner",1) and game.feedback_view("gunner",2)):await finish(1,"initial scene");return
 game.drive(0,0,0,0,0)
 if not color_equal(skin(1),Color(.35,.65,1,1)) or not color_equal(skin(2),Color(1,.62,.2,1)) or not separate_tints():await finish(1,"original palette/material separation");return
 if f("hurt")!=0 or f("rings")!=0:await finish(1,"historical startup effects");return
 record("initial");write("ready-"+role,{"ready":true})
 if not await until(func():return barrier("ready")):await finish(1,"ready barrier");return
 if role=="host":
  game.drive(0,1,0,0,0)
  if not await until(func():return game.ui_probe("y",1)>=298):await finish(1,"firing lane");return
  game.drive(0,0,1,2,0)
  if not await until(func():return p("hits")>=1):await finish(1,"first damage");return
  game.drive(0,0,0,0,0)
 if not await until(func():return f("hurt")==1 and f("left",2)>0):await finish(1,"hurt pulse");return
 if not color_equal(skin(2),Color(1,.25,.2,1)) or not separate_tints():await finish(1,"red skin changed gun/beam");return
 record("hurt");write("hurt-"+role,{"ready":true})
 if not await until(func():return f("left",2)==0 and barrier("hurt")):await finish(1,"hurt decay");return
 if not color_equal(skin(2),Color(1,.62,.2,1)) or f("hurt")!=1:await finish(1,"palette restore or duplicate pulse");return
 write("faded-"+role,{"ready":true})
 if role=="host":
  if not await until(func():return barrier("faded")):await finish(1,"fade barrier");return
  game.drive(0,0,1,2,0)
  if not await until(func():return game.ui_probe("kills",1)==1):await finish(1,"kill");return
  game.drive(0,0,0,0,0)
 if not await until(func():return f("hp",2)==0 and f("left",2)>0):await finish(1,"lethal pulse");return
 record("lethal")
 if not color_equal(skin(2),Color(1,.25,.2,1)):await finish(1,"lethal flash precedence");return
 if not await until(func():return f("left",2)==0):await finish(1,"dead fade");return
 if not color_equal(skin(2),Color(.35,.32,.3,.55)) or not separate_tints():await finish(1,"dead skin/materials");return
 record("dead")
 if not await until(func():return p("life",2)>1 and p("hp",2)==3 and color_equal(skin(2),Color(1,.62,.2,1))):await finish(1,"respawn palette");return
 if f("left",2)!=0:await finish(1,"old-life flash on respawn");return
 record("respawn");write("respawn-"+role,{"ready":true})
 if not await until(func():return barrier("respawn")):await finish(1,"respawn barrier");return
 if role=="client":
  game.drive(0,0,4,0,0)
  if not await until(func():return p("lobs")>=1):await finish(1,"lob submission");return
  game.drive(0,0,0,0,0)
 if not await until(func():return f("rings")==1):await finish(1,"landing ring");return
 var ring:MeshInstance2D=game.feedback_view("ring",1)
 if not ring or abs(ring.position.x-255)>.2 or abs(ring.position.y-300)>.2:await finish(1,"detached landing pose");return
 var box:=ring.mesh.get_aabb()
 if abs(box.size.x-52)>.01 or abs(box.size.y-52)>.01 or ring.modulate.a<=0 or ring.modulate.a>1:await finish(1,"splash footprint/fade");return
 if role=="client" and f("speculative")<1:await finish(1,"own landing was not predicted");return
 record("landing");write("landed-"+role,{"ready":true})
 if OS.get_environment("RQ_FEEDBACK_CAPTURE")!="":
  await RenderingServer.frame_post_draw
  var image:=root.get_texture().get_image();image.save_png(OS.get_environment("RQ_FEEDBACK_CAPTURE"));image=null
 if not await until(func():return f("rings")==0 and barrier("landed")):await finish(1,"ring expiry");return
 if f("landed")!=1 or f("dropped")!=0:await finish(1,"duplicate/lost landing");return
 if role=="observer":
  game.on_leave();game.on_watch()
  if not await until(func():return p("steady") and p("players")==2 and game.feedback_view("gunner",2)):await finish(1,"observer rejoin");return
  await frames(30)
  if f("hurt")!=0 or f("landed")!=0 or f("rings")!=0:await finish(1,"rejoin replayed old feedback");return
 write("done-"+role,{"ready":true})
 if not await until(func():return barrier("done")):await finish(1,"finish barrier");return
 await finish(0,"health lifetime palette predicted landing and rejoin")
