extends SceneTree
var game: Node
func _initialize(): run.call_deferred()
func p(key: String) -> int: return int(game.probe(key, int(game.probe("seat",1)) if game != null else 1))
func until(predicate: Callable, ms := 20000) -> bool:
	var end := Time.get_ticks_msec()+ms
	while Time.get_ticks_msec()<end:
		if predicate.call(): return true
		await process_frame
	return false
func finish(code: int, reason := ""):
	if reason != "": print("RSY_AUTO_FAIL ",reason)
	game.queue_free(); game=null; await process_frame; await process_frame; await create_timer(0.3).timeout
	quit(code)
func saved(mask: int) -> bool: return p("profile_loaded") and p("saved_automatic")==mask and not p("profile_writing") and not p("profile_error")
func run():
	game=load("res://main.tscn").instantiate();root.add_child(game)
	var mode:=OS.get_environment("RSY_AUTO_PHASE")
	if mode=="early":
		if not await until(func():return p("ready")):await finish(1,"early admission");return
		game.on_ready();game.dev_abilities(5,6)
	if not await until(func():return p("ready") and p("meta_claimed") and p("profile_loaded")):await finish(1,"profile ready");return
	if mode=="early":
		if not await until(func():return p("ability0")==5 and p("ability1")==6 and saved(3)):await finish(1,"admission replaced queued explicit choices");return
		print("REPLAY_AUTOMATIC_EARLY_OK mask=3 q=5 e=6")
	elif mode=="create":
		if p("seat")!=1 or p("automatic")!=15 or p("look")!=1 or p("iron")!=0:await finish(1,"new automatic defaults");return
		var methods:=["on_look","on_iron","on_ability0","on_ability1"]
		var reverse:=["on_look_prev","on_iron_prev","on_ability0_prev","on_ability1_prev"]
		for index in range(4):
			var mask:=15 & ~(1<<index);var writes:=p("profile_writes")
			game.call(methods[index])
			if not await until(func():return saved(mask) and p("profile_writes")>writes):await finish(1,"explicit preference commit");return
			game.call(reverse[index])
			if not await until(func():return saved(15)):await finish(1,"automatic preference commit");return
		if not "By seat" in game.get_node("UI/Lobby/Scroll/Layout/Picked").text:await finish(1,"automatic label");return
		print("REPLAY_AUTOMATIC_CREATED seat=1 look=1 iron=0 mask=15")
	elif mode=="client":
		if not await until(func():return p("seat")==2 and p("look")==2 and p("iron")==1 and saved(15)):await finish(1,"automatic did not follow new seat");return
		print("REPLAY_AUTOMATIC_RESEATED seat=2 look=2 iron=1 mask=15")
		game.dev_loadout(2,5);game.dev_abilities(5,6)
		if not await until(func():return p("look")==2 and p("iron")==5 and p("ability0")==5 and p("ability1")==6 and saved(0)):await finish(1,"explicit loadout save");return
		print("REPLAY_AUTOMATIC_EXPLICIT_SAVED mask=0")
	elif mode=="explicit":
		if p("seat")!=1 or p("look")!=2 or p("iron")!=5 or p("ability0")!=5 or p("ability1")!=6 or not saved(0):await finish(1,"explicit choice re-resolved");return
		print("REPLAY_AUTOMATIC_EXPLICIT_RELOADED seat=1 look=2 iron=5 mask=0")
	else:await finish(1,"unknown mode");return
	await finish(0)
