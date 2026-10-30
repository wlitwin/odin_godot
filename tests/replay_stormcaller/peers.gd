extends "res://combat_test.gd"
var saw_warning:=false
var moved:=false
func warning() -> Node2D:
	for child in game.get_node("World").get_children():
		var charge:=child.get_node_or_null("Charge") as Node2D
		if charge!=null and child.visible and charge.visible:return child
	return null
func _process(dt:float)->bool:
	if phase=="hash" or phase=="finish":return super._process(dt)
	if Time.get_ticks_msec()-started>timeout_ms:return fail("storm timeout")
	if phase!="join" and not p("ready"):return false
	var node:=warning()
	if node!=null:
		if abs(node.get_node("Telegraph").scale.x-140.0/180.0)>.002:return fail("warning radius differs from model")
		saw_warning=true
	match phase:
		"join":
			if p("ready"):
				seat=p("seat")
				if seat>0:game.on_ready()
				phase="ready"
		"ready":
			if p("players")==2 and p("marked_ready",1) and p("marked_ready",2):
				if seat==1:game.on_start()
				phase="pulse"
		"pulse":
			if seat==2 and node!=null and not moved:game.dev_drive(1,0,false);moved=true
			if p("hp",1)==8:
				if p("hp",2)!=10:return fail("dodging player was hit")
				if not saw_warning:return fail("warning/charge never presented")
				if seat==2:game.dev_drive(0,0,false)
				write("pulse-"+mode,{"tick":p("head")});phase="barrier"
		"barrier":
			for role in participants:
				if read("pulse-"+role).is_empty():return false
			if seat==1:game.dev_combat(true)
			phase="defeat"
		"defeat":
			if p("mobs")==0:
				if seat==1:game.dev_combat(false)
				acted=Time.get_ticks_msec();phase="settle"
		"settle":
			if Time.get_ticks_msec()-acted>1000:
				if p("hp",1)!=8 or p("hp",2)!=10:return fail("pulse repeated or dead enemy fired")
				print("STORMCALLER_PEER_OK role=",mode," warning=true radius=140 hp=8/10 killed=true")
				write("stopped-"+mode,{"ready":true});phase="hash"
	return false
