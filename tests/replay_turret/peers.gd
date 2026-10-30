extends "res://combat_test.gd"

var migration:bool=false
var member:int=0
var initial_operator:int=1
var next_operator:int=2
var deploy_sent:bool=false
var first_mount:bool=false
var blocked_request:bool=false
var firing:bool=false
var first_done:bool=false
var released:bool=false
var second_mount:bool=false
var second_firing:bool=false
var restored:bool=false
var settled:int=0
var observer_warning:bool=false

func _initialize():
	super._initialize()
	member=int(OS.get_environment("RSY_MEMBER"));migration=member>0
	if migration:
		directory=OS.get_environment("REPLAY_MIGRATION_DIR")
		mode="host" if member==2 else "client" if member==3 else "observer"
		participants=["host","client"];initial_operator=2;next_operator=3
	timeout_ms=65000
func tp(key:String,who:int=1)->int:return game.turret_probe(key,who)
func _process(dt:float)->bool:
	if phase in ["hash","finish"]:return super._process(dt)
	if Time.get_ticks_msec()-started>timeout_ms:
		print("TURRET_DIAG phase=",phase," seat=",seat," count=",tp("count")," operator=",tp("operator")," ammo=",tp("ammo")," epoch=",p("epoch"))
		return fail("turret deadline")
	if not p("ready"):return false
	match phase:
		"join":
			seat=p("seat")
			game.dev_aim(1,0,false)
			if seat==1:game.dev_abilities(7,2)
			phase="loadout"
		"loadout":
			if seat==1 and p("ability0",1)!=7:return false
			if seat>0:game.on_ready()
			phase="ready"
		"ready":
			var wanted:=3 if migration else 2
			if p("players")!=wanted:return false
			for who in range(1,wanted+1):
				if not p("marked_ready",who):return false
			if seat==1:game.on_start()
			phase="deploy"
		"deploy":
			if p("stage")!=1:return false
			if seat==1 and not deploy_sent:deploy_sent=game.dev_cast(0,630,1040,true)
			if tp("count")!=1:return false
			if tp("ammo")!=24:return fail("authored ammo")
			if tp("views")!=1:return false
			observer_warning=true;phase="first"
		"first":
			if seat==initial_operator and not first_mount:
				first_mount=game.dev_turret_use();return false
			if tp("operator")!=initial_operator:return false
			if seat==next_operator and not blocked_request:blocked_request=game.dev_turret_use()
			if seat==next_operator and tp("refused")>0:write("busy-rejected",{"ready":true})
			if read("busy-rejected").is_empty():return false
			if seat==initial_operator and not firing:game.dev_aim(1,0,true);firing=true
			if seat==initial_operator and tp("ammo")<=18 and not first_done:
				game.dev_aim(1,0,false);first_done=true;acted=Time.get_ticks_msec()
			if seat==initial_operator and first_done and Time.get_ticks_msec()-acted>500:
				write("occupied",{"tick":p("head"),"ammo":tp("ammo"),"operator":initial_operator})
				phase="backup" if migration else "release"
			elif not read("occupied").is_empty():phase="backup" if migration else "release"
		"backup":
			var occupied:=read("occupied")
			if member==2 and p("backup_tick")>=int(occupied.tick):write("occupied-backed-up",{"tick":p("backup_tick")})
			if member==1 and not read("occupied-backed-up").is_empty():write("kill_owner",{"tick":p("head")});phase="recover"
			if p("epoch")==2:phase="recover"
		"recover":
			if p("epoch")!=2 or not p("recovery_ready"):return false
			var occupied:=read("occupied")
			if tp("count")!=1 or tp("operator")!=initial_operator or tp("ammo")!=int(occupied.ammo):return fail("occupied turret changed on authority takeover")
			write("restored-"+str(member),{"ammo":tp("ammo")});restored=true
			print("TURRET_OCCUPIED_RESTORED member=",member," operator=",tp("operator")," ammo=",tp("ammo")," epoch=",p("epoch"))
			phase="release"
		"release":
			if migration and (read("restored-2").is_empty() or read("restored-3").is_empty()):return false
			if seat==initial_operator and not released:released=game.dev_turret_use()
			if tp("operator")==0:phase="handoff"
		"handoff":
			if seat==next_operator and not second_mount:second_mount=game.dev_turret_use()
			if tp("operator")!=next_operator:return false
			if tp("ammo")!=int(read("occupied").ammo):return fail("handoff refilled/spent ammo")
			write("handoff-"+mode,{"ready":true});phase="empty"
		"empty":
			for role in participants:
				if read("handoff-"+role).is_empty():return false
			if seat==next_operator and not second_firing:game.dev_aim(1,0,true);second_firing=true
			if tp("count")!=0:return false
			game.dev_aim(1,0,false)
			if tp("mounted",next_operator)!=0:return fail("empty turret left occupancy")
			# Spectators render the delayed observation, so its scene drains after
			# authoritative despawn. The overall deadline still bounds this wait.
			if tp("views")!=0:return false
			settled=Time.get_ticks_msec();phase="settle"
		"settle":
			if Time.get_ticks_msec()-settled<700:return false
			if not observer_warning:return fail("turret view never appeared")
			print("REPLAY_TURRET_PEER_OK mode=",mode," shared=true contention=true handoff=true exhausted=true dismounted=true")
			write("stopped-"+mode,{"ready":true});phase="hash"
	return false
