extends Node
const ViewProbe = preload("res://view_probe.gd")

# Opt-in browser acceptance bridge. Player interactions are driven through the
# real canvas; commands only prepare a world and request observations.
var game: Node
var handled := 0
var queried := 0
var collecting := false
var hashed_through := 0
var ordnance_watch := false
var ordnance_seen := {}
var ordnance := {}

var glob_watch := false
var glob_records := {}
var glob_active := {"lob":0,"spit":0}

var area_watch := false
var area_records := {}
var area_active := {"area":0,"zone":0,"buff":0}

var path_watch := false
var path_records := {}
var path_active := {"flame":0,"arc":0}

func collect_paths():
	path_active = {"flame":0,"arc":0}
	for child in game.get_node("World").get_children():
		var kind := ""
		if child is Label and child.visible and str(child.name).begins_with("Flame"): kind = "flame"
		elif ViewProbe.polygon(child) and child.visible and str(child.name).begins_with("Arc"): kind = "arc"
		if kind == "": continue
		path_active[kind] += 1
		var id := str(child.get_instance_id())
		var position: Vector2 = child.position + child.get_combined_minimum_size()/2 if kind == "flame" else child.position
		if not path_records.has(id):
			if path_records.size() >= 64: continue
			var row := {"kind":kind,"name":str(child.name),"first":xy(position),"last":xy(position),"samples":0}
			if kind == "flame": row.text = child.text
			else:
				var points := []
				for point in ViewProbe.vertices(child): points.append(xy((child.transform.x*point.x+child.transform.y*point.y)/child.transform.y.length()))
				row.points=points;row.depth=child.z_index;row.color=[ViewProbe.tint(child).r,ViewProbe.tint(child).g,ViewProbe.tint(child).b,ViewProbe.tint(child).a]
				row.min_alpha=ViewProbe.tint(child).a;row.max_alpha=ViewProbe.tint(child).a
			path_records[id]=row
		var record: Dictionary = path_records[id];record.samples+=1;record.last=xy(position)
		if kind == "arc": record.min_alpha=minf(record.min_alpha,ViewProbe.tint(child).a);record.max_alpha=maxf(record.max_alpha,ViewProbe.tint(child).a)

func collect_areas():
	area_active = {"area":0,"zone":0,"buff":0}
	for child in game.get_node("World").get_children():
		var kind := ""
		if ViewProbe.polygon(child) and child.visible:
			if str(child.name).begins_with("Area"): kind = "area"
			elif str(child.name).begins_with("Zone"): kind = "zone"
		elif child is CPUParticles2D and ViewProbe.tint(child).is_equal_approx(Color(1,0.9,0.4,1)): kind = "buff"
		if kind == "": continue
		area_active[kind] += 1
		var id := str(child.get_instance_id())
		if not area_records.has(id):
			if area_records.size() >= 32: continue
			var row := {"kind":kind,"name":str(child.name),"position":xy(child.position),"color":[ViewProbe.tint(child).r,ViewProbe.tint(child).g,ViewProbe.tint(child).b,ViewProbe.tint(child).a],"samples":0}
			if kind == "buff": row.amount = child.amount; row.lifetime = child.lifetime; row.one_shot = child.one_shot
			else:
				var radii := []
				for point in ViewProbe.vertices(child): radii.append(point.length())
				row.points = ViewProbe.vertices(child).size(); row.radii = radii; row.depth = child.z_index
				row.min_scale = child.scale.x; row.max_scale = child.scale.x; row.min_alpha = ViewProbe.tint(child).a; row.max_alpha = ViewProbe.tint(child).a
			area_records[id] = row
		var record: Dictionary = area_records[id]
		record.samples += 1
		if kind != "buff":
			record.min_scale = minf(record.min_scale,child.scale.x); record.max_scale = maxf(record.max_scale,child.scale.x)
			record.min_alpha = minf(record.min_alpha,ViewProbe.tint(child).a); record.max_alpha = maxf(record.max_alpha,ViewProbe.tint(child).a)

