# API-contract fixture: ENet supplies local packets; this is not Valve networking.
extends Node
var polls:=0
var creates:=0
var member:=int(OS.get_environment("REPLAY_CAVE_MEMBER"))
func steamInitEx(app_id:int,embed_callbacks:bool)->Dictionary:
 assert(app_id==480 and not embed_callbacks)
 return {"status":0}
func getSteamID()->int:return 76561198000000000+member
func run_callbacks():polls+=1
func new_peer()->MultiplayerPeer:
 creates+=1
 print("STEAM_ROOM_FACTORY member=",member," count=",creates)
 return load("res://fake_peer.gd").new()
