extends Node
var game: Node
var member := 0
var mode := ""
var phase := "join"
var started := 0
var dependency_waited := false
var assets_ready := false
var expected := ""
var next_trace := 0
var collecting_hashes := false
var hashed_through := 0
func p(field: String, seat: int=1) -> int: return int(game.probe(field,seat))
func _ready() -> void:
	if not OS.has_feature("web"): set_process(false);return
	mode=str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('migration') || ''",true))
	if mode.is_empty(): set_process(false);return
	member=int(str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('member') || '0'",true)))
	expected=str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('spray_expected') || ''",true))
	game=get_parent();started=Time.get_ticks_msec()
func fail(reason: String) -> void:
	print("RSB_FAIL member=",member," phase=",phase," ",reason," head=",p("head")," room=",p("room_phase")," control=",p("control_error")," link=",p("link_error")," facts=",p("facts")," confirmed=",p("confirmed")," predicted=",p("predhead")," pending=",p("pending_snapshot")," full=",p("fullsnaps")," delta=",p("deltasnaps")," badacks=",p("badacks")," fragbad=",p("frag_rejected"))
	set_process(false)
func _process(_delta: float) -> void:
	if phase!="done" and Time.get_ticks_msec()>=next_trace:
		next_trace=Time.get_ticks_msec()+2000
		print("RSB_TRACE member=",member," phase=",phase," ready=",p("ready")," players=",p("players")," marked=",p("marked_ready",1),",",p("marked_ready",2),",",p("marked_ready",3)," abilities=",p("ability0",member),",",p("ability1",member)," netphase=",p("phase")," head=",p("head")," resyncs=",p("resyncs")," reason=",p("resync_reason")," deferred=",p("egress_deferred")," link=",p("link_error")," facts=",p("facts")," confirmed=",p("confirmed")," predicted=",p("predhead")," pending=",p("pending_snapshot")," full=",p("fullsnaps")," delta=",p("deltasnaps")," badacks=",p("badacks")," fragbad=",p("frag_rejected"))
	if phase!="done" and Time.get_ticks_msec()-started>150000: fail("timeout");return
	var command=str(JavaScriptBridge.eval("globalThis.rsbCommand || ''",true))
	if command=="health":
		JavaScriptBridge.eval("globalThis.rsbCommand=''",true)
		var health := {"ready":p("ready"),"epoch":p("epoch"),"resyncs":p("resyncs"),"fragment_rejections":p("frag_rejected"),"full_snapshots":p("fullsnaps"),"head":p("head")}
		JavaScriptBridge.eval("globalThis.rsbHealth="+JSON.stringify(health)+";0",true)
	if command=="hashes":
		JavaScriptBridge.eval("globalThis.rsbCommand=''",true)
		collecting_hashes=true
		hashed_through=p("head")
		JavaScriptBridge.eval("globalThis.rsbHashes={};0",true)
	if collecting_hashes and p("ready"):
		var hashes := {}
		var head := p("head")
		# Digest each newly retained frame once. Browser callbacks need not run
		# together, and the authority may have advanced by the time a peer sees it.
		var through := mini(head,hashed_through+8)
		for tick in range(maxi(hashed_through+1,head-127),through+1):
			var value = game.probe_hash(tick)
			if value!=-1: hashes[str(tick)]=str(value)
		hashed_through=through
		JavaScriptBridge.eval("Object.assign(globalThis.rsbHashes,"+JSON.stringify(hashes)+");Object.keys(globalThis.rsbHashes).slice(0,-1024).forEach(k=>delete globalThis.rsbHashes[k]);0",true)
	if command=="combat":
		JavaScriptBridge.eval("globalThis.rsbCommand=''",true)
		if not game.dev_cast(0,500.0,1040.0,true) or not game.dev_cast(1,800.0,1040.0,true): fail("combat setup");return
	if command=="handoff":
		JavaScriptBridge.eval("globalThis.rsbCommand=''",true)
		if not game.handoff(): fail("handoff refused");return
	match phase:
		"join":
			if p("ready"):
				if p("seat")!=member: fail("seat");return
				game.dev_drive(0,0,false)
				if member==2: game.dev_asset_pause(true)
				game.dev_abilities(5 if member==1 else 4,1 if member==1 else 6)
				if member==1:
					game.on_spray_pick()
					print("RSB_PICKER_READY")
				phase="loadout"
		"loadout":
			if p("ability0",member)==(5 if member==1 else 4) and p("ability1",member)==(1 if member==1 else 6):
				game.on_ready();phase="ready"
		"ready":
			if p("players")==3 and p("marked_ready",1) and p("marked_ready",2) and p("marked_ready",3):
				if member==1: game.on_start()
				phase="world"
		"world":
			if p("ready") and p("stage")==1 and p("in_yard",1) and p("in_yard",2) and p("in_yard",3):
				if member==1:
					if p("spray_bytes",1)==0: return
					if not game.stamp(): fail("stamp");return
				phase="backup"
		"backup":
			if member==2 and not dependency_waited and p("asset_prepare_wait"):
				if p("backup_spray"): fail("prepared missing asset");return
				dependency_waited=true;game.dev_asset_pause(false)
				print("RSB_DEPENDENCY_WAIT")
			if member==2 and dependency_waited and not assets_ready and p("backup_spray") and p("spray_cached",1):
				assets_ready=true;print("RSB_ASSETS_READY")
			if member==2 and p("active_backup") and p("backup_spray"):
				print("RSB_BACKUP_READY tick=",p("backup_tick")," bytes=",p("spray_bytes",1))
				phase="migration"
			if member!=2 and p("epoch")==2: phase="migration"
		"migration":
			if p("ready") and p("epoch")==2 and p("recovery_ready"):
				if p("seat")!=member or p("recovery_kind")!=(1 if mode=="planned" else 2): fail("recovery identity/kind");return
				if member==2:
					if not p("authority") or not p("restored_exact") or not p("restored_active") or not dependency_waited: fail("checkpoint restore");return
				phase="land"
		"land":
			if p("ready") and p("landed")>=1:
				if member==2:
					if not game.dev_cast(0,0.0,0.0,false) or not game.dev_cast(1,800.0,1040.0,true): fail("continued casts");return
				phase="continued"
		"continued":
			if p("ready") and p("casts",2)>=2 and p("landed")>=2 and p("reactions")>=2:
				if not p("spray_cached",1) or not p("spray_visible",1) or p("spray_stamp",1)!=1 or game.spray_id(1)!=expected: fail("spray recovery");return
				print("RSB_RECOVERED member=",member," checkpoint=",p("recovery_tick")," lost=",p("lost_ticks")," interruption_ms=",p("interruption")," spray_bytes=",p("spray_bytes",1)," casts=",p("casts",2)," landed=",p("landed")," reactions=",p("reactions"))
				phase="done"