func collect_globs():
	glob_active = {"lob":0,"spit":0}
	for child in game.get_node("World").get_children():
		if not ViewProbe.polygon(child) or not child.visible: continue
		var kind := "lob" if str(child.name).begins_with("Lob") else "spit" if str(child.name).begins_with("Spit") else ""
		if kind == "": continue
		glob_active[kind] += 1
		var id := str(child.get_instance_id())
		if not glob_records.has(id):
			if glob_records.size() >= 32: continue
			var radii := []
			for point in ViewProbe.vertices(child): radii.append(point.length())
			glob_records[id] = {"kind":kind,"name":str(child.name),"points":ViewProbe.vertices(child).size(),"radii":radii,"color":[ViewProbe.tint(child).r,ViewProbe.tint(child).g,ViewProbe.tint(child).b,ViewProbe.tint(child).a],"depth":child.z_index,"first":xy(child.position),"last":xy(child.position),"min_scale":child.scale.x,"max_scale":child.scale.x,"samples":0}
		var row: Dictionary = glob_records[id]
		row.last = xy(child.position); row.min_scale = minf(row.min_scale,child.scale.x); row.max_scale = maxf(row.max_scale,child.scale.x); row.samples += 1

func collect_ordnance():
	var active := {"sparks":0, "shells":0, "embers":0}
	for child in game.get_node("World").get_children():
		if not ViewProbe.polygon(child) or not child.visible: continue
		var kind := ""
		if str(child.name).begins_with("WallSpark"): kind = "sparks"
		elif str(child.name).begins_with("Grenade"): kind = "shells"
		elif str(child.name).begins_with("Ember"): kind = "embers"
		else: continue
		active[kind] += 1
		var id: int = child.get_instance_id()
		if kind == "shells":
			if ordnance_seen.has(id):
				var minimum: float = minf(ordnance_seen[id], child.position.x)
				if minimum < 665 and child.position.x > minimum + 8: ordnance.bounced = true
				ordnance_seen[id] = minimum
			else: ordnance_seen[id] = child.position.x
		elif ordnance_seen.has(id): continue
		else: ordnance_seen[id] = true
		if ordnance[kind].size() < 12:
			ordnance[kind].append({"position":xy(child.position), "rotation":child.rotation, "points":ViewProbe.vertices(child).size(), "color":[ViewProbe.tint(child).r,ViewProbe.tint(child).g,ViewProbe.tint(child).b,ViewProbe.tint(child).a]})
	ordnance.active = active
	ordnance.dropped = game.feedback_probe("dropped")
	ordnance.old_epoch = game.feedback_probe("wrong_epoch")


func _ready():
	if not OS.has_feature("web") or not bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('ui_test')", true)):
		set_process(false); return
	game = get_parent()
	print("RSY_WEB_UI_READY")

