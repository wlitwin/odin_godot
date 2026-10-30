extends Node
var mode:=""
var phase:="load"
var game:Node
var started:=0
func p(key:String)->int:return int(game.probe(key,1))
func _ready():
	if not OS.has_feature("web"):set_process(false);return
	mode=str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('settings_test')||''",true))
	if mode=="":set_process(false);return
	game=get_parent();started=Time.get_ticks_msec()
func fail(reason:String):print("RSY_BROWSER_SETTINGS_FAIL ",reason);set_process(false)
func _process(_dt:float):
	if Time.get_ticks_msec()-started>60000:fail("timeout");return
	if p("settings_error")==1:
		if mode in ["conflict","corrupt"]:
			print("RSY_BROWSER_SETTINGS_REJECTED mode=",mode);set_process(false);return
		fail("storage");return
	if not p("ready") or p("settings_pending"):return
	match phase:
		"load":
			if mode=="create":
				if p("volume")!=8:fail("default volume");return
				for _i in 5:game.on_volume_down()
				game.on_shake();phase="saved"
			else:
				if p("volume")!=3 or p("shake_off")!=1:fail("restored settings");return
				if mode=="conflict":print("RSY_BROWSER_SETTINGS_WAIT");phase="edit"
				else:print("RSY_BROWSER_SETTINGS_RELOADED");set_process(false)
		"saved":
			if p("volume")!=3 or p("shake_off")!=1:fail("save value");return
			print("RSY_BROWSER_SETTINGS_SAVED");set_process(false)
		"edit":
			if JavaScriptBridge.eval("globalThis.settingsCommand==='edit'",true):
				JavaScriptBridge.eval("globalThis.settingsCommand=''",true);game.on_volume_up()
