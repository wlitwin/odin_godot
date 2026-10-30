extends Node
var mode := ""
var phase := "join"
var entered_floor := 1
var started := 0
var game: Node
func p(key:String) -> int: return int(game.probe(key,1))
func _ready() -> void:
	if not OS.has_feature("web"):set_process(false);return
	mode=str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('profile_test')||''",true))
	if mode.is_empty():set_process(false);return
	game=get_parent();started=Time.get_ticks_msec()
func fail(reason:String) -> void:
	print("RSY_BROWSER_PROFILE_FAIL phase=",phase," ",reason)
	set_process(false)
func _process(_delta:float) -> void:
	if Time.get_ticks_msec()-started>150000:fail("timeout");return
	if p("profile_error"):
		if mode in ["corrupt","conflict"]:
			if mode=="corrupt" and p("ready"):fail("opened corrupt profile");return
			print("RSY_BROWSER_PROFILE_REJECTED mode=",mode)
			set_process(false);return
		fail("profile write");return
	match phase:
		"join":
			if p("ready"):
				if mode=="earn":game.dev_loadout(2,1);game.dev_abilities(5,6)
				phase="loadout"
		"loadout":
			if p("look")==2 and p("iron")==1 and p("ability0")==5 and p("ability1")==6 and not p("profile_writing"):
				if mode!="earn" and (p("parts")!=2 or p("cores")!=0 or not p("profile_loaded")):fail("restored profile");return
				if mode=="conflict":
					print("RSY_BROWSER_PROFILE_WAIT revision=",p("profile_revision"));phase="conflict"
				else:game.on_ready();phase="ready"
		"conflict":
			if JavaScriptBridge.eval("globalThis.profileCommand==='edit'",true):
				JavaScriptBridge.eval("globalThis.profileCommand=''",true)
				game.dev_loadout(1,2)
		"ready":
			if p("marked_ready"):game.on_start();phase="world"
		"world":
			if p("stage")==1 and p("in_yard"):
				if mode=="load":
					if p("hp")!=14 or p("parts")!=2:fail("plate at entry");return
					print("RSY_BROWSER_PROFILE_RELOADED revision=",p("profile_revision")," hp=",p("hp")," parts=",p("parts"))
					set_process(false);return
				game.dev_combat(true);phase="fight"
		"fight":
			if p("stage")==2 and p("drops")==0:
				game.dev_combat(false)
				if entered_floor==1:game.dev_gate(true);phase="gate"
				else:
					if p("cores")!=2:fail("earned cores");return
					if not game.dev_buy(1,true):fail("buy plate");return
					phase="saved"
		"gate":
			if p("floor")==2:entered_floor=2;game.dev_combat(true);phase="fight"
		"saved":
			if p("parts")==2 and p("cores")==0 and p("profile_writes")>=3 and not p("profile_writing"):
				print("RSY_BROWSER_PROFILE_EARNED revision=",p("profile_revision")," parts=",p("parts")," cores=",p("cores"))
				set_process(false)