func p(key: String, seat: int = 1) -> int: return int(game.probe(key, seat))
func xy(value: Vector2) -> Array: return [value.x, value.y]
func box(control: Control) -> Array:
	var rect := control.get_global_rect(); return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _process(_dt: float):
	var raw: String = str(JavaScriptBridge.eval("JSON.stringify(globalThis.uiCommand||null)", true))
	if raw != "null":
		var command: Dictionary = JSON.parse_string(raw)
		if int(command.id) > handled:
			var accepted := true
			match str(command.kind):
				"muster_focus":
					var target := game.get_node("UI/Lobby/Scroll/Layout/" + str(command.path)) as Control
					game.get_node("UI/Lobby/Scroll").ensure_control_visible(target)
				"ready": game.on_ready()
				"start": game.on_start()
				"scrap": accepted = game.dev_grant_scrap(int(command.seat), int(command.amount)) > 0
				"cores": accepted = game.dev_grant_cores(int(command.seat), int(command.amount)) > 0
				"hurt": accepted = game.dev_hurt(int(command.seat), int(command.amount)) > 0
				"jam": accepted = game.dev_jam(int(command.seat)) > 0
				"aim": game.dev_aim(float(command.x), float(command.y), bool(command.fire))
				"path_watch": path_watch = true; path_records = {}; path_active = {"flame":0,"arc":0}
				"status": accepted = game.dev_status(int(command.seat),int(command.status)) > 0
				"barrel": accepted = game.dev_spawn(5,1,float(command.dx),0.0) > 0
				"area_watch": area_watch = true; area_records = {}; area_active = {"area":0,"zone":0,"buff":0}
				"glob_watch": glob_watch = true; glob_records = {}; glob_active = {"lob":0,"spit":0}
				"abilities": game.dev_abilities(int(command.first),int(command.second))
				"cast": accepted = game.dev_cast(int(command.slot),float(command.x),float(command.y),true)
				"spitter": accepted = game.dev_spawn(2,2,210.0,0.0) > 0
				"ordnance":
					ordnance_watch = true; ordnance_seen = {}
					ordnance = {"sparks":[], "shells":[], "embers":[], "bounced":false}
				"hashes": collecting = true; hashed_through = p("head"); JavaScriptBridge.eval("globalThis.uiHashes={};0", true)
				_: accepted = false
			handled = int(command.id)
			JavaScriptBridge.eval("globalThis.uiAck=" + JSON.stringify({"id": handled, "accepted": accepted}) + ";0", true)
	if collecting and p("ready"):
		var hashes := {}; var head := p("head"); var through := mini(head, hashed_through + 8)
		for tick in range(maxi(hashed_through + 1, head - 127), through + 1):
			var value = game.probe_hash(tick)
			if value != -1: hashes[str(tick)] = str(value)
		hashed_through = through
		JavaScriptBridge.eval("Object.assign(globalThis.uiHashes," + JSON.stringify(hashes) + ");Object.keys(globalThis.uiHashes).slice(0,-512).forEach(k=>delete globalThis.uiHashes[k]);0", true)
	if ordnance_watch: collect_ordnance()
	if glob_watch: collect_globs()
	if area_watch: collect_areas()
	if path_watch: collect_paths()
	var query := int(JavaScriptBridge.eval("globalThis.uiQuery||0", true))
	if query <= queried: return
	queried = query
	var hud := game.get_node("UI/CombatHUD")
	var focused := get_viewport().gui_get_focus_owner()
	var state := {"query": query, "ready": p("ready"), "seat": p("seat"), "players": p("players"), "stage": p("stage"), "run": p("run"), "head": p("head"), "epoch": p("epoch"),
		"chat_ready": int(game.chat_probe("ready")), "typing": int(game.chat_probe("typing")), "history": game.get_node("UI/Chat/Lines").text,
		"parsed_history": game.get_node("UI/Chat/Lines").get_parsed_text(), "bbcode": game.get_node("UI/Chat/Lines").bbcode_enabled,
		"pings": int(game.chat_probe("pings")), "active_pings": int(game.chat_probe("active_pings")), "menu": p("menu_open"), "camera": p("camera_seat"),
		"menu_box": box(game.get_node("UI/Menu")), "veil_box": box(game.get_node("UI/MenuVeil")), "veil": game.get_node("UI/MenuVeil").visible,
		"tally": game.get_node("UI/Tally").visible, "tally_box": box(game.get_node("UI/Tally")), "focus": str(focused.get_path()) if focused != null else "",
		"resume_box": box(game.get_node("UI/Menu/Scroll/Column/Resume")), "quit_box": box(game.get_node("UI/Menu/Scroll/Column/Quit")),
		"following": game.get_node("UI/Following").visible, "following_text": game.get_node("UI/Following").text,
		"health": hud.get_node("Vitals/Text").text, "health_width": hud.get_node("Vitals/Fill").size.x,
		"vignette": game.get_node("ScreenFx/Vignette").visible, "vignette_alpha": game.get_node("ScreenFx/Vignette").modulate.a,
		"ammo_state": hud.get_node("Ammo/State").text, "ammo": hud.get_node("Ammo/Count").text,
		"pip0": hud.get_node("Vitals/Pip0/Fill").size.x, "pip1": hud.get_node("Vitals/Pip1/Fill").size.x,
		"viewport": xy(get_viewport().get_visible_rect().size), "chat_box": box(game.get_node("UI/Chat/Input")), "shop_box": box(game.get_node("UI/Shop")),
		"ping_point": xy(game.get_node("World").get_global_transform_with_canvas() * Vector2(1100, 500))}
	state.network = {}
	for key in ["facts", "confirmed", "predhead", "pending_snapshot", "phase", "resyncs", "resync_reason", "fullsnaps", "deltasnaps", "large_snapshots", "watch_catchups", "fragmented_snapshots", "snapshot_every", "snapshot_parts_sent", "snapshot_parts_received", "snapshot_parts_expired", "snapshot_parity_sent", "snapshot_parity_received", "snapshot_shards_recovered", "lz4_snapshots", "shuffled_snapshots", "shuffle_attempts", "shuffle_bytes_saved", "action_copy_batches", "action_copies", "action_copy_bytes", "action_copy_oversize", "reuse_enabled", "reused_correction_ticks"]: state.network[key] = p(key)
	var players: Array = []; var cards: Array = []
	for seat in [1, 2, 3]:
		var row := {}
		for key in ["look", "ability0", "ability1", "marked_ready", "in_yard", "hp", "scrap", "cores", "parts", "boost_damage", "shots", "ammo", "iron", "blasts", "casts", "cd0", "cd1", "dashes", "revive_progress", "fx_mask", "x", "y"]: row[key] = p(key, seat)
		players.append(row)
	for i in range(9):
		var card := game.get_node("UI/Shop/Card" + str(i)) as Button
		cards.append({"box": box(card), "text": card.text, "disabled": card.disabled})
	var muster_rows := []; var muster_buttons := {}
	for index in range(4):
		var row := game.get_node("UI/Lobby/Scroll/Layout/Roster/Row%d" % index)
		var sprite := row.get_node("Body") as Sprite2D
		muster_rows.append({"visible":row.visible,"name":row.get_node("Name").text,"iron":row.get_node("Iron").text,"lamp":row.get_node("Lamp").text,"tint":[row.modulate.r,row.modulate.g,row.modulate.b,row.modulate.a],"frame":sprite.frame,"texture":sprite.texture.resource_path if sprite.texture != null else ""})
	for path in ["Picks/LookPrev","Picks/Look","Picks/IronPrev","Picks/Iron","Abilities/LeftPrev","Abilities/Left","Abilities/RightPrev","Abilities/Right","Actions/Ready","Actions/Start"]:
		var target := game.get_node("UI/Lobby/Scroll/Layout/" + path) as Button
		muster_buttons[path] = {"visible":target.is_visible_in_tree(),"disabled":target.disabled,"text":target.text,"box":box(target)}
	state.muster = {"automatic":p("automatic"),"saved_automatic":p("saved_automatic"),"profile_loaded":p("profile_loaded"),"profile_writing":p("profile_writing"),"profile_error":p("profile_error"),"picked":game.get_node("UI/Lobby/Scroll/Layout/Picked").text,"box":box(game.get_node("UI/Lobby")),"visible":game.get_node("UI/Lobby").visible,"rows":muster_rows,"buttons":muster_buttons}
	var chat_diagnostics := {}
	for key in ["lines","pending","rejected","sequence","history_serial","display_revision","scope_drops","duplicates","result","outbox"]: chat_diagnostics[key] = game.chat_probe(key)
	chat_diagnostics.draft = game.get_node("UI/Chat/Input").text
	chat_diagnostics.notice = game.get_node("UI/Chat/Notice").text
	chat_diagnostics.resyncs = p("resyncs")
	chat_diagnostics.resync_reason = p("resync_reason")
	state.chat_diagnostics = chat_diagnostics
	var tally_rows := []
	for row in range(4):
		var values := []
		for column in range(8): values.append(game.get_node("UI/Tally/Column/Grid/Row%d_%d" % [row,column]).text)
		tally_rows.append({"visible":game.get_node("UI/Tally/Column/Grid/Row%d_0" % row).visible, "values":values})
	state.mesh_probe={"reads":ViewProbe.reads,"read_us":ViewProbe.read_us,"hits":ViewProbe.hits}
	state.paths = {"records":path_records.values(),"active":path_active}
	state.areas = {"records":area_records.values(),"active":area_active}
	state.globs = {"records":glob_records.values(),"active":glob_active}
	state.players_state = players; state.cards = cards; state.ordnance = ordnance; state.tally_rows = tally_rows
	JavaScriptBridge.eval("globalThis.uiState=" + JSON.stringify(state) + ";0", true)
