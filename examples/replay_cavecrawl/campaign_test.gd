extends SceneTree
var restart_active:=false
var restart_complete:=false
var restart_sent:=false
var game:Node
var role:=""
var directory:=""
var phase:=""
var started:=0
var entered:=0
var acted:=false
var next_try:=0
var shots:=0
var reject_before:=0
var pickup_old:={}
var closing:=false
var wave_seen:={}
var deaths_checked:=false
var proposal:=0
var answered:=0
const ORDER:=["join","loot","drop","grab","carry","setdown","positions","death","revive","stale","reclaim","heal","respawn_positions","bleedout","regather","fight1","exit1","loot2","fight2","exit2","hash"]
func _initialize():
	role=OS.get_environment("REPLAY_CAVE_ROLE");directory=OS.get_environment("REPLAY_CAMPAIGN_DIR")
	game=load("res://cave.tscn").instantiate();root.add_child(game);started=Time.get_ticks_msec()
	if role=="host":write("phase",{"name":"join"})
func p(key:String,index:int=1)->int:return int(game.campaign_probe(key,index)) if game!=null else -1
func pos(seat:int)->Vector2:return Vector2(p("x",seat),p("y",seat))
func near(seat:int,target:Vector2,distance:float=9)->bool:return pos(seat).distance_to(target)<=distance
func read(name:String)->Dictionary:
	var path:=directory+"/"+name+".json"
	return JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
