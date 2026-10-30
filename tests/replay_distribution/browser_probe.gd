extends Node
var phase:=0
var started:=0
func _ready():started=Time.get_ticks_msec()
func _process(_dt:float):
	var game=get_parent()
	if Time.get_ticks_msec()-started>15000:
		print("REPLAY_PACKAGE_BROWSER_FAIL timeout");set_process(false);return
	if game.probe("ready")!=1:return
	if phase==0:game.move(1);phase=1
	elif phase==1 and abs(game.probe("x")-320)<=18:game.move(0);game.take();phase=2
	elif phase==2 and game.probe("bag1")==1 and game.probe("coin")==0:
		print("REPLAY_PACKAGE_BROWSER_OK coin=0 bag1=1")
		set_process(false)
