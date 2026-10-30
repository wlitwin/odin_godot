package replay_authority

import tr "godot:replay/transport"

// Trusted integration entry point. The caller authenticates the exact request
// and must guard the real commit against replacement of the durable publication.
// Registration only replaces the process; this separate decision grants a NEW
// epoch for an exact saved Point after expiry/quarantine and rollback checks.
service_recover_published :: proc(s:^Service,from:tr.Peer_Id,actor:Identity,nonce:Nonce,sequence:u64,digest:[32]u8,epoch:u64,point:Point)->(Error,bool) {
	if !s.ready || !s.allow_expired_owner_rebind || sequence==0 || nonce==(Nonce{}) || digest==([32]u8{}) {return .Invalid,false}
	now,ok:=s.clock.read(s.clock.user);if !ok {s.coordinator.poisoned,s.coordinator.active=true,false;return .Clock,false}
	if error:=coordinator_time(&s.coordinator,now);error!=.None {return error,false}
	index:=-1
	for m,i in s.coordinator.record.members {if m.identity==actor && m.enabled {index=i;break}}
	if index<0 || s.active_peer[index]!=from || s.active_generation[index]!=tr.peer_generation(&s.wire,from) || !tr.peer_connected(&s.wire,from) {return .Denied,false}
	frontier:=s.coordinator.record.requests[index]
	if frontier.nonce!=nonce {return .Denied,false}
	if sequence<frontier.sequence || (sequence==frontier.sequence && digest!=frontier.hash) {return .Stale,false}
	if sequence==frontier.sequence {return frontier.result,true}
	candidate:=s.coordinator;candidate.commit,candidate.user=service_stage,nil
	result:=coordinator_recover_published(&candidate,actor,epoch,sequence,point,now)
	if result==.Clock {s.coordinator.poisoned,s.coordinator.active=true,false;return .Clock,false}
	if s.coordinator.record.revision==max(u64) {return .Capacity,false}
	if result!=.None {candidate=s.coordinator;candidate.record.revision+=1}
	candidate.record.requests[index]={sequence,digest,result,nonce}
	if !record_valid(candidate.record) || !s.coordinator.commit(s.coordinator.user,s.coordinator.record.revision,candidate.record) {
		s.coordinator.poisoned,s.coordinator.active=true,false;return .Storage,false
	}
	candidate.commit,candidate.user=s.coordinator.commit,s.coordinator.user;s.coordinator=candidate
	s.active_at[index]=now;s.stats.commits+=1
	return result,false
}

// This primitive does not locate or authenticate storage. Only a guarded trusted
// backend may commit it. Existing live-migration claim/release rules stay separate.
coordinator_recover_published :: proc(c:^Coordinator,actor:Identity,epoch,request:u64,point:Point,now:u64)->Error {
	if error:=coordinator_time(c,now);error!=.None {return error}
	if epoch==0 || epoch!=c.record.epoch || request==0 {return .Stale}
	if now<c.quarantine_until || (c.active && now<c.expires) {return .Busy}
	member,allowed:=host_member(c,actor);if !allowed {return .Denied}
	prior_grant:=c.record.recovery!=.None && point==c.record.recovered
	if !point_valid(point) || point.scope.room!=c.record.room || point.scope.content!=c.record.content || (point.scope.epoch!=epoch && !prior_grant) {return .Invalid}
	if c.record.released && point!=c.record.point {return .No_Checkpoint}
	if c.record.last_tick>point.archive.tick && c.record.last_tick-point.archive.tick>c.record.policy.max_known_rollback {return .Too_Old}
	return coordinator_grant(c,member,request,c.restarted ? .Coordinator_Restart : .Abrupt,point,now)
}