func write(name:String,value:Dictionary):
	var path:=directory+"/"+name+".json";var file:=FileAccess.open(path+".pending",FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close();DirAccess.rename_absolute(path+".pending",path)
func done():
	if read(phase+"-"+role).is_empty():
		write(phase+"-"+role,{"head":p("clock"),"depth":p("depth"),"gems":p("gem_total"),"slain":p("slain",1)+p("slain",2)})
		print("CAVE_CAMPAIGN_PHASE role=",role," phase=",phase," tick=",p("clock"))
func fail(reason:String):
	print("CAVE_CAMPAIGN_FAIL role=",role," phase=",phase," ",reason," depth=",p("depth")," hp=",p("hp",1),"/",p("hp",2)," mobs=",p("mobs")," wave=",p("wave")," stamina=",p("stamina",1),"/",p("stamina",2)," position=",pos(1),"/",pos(2))
	finish(1)
func finish(code:int):
	if closing:return
	if code==0 and OS.get_environment("REPLAY_CAMPAIGN_RESTART")=="1" and not restart_complete:
		restart_active=true;write("restart-armed-"+role,{"done":true});return
	closing=true;game.queue_free();game=null;await process_frame;await process_frame;quit(code)
func gem_pickup()->Dictionary:
	for index in 48:
		if p("pickup_alive",index)==1 and p("pickup_item",index)==1:return {"index":index,"generation":p("pickup_generation",index),"x":p("pickup_x",index),"y":p("pickup_y",index)}
	return {}
func _process(_dt:float)->bool:
	if closing:return false
	var now:=Time.get_ticks_msec()
	if now-started>160000:fail("campaign timeout");return false
	if not game.probe_ready():return false
	if restart_active:return restart_frame()
	var requested:=str(read("phase").get("name","join"))
	if phase!=requested:
		phase=requested;acted=false;next_try=0;shots=0;entered=now;reject_before=p("rejected")
	var seat:=1 if role=="host" else 2
	if role=="observer" and phase!="hash":done()
	elif read(phase+"-"+role).is_empty() or phase=="hash":
		match phase:
			"join":
				if game.probe_players()==2 and p("gem_total")==3:done()
			"loot":
				if role=="host":
					game.walk_to(300,180)
					if near(1,Vector2(300,180)) and not acted:game.loot(0);acted=true
					if p("bag_gems",1)==3:done()
				else:done()
			"drop":
				if role=="host":
					if not acted:game.drop(0);acted=true
					var item:=gem_pickup()
					if not item.is_empty() and p("bag_gems",1)==0:write("original-pickup",item);done()
				else:done()
			"grab","reclaim":
				if role=="client":
					var item:=gem_pickup()
					if not item.is_empty():
						game.walk_to(item.x,item.y)
						if near(2,Vector2(item.x,item.y),30) and not acted:game.grab(item.index,item.generation);acted=true
					if p("bag_gems",2)==3 and gem_pickup().is_empty():done()
				elif p("bag_gems",2)==3:done()
			"carry":
				if role=="host":
					game.walk_to(120,80)
					if near(1,Vector2(120,80)) and not acted:game.carry();acted=true
				if p("carrier")==1:done()
			"setdown":
				if role=="host":
					game.walk_to(190,120)
					if near(1,Vector2(190,120)) and not acted:game.set_down();acted=true
				if p("carrier")==0 and p("relic_version")>=3:done()
			"positions","respawn_positions":
				var target:=Vector2(140,120) if role=="host" else Vector2(220,120)
				game.walk_to(target.x,target.y)
				if near(seat,target):done()
			"death":
				if role=="host" and p("hp",2)>0 and p("rock_cd",1)==0 and p("stamina",1)>=3 and now>=next_try:
					var aim:=pos(2)-pos(1);game.throw(aim.x,aim.y);shots+=1;next_try=now+1200
				if p("hp",2)==0 and p("deaths",2)==1:
					if p("bag_gems",2)!=0 or p("gem_total")!=3:fail("death spill conservation");return false
					done()
			"revive":
				if role=="host":
					var friend:=pos(2);game.walk_to(friend.x,friend.y)
					if near(1,friend,30) and not acted:game.revive(2);acted=true
				if p("hp",2)==30 and p("respawn",2)==0:done()
				elif p("hp",2)==100:fail("respawn happened before revive");return false
			"stale":
				if role=="client":
					var old:=read("original-pickup");var current:=gem_pickup()
					if current.is_empty():return false
					if current.index!=old.index or current.generation<=old.generation:fail("pickup slot was not recycled");return false
					if not acted:game.grab(old.index,old.generation);acted=true
					if p("rejected")>reject_before:
						if p("bag_gems",2)!=0 or p("gem_total")!=3:fail("stale handle changed inventory");return false
						done()
				else:done()
			"heal":
				if role=="client" and not acted:game.heal();acted=true
				if p("hp",2)==55:done()
			"bleedout":
				if p("deaths",2)<2 and role=="host" and p("rock_cd",1)==0 and p("stamina",1)>=3 and now>=next_try:
					var aim:=pos(2)-pos(1);game.throw(aim.x,aim.y);next_try=now+1200
				if p("deaths",2)==2 and p("hp",2)==0 and read("respawn-deadline").is_empty() and role=="host":write("respawn-deadline",{"tick":p("respawn",2)})
				if p("deaths",2)==2 and p("hp",2)==100:
					var deadline:=read("respawn-deadline")
					if deadline.is_empty() or p("clock")<int(deadline.tick) or not near(2,Vector2(80,120),10) or p("bag_gems",2)!=0 or p("gem_total")!=3:fail("bleedout/respawn contract");return false
					done()
			"regather":
				if role=="client":
					var item:=gem_pickup()
					if not item.is_empty():
						game.walk_to(item.x,item.y)
						if near(2,Vector2(item.x,item.y),30) and not acted:game.grab(item.index,item.generation);acted=true
					if p("bag_gems",2)==3 and gem_pickup().is_empty():done()
				elif p("bag_gems",2)==3:done()
			"fight1","fight2":
				var depth:=p("depth");wave_seen[str(depth)+"/"+str(p("wave"))]=true
				var target:=Vector2(160,40 if role=="host" else 320) if depth==1 else Vector2(340,100 if role=="host" else 300)
				game.walk_to(target.x,target.y)
				if near(seat,target) and p("rock_cd",seat)==0 and p("stamina",seat)>=3 and now>=next_try:
					for index in 16:
						if p("mob_alive",index)!=1:continue
						var point:=Vector2(p("mob_x",index),p("mob_y",index))
						if (point.y<180)!=(role=="host"):continue
						var aim:=point-pos(seat);game.throw(aim.x,aim.y);next_try=now+1200;break
				if p("done")==1 and p("mobs")==0 and p("rocks")==0:
					if not wave_seen.has(str(depth)+"/1") or not wave_seen.has(str(depth)+"/2"):fail("wave progression was skipped");return false
					if p("slain",1)+p("slain",2)!=(5 if depth==1 else 12):fail("slain total");return false
					done()
			"exit1","exit2":
				var expected_depth:=1 if phase=="exit1" else 2
				if p("depth")==expected_depth and p("won")==0:
					var target:=Vector2(560,180) if expected_depth==1 else Vector2(90,300)
					game.walk_to(target.x,target.y)
					if role=="host" and near(1,target) and not game.probe_door() and not acted:game.door();acted=true
				if (expected_depth==1 and p("depth")==2) or (expected_depth==2 and p("won")==1):done()
			"loot2":
				if role=="client":
					game.walk_to(200,260)
					if near(2,Vector2(200,260)) and not acted:game.loot(0);acted=true
					if p("bag_gems",2)==8:done()
				else:done()
			"hash":
				# The shared phase file can arrive before this peer's authority
				# observation. Judge totals only once the completion tick is visible.
				if p("clock")<int(read("exit2-host").get("head",0)):return false
				if p("won")!=1 or p("gem_total")!=8 or p("slain",1)+p("slain",2)!=12:fail("victory totals");return false
				if role=="host":
					var ready:=proposal!=0;var retry:=proposal==0;var expected:=""
					for peer in ["host","client","observer"]:
						var answer:=read("hash-"+peer)
						if int(answer.get("tick",0))!=proposal:ready=false
						elif str(answer.get("hash","-1"))=="-1":retry=true
						elif expected=="":expected=str(answer.hash)
						elif expected!=str(answer.hash):fail("whole world mismatch");return false
					if retry:
						var minimum:=0
						for peer in ["host","client","observer"]:minimum=maxi(minimum,int(read("exit2-"+peer).get("head",0)))
						if p("clock")-10>=minimum:proposal=p("clock")-10;write("proposal",{"tick":proposal})
					elif ready:write("finish",{"tick":proposal,"hash":expected})
				var tick:=int(read("proposal").get("tick",0))
				if tick>0 and tick!=answered:answered=tick;write("hash-"+role,{"tick":tick,"hash":str(game.campaign_hash(tick))})
				var result:=read("finish")
				if not result.is_empty():
					if read("complete-"+role).is_empty():
						print("REPLAY_CAVE_CAMPAIGN_OK role=",role," depth=2 slain=12 gems=8 deaths=",p("deaths",2)," hash=",result.hash," tick=",result.tick);write("complete-"+role,{"done":true,"drops":p("fault_drops"),"duplicates":p("fault_duplicates"),"deaths":p("deaths",2),"damage":p("damage",1)+p("damage",2)})
					if not read("complete-host").is_empty() and not read("complete-client").is_empty() and not read("complete-observer").is_empty():finish(0)
	if role=="host" and phase!="hash":
		var complete:=true
		for peer in ["host","client","observer"]:
			if read(phase+"-"+peer).is_empty():complete=false
		if complete:write("phase",{"name":ORDER[ORDER.find(phase)+1]})
	return false

func restart_frame()->bool:
	for peer in ["host","client","observer"]:
		if read("restart-armed-"+peer).is_empty():return false
	if role=="host" and not restart_sent:
		var button:Button=game.get_node("Lobby/Panel/Column/Buttons/Start")
		if not button.visible or button.text!="Another run":fail("missing restart button");return false
		button.pressed.emit();restart_sent=true
	if game.lobby_probe("run",0)!=2:return false
	if p("depth")!=1 or p("won")!=0 or p("gem_total")!=3 or p("bag_gems",1)!=0 or p("bag_gems",2)!=0 or p("slain",1)+p("slain",2)!=12 or p("deaths",2)!=2:
		fail("restart did not reset run while retaining ledger");return false
	if game.lobby_name(1)!="Seat 1" or game.lobby_name(2)!="Seat 2":fail("restart lost profiles");return false
	if read("restart-done-"+role).is_empty():
		print("REPLAY_CAVE_RESTART_OK role=",role," run=2 profiles_retained=true slain=12 deaths=2 fresh_gems=3")
		write("restart-done-"+role,{"run":2,"gems":3,"slain":12,"deaths":2})
	for peer in ["host","client","observer"]:
		if read("restart-done-"+peer).is_empty():return false
	restart_complete=true;finish(0);return false
