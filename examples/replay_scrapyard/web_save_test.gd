extends Node
var game:Node
var mode:=""
var phase:="join"
var started:=0
var captured:=0
var expected_tick:=""
var expected_hash:=""
var image_a:=""
var image_b:=""
func p(key:String)->int:return int(game.probe(key,1))
func query(key:String)->String:return str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('"+key+"')||''",true))
func _ready()->void:
	if not OS.has_feature("web"):set_process(false);return
	mode=query("save_test")
	if mode.is_empty():set_process(false);return
	game=get_parent();started=Time.get_ticks_msec()
	expected_tick=query("saved_tick");expected_hash=query("saved_hash");image_a=query("image_a");image_b=query("image_b")
func fail(reason:String)->void:
	print("RSS_FAIL phase=",phase," ",reason);set_process(false)
func _process(_delta:float)->void:
	if Time.get_ticks_msec()-started>75000:fail("timeout");return
	if p("save_error"):
		if mode in ["missing","identity","corrupt"] and not p("ready"):
			print("RSS_REJECTED mode=",mode);set_process(false);return
		fail("load");return
	var command=str(JavaScriptBridge.eval("globalThis.saveCommand||''",true))
	if command=="picker":
		JavaScriptBridge.eval("globalThis.saveCommand=''",true);game.on_spray_pick();print("RSS_PICKER_NEXT")
	if command=="conflict_save":
		JavaScriptBridge.eval("globalThis.saveCommand=''",true);captured=p("saved_tick")
		if not game.save_run() or not p("save_pending"):fail("submit conflicting save");return
		phase="conflict"
	if command=="slot_save":
		JavaScriptBridge.eval("globalThis.saveCommand=''",true);captured=p("head")
		if not game.save_run() or not p("save_pending"):fail("submit named slot");return
		phase="commit"
	match phase:
		"join":
			if not p("ready"):return
			game.dev_drive(0,0,false)
			if mode.begins_with("resume"):
				if str(p("restored_tick"))!=expected_tick or str(p("restored_hash"))!=expected_hash:fail("installed world differs");return
				if p("epoch")!=2 or p("seat")!=1 or p("casts")!=2 or p("lobs")!=1 or p("zones")!=1:fail("restored combat");return
				phase="land"
			elif mode in ["missing","identity","corrupt"]:fail("accepted invalid run");return
			else:
				game.dev_abilities(5,1)
				if mode=="create":game.on_spray_pick();print("RSS_PICKER")
				phase="loadout"
		"loadout":
			if p("ability0")==5 and p("ability1")==1:
				if mode=="create" and (p("spray_revision")!=1 or p("spray_storing")):return
				game.on_ready();phase="ready"
		"ready":
			if p("marked_ready"):game.on_start();phase="world"
		"world":
			var expected:=image_a if mode=="create" else image_b
			if p("in_yard") and game.spray_id(1)==expected:
				if not game.stamp():fail("stamp");return
				if mode=="create":
					if not game.dev_cast(0,500.0,1040.0,true) or not game.dev_cast(1,800.0,1040.0,true):fail("combat setup");return
					phase="save"
				else:phase="preference"
		"preference":
			if p("spray_cached") and p("spray_visible") and p("spray_stamp")==1 and p("spray_revision")==2:
				print("RSS_PREFERENCE_RESTORED image=",game.spray_id(1))
				if mode=="slot":phase="await_command"
				else:set_process(false)
		"save":
			if p("casts")==2 and p("lobs")==1 and p("zones")==1 and p("spray_stamp")==1:
				captured=p("head")
				if not game.save_run() or not p("save_pending") or p("saved_tick")!=0:fail("submission is not a save receipt");return
				phase="commit"
		"commit":
			if not p("save_pending"):
				if p("saved_tick")!=captured or p("save_revision")!=1:fail("save completion");return
				var result:={"tick":str(p("saved_tick")),"hash":str(p("saved_hash")),"image":game.spray_id(1)}
				JavaScriptBridge.eval("globalThis.saveReceipt="+JSON.stringify(result)+";0",true)
				print("RSS_SAVED tick=",p("saved_tick")," hash=",p("saved_hash"));phase="replacement"
		"replacement":
			if p("spray_revision")==2 and not p("spray_storing") and game.spray_id(1)==image_b:
				print("RSS_PREFERENCE_CHANGED");phase="await_command"
		"conflict":
			if not p("save_pending"):
				if p("saved_tick")!=captured or p("save_ok"):fail("conflict replaced save receipt");return
				print("RSS_SAVE_CONFLICT");set_process(false)
		"land":
			if game.spray_id(1)!=image_a:fail("preference replaced checkpoint image");return
			if p("landed")==1:
				if p("casts")!=2 or p("zones")!=1 or not p("spray_cached") or not p("spray_visible") or p("spray_stamp")!=1:fail("restored dependency/action");return
				game.dev_aim(1.0,0.0,true);phase="continued"
		"continued":
			if p("shots")>0 and p("damage")>0:
				game.dev_aim(1.0,0.0,false)
				print("RSS_RESUME_OK mode=",mode," tick=",p("restored_tick")," hash=",p("restored_hash")," image=",game.spray_id(1)," landed=",p("landed")," shots=",p("shots"))
				set_process(false)
