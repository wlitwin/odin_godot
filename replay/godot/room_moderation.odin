package replay_godot

import auth "godot:replay/authority"
import net "godot:replay/net"
import rec "godot:replay/recovery"

Removal_Phase :: enum {Idle,Queued,Waiting,Removed,Failed}
Room_Removal :: struct {phase:Removal_Phase,target:auth.Identity,seat:u16,epoch,sequence:u64,error:auth.Error,attempts:u8,refresh:bool,rpc_timeout:u64}

// A successful call queues work; Removed means coordinator-durable exclusion.
// Target the authenticated identity behind the seat, never a mutable display name.
room_remove :: proc(room:^Room($S,$C,$A,$E,$N),seat:u16)->net.Error {
 if !room.ready || room.phase!=.Hosting || !room.session.authority || room.handoff_requested || room.removed {return .Wrong_Phase}
 if room.removal.phase==.Queued || room.removal.phase==.Waiting {return .Capacity}
 if !auth.lease_live(&room.lease,room.session.server.cfg.epoch) {return .Fenced}
 connection,live:=net.server_seat_connection(&room.session.server,seat);if !live {return .Invalid_Input}
 for member in room.members {if member.enabled && member.game_token_hash==connection.token_hash && member.identity.incarnation==connection.incarnation {
  if member.identity.member==room.options.identity.member {return .Wrong_Phase}
  room.removal={phase=.Queued,target=member.identity,seat=seat,epoch=room.lease.view.epoch}
  return .None
 }}
 return .Invalid_Input
}

@(private)
room_removal_observe :: proc(room:^Room($S,$C,$A,$E,$N)) {
 if room.removal.phase==.Waiting {
  if reply,done:=auth.rpc_completed(&room.rpc);done && reply.sequence==room.removal.sequence && room.rpc.request_kind==auth.RPC_REMOVE_REQUEST {
   room.rpc.timeout_ms=room.removal.rpc_timeout
   room.removal.error=reply.result
   room.removal.phase=reply.result==.None ? .Removed : .Failed
  } else if !room.rpc.pending {
   // A timeout can follow a committed but lost reply. The next ordinary Query
   // resolves it from the durable roster instead of reporting success early.
   room.rpc.timeout_ms=room.removal.rpc_timeout
   room.removal.phase=room.removal.attempts>=2 ? .Failed : .Queued;room.removal.error=.Busy;room.removal.refresh=true
  }
 }
 if room.removal.refresh && !room.rpc.pending && room.rpc.request_kind==auth.RPC_REQUEST && room.last_roster>room.removal.sequence {room.removal.refresh=false}
 for member in room.members {if member.identity.member==room.removal.target.member && !member.enabled && room.removal.target.member!=0 {
  room.removal.phase,room.removal.error=.Removed,.None
 }}
 if (room.removal.phase==.Queued || room.removal.phase==.Waiting) &&
    (room.lease.view.epoch!=room.removal.epoch || room.lease.view.owner!=room.options.identity) {
  room.removal.phase,room.removal.error=.Failed,.Stale
 }
}

@(private)
room_moderation_roster :: proc(room:^Room($S,$C,$A,$E,$N)) {
 if room.last_roster==0 {return}
 for member in room.members {if member.identity.member==room.options.identity.member && !member.enabled {
  room.removed=true;room.lease.deadline=0
  room.phase,room.error=.Failed,.Fenced
  room.session.fenced=true
  if room.session.ready && !room.session.authority {room.session.client.phase=.Rejected;room.session.client.rejection=.Banned}
  return
 }}
 if !room.session.ready || !room.session.authority {return}
 // A restored old checkpoint must not undo coordinator-durable removal.
 for member in room.members {if member.identity.member!=0 && !member.enabled && member.game_token_hash!=([32]u8{}) {
  net.server_ban_identity(&room.session.server,member.game_token_hash)
  if room.options.successor.member==member.identity.member {room.options.successor={};room.options.successor_seat=0}
 }}
 if session_link(&room.session)^.outgoing.ready {
  _,live:=net.server_connection(&room.session.server,session_link(&room.session)^.outgoing.target)
  if !live {rec.link_untarget(session_link(&room.session))}
 }
}
