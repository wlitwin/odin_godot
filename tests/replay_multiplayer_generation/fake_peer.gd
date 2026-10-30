extends MultiplayerPeerExtension
var packets:Array[Dictionary]=[]
var status:=MultiplayerPeer.CONNECTION_CONNECTED
var denied:Array[int]=[]
func join(id:int):peer_connected.emit(id)
func leave(id:int):peer_disconnected.emit(id)
func enqueue(id:int,value:int):packets.append({"id":id,"bytes":PackedByteArray([value,2,3])})
func _get_packet_script()->PackedByteArray:return packets.pop_front().bytes
func _put_packet_script(_bytes:PackedByteArray)->Error:return OK
func _get_available_packet_count()->int:return packets.size()
func _get_max_packet_size()->int:return 65536
func _get_packet_peer()->int:return packets[0].id
func _get_packet_mode()->MultiplayerPeer.TransferMode:return MultiplayerPeer.TRANSFER_MODE_RELIABLE
func _get_packet_channel()->int:return 0
func _set_target_peer(_id:int):pass
func _set_transfer_channel(_channel:int):pass
func _get_transfer_channel()->int:return 0
func _set_transfer_mode(_mode:MultiplayerPeer.TransferMode):pass
func _get_transfer_mode()->MultiplayerPeer.TransferMode:return MultiplayerPeer.TRANSFER_MODE_RELIABLE
func _get_connection_status()->MultiplayerPeer.ConnectionStatus:return status
func _is_server()->bool:return true
func _get_unique_id()->int:return 1
func _is_server_relay_supported()->bool:return false
func _is_refusing_new_connections()->bool:return false
func _set_refuse_new_connections(_value:bool):pass
func _disconnect_peer(id:int,_force:bool):denied.append(id)
func _poll():pass
func _close():status=MultiplayerPeer.CONNECTION_DISCONNECTED;packets.clear()
