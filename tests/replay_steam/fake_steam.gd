extends Node
var polls:=0
var behavior:=0
func steamInitEx(app_id:int,embed_callbacks:bool)->Dictionary:
	assert(app_id==480 and not embed_callbacks)
	return {"status":"bad"} if behavior==1 else {"status":1 if behavior==3 else 0}
func getSteamID()->int:return 0 if behavior==2 else 76561198000000001
func run_callbacks():polls+=1
func new_peer()->MultiplayerPeer:return load("res://fake_peer.gd").new()
