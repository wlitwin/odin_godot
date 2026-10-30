# API-contract fixture only: transport is real ENet, not Valve's network.
extends MultiplayerPeerExtension
var inner:=ENetMultiplayerPeer.new()
var hosting:=false
var fail_creation:=false
var virtual_port:=-1
func _init():
	inner.peer_connected.connect(_forward_connected)
	inner.peer_disconnected.connect(_forward_disconnected)
func _forward_connected(id:int):peer_connected.emit(id)
func _forward_disconnected(id:int):peer_disconnected.emit(id)
func create_host(port:int)->Error:
	if fail_creation:return ERR_CANT_CREATE
	hosting=true;virtual_port=port
	return inner.create_server(port,16)
func create_client(steam_id:int,port:int)->Error:
	assert(steam_id==76561198000000001)
	virtual_port=port
	return inner.create_client("127.0.0.1",port)
func get_steam_id_for_peer_id(id:int)->int:return 76561198000000001 if id==1 else 76561198000000002
func _get_packet_script()->PackedByteArray:return inner.get_packet()
func _put_packet_script(bytes:PackedByteArray)->Error:return inner.put_packet(bytes)
func _get_available_packet_count()->int:return inner.get_available_packet_count()
func _get_max_packet_size()->int:return 65536
func _get_packet_peer()->int:return inner.get_packet_peer()
func _get_packet_mode()->MultiplayerPeer.TransferMode:return inner.get_packet_mode()
func _get_packet_channel()->int:return inner.get_packet_channel()
func _set_target_peer(id:int):inner.set_target_peer(id)
func _set_transfer_channel(channel:int):inner.transfer_channel=channel
func _get_transfer_channel()->int:return inner.transfer_channel
func _set_transfer_mode(mode:MultiplayerPeer.TransferMode):inner.transfer_mode=mode
func _get_transfer_mode()->MultiplayerPeer.TransferMode:return inner.transfer_mode
func _get_connection_status()->MultiplayerPeer.ConnectionStatus:return inner.get_connection_status()
func _is_server()->bool:return hosting
func _get_unique_id()->int:return inner.get_unique_id()
func _is_server_relay_supported()->bool:return false
func _is_refusing_new_connections()->bool:return inner.refuse_new_connections
func _set_refuse_new_connections(value:bool):inner.refuse_new_connections=value
func _disconnect_peer(id:int,force:bool):inner.disconnect_peer(id,force)
func _poll():inner.poll()
func _close():
	if inner.peer_connected.is_connected(_forward_connected):inner.peer_connected.disconnect(_forward_connected)
	if inner.peer_disconnected.is_connected(_forward_disconnected):inner.peer_disconnected.disconnect(_forward_disconnected)
	inner.close()
