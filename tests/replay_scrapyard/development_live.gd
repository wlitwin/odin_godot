extends "res://combat_test.gd"
var attempt:=0
var submitted:=false
func _initialize():
	super._initialize();participants=["host","client"];timeout_ms=30000
func _process(dt:float)->bool:
	if phase=="hash" or phase=="finish":return super._process(dt)
	if Time.get_ticks_msec()-started>timeout_ms:return fail("development timeout")
	if not p("ready"):return false
	match phase:
		"join":
			seat=p("seat");game.dev_drive(0,0,false);game.dev_loadout(0,0);phase="loadout"
		"loadout":
			if p("iron",seat)==0 and p("look",seat)==0:game.on_ready();phase="ready"
		"ready":
			if p("players")==2 and p("marked_ready",1) and p("marked_ready",2):
				if seat==1:game.on_start()
				phase="world"
		"world":
			if p("in_yard",1) and p("in_yard",2):phase="deny"
		"deny":
			if seat==2:
				if not submitted:
					var sequence:=0
					match attempt:
						0:sequence=game.dev_grant_cores(2,123456)
						1:sequence=game.dev_hurt(1,255)
						2:sequence=game.dev_jam(1)
						3:sequence=game.dev_status(1,2)
						4:sequence=game.dev_smite(2)
						5:sequence=game.dev_grant_scrap(2,123456)
					if sequence<=0:return fail("remote action was not submitted")
					submitted=true
				elif p("dev_result")==-1:
					if p("dev_reason")!=2:return fail("remote action rejection reason")
					attempt+=1;submitted=false
					if attempt==6:write("denied",{"count":6});phase="grant"
				elif p("dev_result")==1:return fail("remote development action admitted")
			elif not read("denied").is_empty():
				if p("hp",1)!=10 or p("gun_mode",1)!=0 or p("fx_mask",1)!=0 or p("cores",2)!=0 or p("scrap",2)!=0:return fail("remote action changed authority")
				if game.dev_grant_scrap(2,500)<=0 or game.dev_grant_cores(2,20)<=0:return fail("local authority submission")
				phase="grant"
		"grant":
			if p("cores",2)==20 and p("scrap",2)==500:
				print("RSY_DEVELOPMENT_AUTHORITY_OK role=",mode," rejected=6 granted_scrap=500 granted_cores=20")
				write("stopped-"+mode,{"ready":true});phase="hash"
	return false
