extends SceneTree
func _initialize():
	assert(Engine.has_singleton("Steam"))
	assert(ClassDB.can_instantiate("SteamMultiplayerPeer"))
	var methods:={}
	for method in ClassDB.class_get_method_list("SteamMultiplayerPeer",true):methods[method.name]=method
	for name in ["create_host","create_client","get_steam_id_for_peer_id"]:assert(methods.has(name))
	assert(methods.create_host.args.size()==1 and methods.create_client.args.size()==2)
	assert(methods.get_steam_id_for_peer_id.args.size()==1)
	print("REPLAY_STEAM_NATIVE_CAPABILITY_OK singleton=true peer=true methods=3 initialization=false")
	quit(0)
