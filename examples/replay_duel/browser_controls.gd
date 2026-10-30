extends HBoxContainer
var capture := false
var provisioned := false
func _ready() -> void:
	visible = OS.has_feature("web")
	if visible:
		provisioned = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('party') || ''", true)) != ""
		var role := str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('role') || 'listen'", true))
		visible = role != "watch"
		$Join.visible = role == "listen"
		$Watch.visible = role == "listen" and str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('auth') || '0'", true)) != "1"
		if provisioned:
			$Watch.visible = false
			$Join.text = "Invite player"
		capture = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('probe') === '1'", true))
	else:
		provisioned = OS.get_environment("RDP_PARTY") != ""
		visible = provisioned
		$Join.visible = false
		$Join.text = "Copy invitation"
		$Watch.visible = false
	$Join.pressed.connect(func(): copy_link(false))
	$Watch.pressed.connect(func(): copy_link(true))
	$Save.pressed.connect(func():
		if get_parent().call("save_participant"):
			$Save.disabled = true
			$Note.text = "Preparing participant file…"
	)
func copy_link(watch: bool) -> void:
	if provisioned:
		var invite: String = get_parent().call("party_invite")
		if invite.is_empty():
			$Note.text = "Invitation is not ready yet."
			return
		if not OS.has_feature("web"):
			DisplayServer.clipboard_set(invite)
			$Note.text = "Invitation copied"
			return
		var current_url: String = str(JavaScriptBridge.eval("location.href", true))
		var service: String = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('service') || ''", true))
		var local: String = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('local') || '0'", true))
		var invitation_url := current_url.split("?")[0].get_base_dir() + "/lobby.html?service=" + service.uri_encode() + "&invite=" + invite.uri_encode() + "&local=" + local
		JavaScriptBridge.eval("replayDuelShowInvite(" + JSON.stringify(invitation_url) + "); 0", true)
		$Note.text = "Share the match invitation"
		return
	var code: String = get_parent().call("room_code", watch)
	if code.is_empty():
		$Note.text = "Room is opening…"
		return
	var current: String = str(JavaScriptBridge.eval("location.href", true))
	var relay: String = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('url') || 'ws://127.0.0.1:9080/rtc'", true))
	var url := current.split("?")[0].get_base_dir() + "/lobby.html?role=" + ("watch" if watch else "dial") + "&room=" + code.uri_encode() + "&url=" + relay.uri_encode()
	if not watch and str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('stage') || ''", true)) == "resume": url += "&resume=1"
	if not watch: url += "&live_rejoin=1"
	if str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('auth') || '0'", true)) == "1": url += "&auth=1"
	DisplayServer.clipboard_set(url)
	$Note.text = "Watch link copied" if watch else "Join link copied"

func _process(_delta: float) -> void:
	if provisioned:
		$Join.visible = not str(get_parent().call("party_invite")).is_empty()
	if visible and get_parent().call("probe", 5) == 1:
		$Note.text = "Keep the downloaded file before closing." if OS.has_feature("web") else "Participant file saved. Rejoin with the same profile."
	if capture:
		var game := get_parent()
		var state := {"tick": game.call("probe", 0), "x": game.call("probe", 1), "y": game.call("probe", 2), "shots": game.call("probe", 3), "sampled": game.call("probe", 4), "saved": game.call("probe", 5), "confirmed": game.call("probe", 6)}
		JavaScriptBridge.eval("globalThis.replayDuelState = " + JSON.stringify(state) + "; 0", true)
