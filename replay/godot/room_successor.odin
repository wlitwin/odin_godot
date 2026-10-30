package replay_godot

import auth "godot:replay/authority"
import net "godot:replay/net"

@(private)
room_successor_eligible :: proc(room:^Room($S,$C,$A,$E,$N),member:auth.Member,connection:net.Connection)->bool {
 return member.identity!=room.options.identity && member.enabled && member.can_host && member.trusted_authority &&
  (room.lease.view.policy.mode!=.Dedicated || member.infrastructure) &&
  (!connection.spectator || member.infrastructure) && member.game_token_hash==connection.token_hash && member.identity.incarnation==connection.incarnation
}

// Player seats keep their existing ordering. An avatarless infrastructure
// standby is selected by authenticated member identity and admitted connection.
@(private)
room_select_successor :: proc(room:^Room($S,$C,$A,$E,$N)) {
 room.options.successor,room.options.successor_seat={},0
 for seat in 1..=N {
  connection,live:=net.server_seat_connection(&room.session.server,u16(seat));if !live {continue}
  for member in room.members {if room_successor_eligible(room,member,connection) {
   room.options.successor,room.options.successor_seat=member.identity,u16(seat);return
  }}
 }
 connections:[net.MAX_PEERS]net.Connection
 count:=net.server_connections(&room.session.server,connections[:])
 for member in room.members {if member.infrastructure {
  for connection in connections[:count] {if connection.spectator && room_successor_eligible(room,member,connection) {
   room.options.successor=member.identity;return
  }}
 }}
}

@(private)
room_successor_connection :: proc(room:^Room($S,$C,$A,$E,$N))->(net.Connection,bool) {
 if room.options.successor.member==0 {return {},false}
 connections:[net.MAX_PEERS]net.Connection
 count:=net.server_connections(&room.session.server,connections[:])
 for member in room.members {if member.identity.member==room.options.successor.member {
  for connection in connections[:count] {if (room.options.successor_seat==0 || connection.seat==room.options.successor_seat) && room_successor_eligible(room,member,connection) {return connection,true}}
 }}
 return {},false
}
