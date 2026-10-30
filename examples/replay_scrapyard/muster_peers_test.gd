extends "res://combat_test.gd"
var initial_look := 0

func roster(index: int) -> Control: return game.get_node("UI/Lobby/Scroll/Layout/Roster/Row" + str(index))
func press_pick(path: String): game.get_node("UI/Lobby/Scroll/Layout/" + path).pressed.emit()
func _process(dt: float) -> bool:
	if phase == "hash" or phase == "finish": return super._process(dt)
	if Time.get_ticks_msec() - started > 35000: return fail("muster peers timeout")
	match phase:
		"join":
			if p("ready"):
				seat = p("seat"); phase = "staging"
		"staging":
			if p("players") != 2 or not p("meta_claimed",1) or not p("meta_claimed",2): return false
			if not game.get_node("UI/Lobby").visible or game.get_node("World").visible or not roster(0).visible or not roster(1).visible or roster(2).visible: return fail("staging roster")
			var actions := game.get_node("UI/Lobby/Scroll/Layout/Actions") as Control
			if actions.visible != (seat > 0): return fail("observer controls")
			if seat == 1 and not game.get_node("UI/Lobby/Scroll/Layout/Actions/Start").disabled: return fail("start without ready guest")
			if seat != 1 and game.get_node("UI/Lobby/Scroll/Layout/Actions/Start").is_visible_in_tree(): return fail("foreign start")
			initial_look = p("look",2)
			write("muster-" + mode,{"ready":true});phase = "barrier"
		"barrier":
			for role in participants:
				if read("muster-" + role).is_empty(): return false
			if seat == 2: press_pick("Actions/Ready")
			phase = "ready-lamp"
		"ready-lamp":
			if not p("marked_ready",2) or roster(1).get_node("Lamp").text != "READY": return false
			write("lamp-"+mode,{"ready":true});phase="pick"
		"pick":
			for role in participants:
				if read("lamp-"+role).is_empty(): return false
			if seat==2:press_pick("Picks/Look")
			phase="changed"
		"changed":
			if p("look",2)!=0 or p("marked_ready",2) or roster(1).get_node("Lamp").text!="...":return false
			var body:=roster(1).get_node("Body") as Sprite2D
			if not body.texture.resource_path.ends_with("runner_" + ["becca","joe","unknow"][p("look",2)] + "_idle.png") or body.frame!=0:return fail("remote preview")
			write("changed-"+mode,{"ready":true});phase="start"
		"start":
			for role in participants:
				if read("changed-"+role).is_empty():return false
			if seat==2:press_pick("Actions/Ready")
			phase="started"
		"started":
			if seat==1 and p("stage")==0 and p("marked_ready",2):
				if p("marked_ready",1):return fail("host shortcut setup")
				press_pick("Actions/Start");phase="entered"
			elif seat!=1:phase="entered"
		"entered":
			if not p("in_yard",1) or not p("in_yard",2):return false
			if game.get_node("UI/Lobby").visible or not game.get_node("World").visible:return false
			if not p("marked_ready",1):return fail("start bypassed readiness")
			print("REPLAY_MUSTER_PEER_OK role=",mode," rows=2 preview=true unready=true observer_controls=true start_shortcut=true")
			write("stopped-"+mode,{"ready":true});phase="hash"
	return false
