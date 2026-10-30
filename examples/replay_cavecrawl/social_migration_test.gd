extends "res://migration_test.gd"
var chat_before_sent:=false
var chat_before_done:=false
var chat_after_sent:=false
var chat_after_done:=false
func _process(dt:float)->bool:
	if Time.get_ticks_msec()-started>38000:return fail("social migration timeout")
	if not game.probe_ready() or game.social_probe("ready")!=1:return false
	var text:String=game.get_node("Social/Chat/Lines").text
	if not chat_before_done:
		if not chat_before_sent:game.on_chat("before migration member %d"%member);chat_before_sent=true
		for id in [1,2,3]:
			if not text.contains("before migration member %d"%id):return false
		chat_before_done=true
	if game.probe_epoch()==2 and game.probe_steady() and not chat_after_done:
		if not chat_after_sent:game.on_chat("after migration member %d"%member);chat_after_sent=true
		for id in [2,3]:
			if not text.contains("after migration member %d"%id):return false
		# The bounded full log survives locally; the view shows its newest four lines.
		if game.social_probe("lines")<5:return fail("migration lost local scrollback")
		print("REPLAY_CAVE_SOCIAL_MIGRATION_OK member=",member," epoch=2 lines=",game.social_probe("lines"))
		chat_after_done=true
	return super._process(dt)
