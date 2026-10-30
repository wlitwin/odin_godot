package replay_godot

import "core:fmt"
import auth "godot:replay/authority"
import net "godot:replay/net"

Room_Backup_Phase :: enum u8 {Unavailable,Connecting,Waiting_Peer,Transferring,Ready,Stale,Checking,Recovering}
// Last accepted control observation. RPC begins clear their transient reply;
// presentation must not discard an authenticated observation on every request.
Room_Backup_Observation :: struct {
 view:auth.View,
 nominee:auth.Identity,
 binding:u64,
 point:auth.Point,
 observed_at:u64,
 prepared,ready:bool,
}
Room_Backup_Status :: struct {
 phase:Room_Backup_Phase,
 nominee:auth.Identity,
 point:auth.Point,
 epoch,revision,observed_at,known_tick,age_ticks,rollback_limit:u64,
 locally_retained:bool,
}
room_backup_status :: proc {room_backup_status_current,room_backup_status_at}
room_backup_status_current :: proc(room:^Room($S,$C,$A,$E,$N))->Room_Backup_Status {
 if !room.ready || room.phase==.Failed {return {phase=.Unavailable}}
 if room.clock.read==nil {return {phase=.Checking}}
 now,valid:=room.clock.read(room.clock.user)
 if !valid {return {phase=.Checking}}
 return room_backup_status_at(room,now)
}
// Read-only observation, not a permit or a promise of future availability. now
// must use Room's clock domain. It never renews, retires or mutates the Lease.
room_backup_status_at :: proc(room:^Room($S,$C,$A,$E,$N),now:u64)->Room_Backup_Status {
 result:=Room_Backup_Status{phase=.Unavailable}
 if !room.ready || room.phase==.Failed || room.restore.phase==.Failed {return result}
 if room.session.fenced || room.handoff_requested || room.phase==.Freezing || room.phase==.Releasing || room.phase==.Claiming || room.phase==.Recovering {result.phase=.Recovering;return result}
 if !room.registered || !room.session.ready || room.phase==.Connecting || (!room.session.authority && room.session.client.phase!=.Running) {result.phase=.Connecting;return result}
 o:=room.backup_observation;l:=&room.lease
 result.phase=.Checking
 epoch:=room.session.authority ? room.session.server.cfg.epoch : room.session.client.cfg.epoch
 if !o.ready || !l.ready || l.poisoned || now<l.now || now<o.observed_at || now>=l.deadline || epoch==0 || epoch<=l.retired_through ||
    l.identity!=room.options.identity || l.view.epoch!=epoch || o.view!=l.view ||
    o.view.room!=room.options.room || o.view.content!=room.options.session.network.content || o.view.owner!=l.view.owner ||
    (room.session.authority && l.view.owner!=room.options.identity) {return result}
 result.epoch,result.revision,result.observed_at=epoch,o.view.revision,o.observed_at
 result.nominee,result.point,result.rollback_limit=o.nominee,o.point,o.view.policy.max_known_rollback
 result.known_tick=max(o.view.last_known_tick,room.session.authority ? room.session.server.timeline.head : room.session.client.authority_frame.tick)
 result.phase=.Waiting_Peer
 if !auth.identity_valid(o.nominee) || o.nominee==o.view.owner || o.binding==0 {return result}
 trusted:=false
 for member in room.members {if member.identity==o.nominee && member.enabled && member.can_host && member.trusted_authority && (o.view.policy.mode!=.Dedicated || member.infrastructure) {trusted=true;break}}
 if !trusted {return result}
 if room.session.authority {
  connection,live:=room_successor_connection(room)
  if !live || room.options.successor!=o.nominee || connection.incarnation!=o.nominee.incarnation || connection.generation!=o.binding {return result}
  matched:=false
  for member in room.members {if member.identity==o.nominee && member.game_token_hash==connection.token_hash {matched=true;break}}
  if !matched {return result}
 }
 result.phase=.Transferring
 if !o.prepared {return result}
 if !auth.point_valid(o.point) || o.point.scope.room!=o.view.room || o.point.scope.content!=o.view.content || o.point.scope.epoch!=epoch || o.point.scope.binding!=o.binding {result.phase=.Checking;return result}
 result.locally_retained=room.prepared.ready && room.prepared.point==o.point
 if o.nominee==room.options.identity && !result.locally_retained {return result}
 result.age_ticks=result.known_tick>o.point.archive.tick ? result.known_tick-o.point.archive.tick : 0
 result.phase=result.age_ticks>result.rollback_limit ? .Stale : .Ready
 return result
}
room_backup_message :: proc(status:Room_Backup_Status)->string {
 switch status.phase {
 case .Unavailable:return "Host recovery unavailable"
 case .Connecting:return "Connecting to the party…"
 case .Waiting_Peer:return "Waiting for a backup host…"
 case .Transferring:return "Preparing host recovery…"
 case .Ready:return "Recovery backup confirmed"
 case .Stale:return "Recovery backup is out of date"
 case .Checking:return "Checking host recovery…"
 case .Recovering:return "Recovering the session…"
 }
 return "Host recovery unavailable"
}
// Preserve restoration disclosure without using it as evidence of a fresh backup.
room_recovery_message :: proc(room:^Room($S,$C,$A,$E,$N),status:Room_Backup_Status)->string {
 if !room.recovery.ready || status.phase==.Recovering || status.phase==.Connecting || status.phase==.Unavailable {return room_backup_message(status)}
 if room.recovery.from_publication {
  prefix:=room.recovery.known_lost_ticks>0 ? "Party restored; recent progress lost" : "Saved party restored"
  return fmt.tprintf("%s · %s",prefix,status.phase==.Ready ? "backup ready" : status.phase==.Stale ? "backup out of date" : status.phase==.Checking ? "checking backup" : "backup pending")
 }
 return fmt.tprintf("Host changed · %s",status.phase==.Ready ? "backup ready" : status.phase==.Stale ? "backup out of date" : status.phase==.Checking ? "checking backup" : "backup pending")
}
