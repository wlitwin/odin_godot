package replay_godot

import gd "godot:godot"
import auth "godot:replay/authority"
import ck "godot:replay/provision/checkpoint"
import net "godot:replay/net"

Room_Restore_Phase :: enum u8 {Idle, Checking, Downloading, Preparing, Requesting, Granted, Complete, Failed}
Room_Restore :: struct {
	phase:Room_Restore_Phase,
	error:ck.Error,
	authority_error:auth.Error,
	client:ck.Client,
	prepared:auth.Prepared,
	publication:ck.Publication,
	serial,contract,started,retry_at,from_epoch,last_known_tick:u64,
	grant_epoch,refresh_after,renewed_epoch:u64,
	local_seat:u16,
}
@(private)
room_restore_destroy :: proc(s:^Room_Restore) {ck.client_close(&s.client);auth.prepared_destroy(&s.prepared);s^={}}
@(private)
room_restore_interrupt :: proc(s:^Room_Restore) {
	ck.client_close(&s.client)
	s.grant_epoch,s.renewed_epoch=0,0
	if s.phase!=.Complete && s.phase!=.Failed {s.phase=.Idle}
}
room_restore_retry :: proc(room:^Room($S,$C,$A,$E,$N))->bool {
	if !room.ready || room.session.ready || !room.options.restore_published || room.restore.phase!=.Failed {return false}
	room.restore.phase,room.restore.error,room.restore.authority_error,room.restore.retry_at=.Idle,.None,.None,0
	return true
}
@(private)
room_restore_fail :: proc(s:^Room_Restore,error:ck.Error,authority_error:auth.Error=.None) {
	s.phase,s.error,s.authority_error=.Failed,error,authority_error;ck.client_close(&s.client)
}
room_restore_frame :: proc(room:^Room($S,$C,$A,$E,$N),now:u64) {
	s:=&room.restore
	if !room.options.restore_published || room.session.ready || !room.registered || room.control_paused {return}
	view:=room.lease.view
	if view.epoch==0 {return}
	if view.remaining_ms!=0 && view.owner!=room.lease.identity {
		room_restore_destroy(s);return // a live host always takes precedence
	}
	if view.owner==room.lease.identity && view.remaining_ms!=0 && s.prepared.ready && view.recovered==s.prepared.point {
		if s.grant_epoch!=view.epoch {s.grant_epoch,s.refresh_after,s.renewed_epoch=view.epoch,room.lease.sequence,0}
		// Restore validates a large world on both ends. Its request-start lease
		// may already be locally expired when the grant arrives. Keep the exact
		// prepared point and ask for a cheap renewal instead of another Restore.
		// Installation still requires a successful renewal AND a live permit.
		if reply,complete:=auth.rpc_completed(&room.rpc);complete && reply.result==.None && room.rpc.request.sequence>s.refresh_after &&
		   room.rpc.request.command.verb==.Renew && room.rpc.request.command.epoch==view.epoch && reply.view.epoch==view.epoch && reply.view.owner==room.lease.identity {s.renewed_epoch=view.epoch}
		s.phase=.Granted;room.lease.require_owner=true;return
	}
	if s.phase==.Failed || s.phase==.Complete || now<s.retry_at {return}
	if s.client.ready && (s.client.lane.request.identity!=room.lease.identity || s.client.lane.request.nonce!=room.rpc.nonce || s.client.lane.request.generation!=view.coordinator_generation) {room_restore_interrupt(s)}
	if s.phase==.Granted {s.phase=.Preparing} // a delayed grant may already be expired
	if s.phase==.Idle {
		if room.rpc.pending || room.lease.pending || view.remaining_ms!=0 {return}
		if !room.checkpoint_codec.ready && net.checkpoint_codec_init(&room.checkpoint_codec,S,C,A,E,N,allocator=room.allocator)!=.None {room_restore_fail(s,.Schema);return}
		if s.contract==0 {
			cfg:=room.options.session.network;cfg.require_permit=true
			contract,error:=net.model_contract(room.model,cfg,room.allocator)
			if error!=.None {room_restore_fail(s,.Schema);return};s.contract=contract
		}
		if s.serial==max(u64) {room_restore_fail(s,.Capacity);return}
		if !ck.client_open(&s.client,room.rpc.key,room.clock,room.control_wire,allocator=room.allocator) {room_restore_fail(s,.Invalid);return}
		s.serial+=1
		q:=ck.Request{version=ck.VERSION,verb=.Status,room=room.options.room,content=room.options.session.network.content,
			sequence=s.serial,generation=view.coordinator_generation,identity=room.lease.identity,nonce=room.rpc.nonce,contract=s.contract}
		if e:=ck.client_begin(&s.client,q);e!=.None {room_restore_fail(s,e);return}
		s.phase=.Checking;if s.started==0 {s.started=now}
		s.from_epoch,s.last_known_tick=view.epoch,view.last_known_tick
	}
	if s.phase==.Preparing {
		// Finish the download ACK even while assets are being prepared. Retained
		// bytes are owned locally; another eligible reader need not wait for us.
		if s.client.phase==.Complete && s.client.receiver.ready {ck.client_update(&s.client)}
		if room.options.preparation_ready!=nil && !room.options.preparation_ready(room.options.preparation_user,s.prepared.point,s.prepared.bytes) {return}
		if room.rpc.pending || room.lease.pending {return}
		s.from_epoch,s.last_known_tick=view.epoch,view.last_known_tick
		if e:=ck.client_restore(&s.client,&room.lease,s.publication,&s.prepared);e!=.None {room_restore_fail(s,e);return}
		s.phase=.Requesting
	}
	if s.phase==.Granted {return}
	error:=ck.client_update(&s.client)
	if error!=.None || s.client.phase==.Failed {
		authority_error:=s.client.reply.recovery_result
		if s.phase==.Requesting && s.client.error==.Busy {s.phase,s.retry_at=.Preparing,now+250;return}
		if s.client.error==.Busy || s.client.error==.Stale || s.client.error==.Timeout {room_restore_interrupt(s);s.retry_at=now+250;return}
		room_restore_fail(s,s.client.error,authority_error);return
	}
	if s.client.phase!=.Complete {return}
	switch s.phase {
	case .Checking:
		s.publication=s.client.reply.publication
		if s.prepared.ready && s.prepared.point==s.publication.point {s.phase=.Preparing;return}
		auth.prepared_destroy(&s.prepared)
		if s.serial==max(u64) {room_restore_fail(s,.Capacity);return};s.serial+=1
		q:=s.client.lane.request;q.verb,q.sequence,q.revision=.Download,s.serial,s.publication.revision
		if e:=ck.client_begin(&s.client,q);e!=.None {room_restore_fail(s,e);return};s.phase=.Downloading
	case .Downloading:
		cp:net.Checkpoint(S,C,A,N);defer net.checkpoint_destroy(&cp)
		if ck.client_decode(&s.client,&cp,room.model,room.allocator,codec=&room.checkpoint_codec)!=.None {room_restore_fail(s,.Schema);return}
		if e:=ck.package_install(s.client.saved.payload,s.client.saved.bytes,s.publication.point,room.options.checkpoint_cache,room.options.checkpoint_assets,codec=&room.checkpoint_codec);e!=.None {room_restore_fail(s,e);return}
		if room.options.session.role==.Server {s.local_seat=0} else {
			seat,found:=net.checkpoint_seat(&cp,room.options.session.token)
			if !found {room_restore_fail(s,.Denied);return};s.local_seat=seat
		}
		if e:=ck.client_prepare(&s.client,&s.prepared,room.model,room.allocator,codec=&room.checkpoint_codec);e!=.None {room_restore_fail(s,e);return}
		s.phase=.Preparing
	case .Requesting:s.phase=.Granted
	case .Idle,.Preparing,.Granted,.Complete,.Failed:
	}
}
@(private)
room_restore_install :: proc(room:^Room($S,$C,$A,$E,$N),options:Session_Options,now:u64)->net.Error {
	s:=&room.restore
	cp:net.Checkpoint(S,C,A,N);defer net.checkpoint_destroy(&cp)
	if e:=auth.prepared_decode(&s.prepared,&cp,room.model,&room.lease,room.allocator,codec=&room.checkpoint_codec);e!=.None {return e}
	opts:=options
	opts.network=net.checkpoint_config(cp.header,cp.settings);opts.network.epoch=room.lease.view.epoch
	if room.options.session.role==.Server {opts.role=.Server}
	start:=gd.time_get_ticks_usec(gd.singleton_time())
	if e:=session_resume(&room.session,&cp,room.model,opts,{epoch=room.lease.view.epoch,local_seat=s.local_seat,permit=opts.permit});e!=.None {return e}
	room.interruption_start=s.started
	room_recovered(room,s.from_epoch,0,room.lease.view,now)
	room.recovery.from_publication,room.recovery.service_known_tick=true,s.last_known_tick
	room.recovery.known_lost_ticks=s.last_known_tick>cp.frame.tick ? s.last_known_tick-cp.frame.tick : 0
	room.recovery.install_us=gd.time_get_ticks_usec(gd.singleton_time())-start
	room.session.recovery={from_epoch=cp.header.epoch,to_epoch=room.lease.view.epoch,recovered_tick=cp.frame.tick,new_seat=s.local_seat}
	room.session.recovery_serial+=1
	s.phase,s.error,s.authority_error=.Complete,.None,.None
	ck.client_close(&s.client);auth.prepared_destroy(&s.prepared)
	return .None
}

room_restore_message :: proc(s:^Room_Restore)->string {
	switch s.phase {
	case .Checking,.Downloading:return "Loading saved party progress…"
	case .Preparing:return "Preparing the saved party…"
	case .Requesting,.Granted:return "Resuming the party…"
	case .Failed:
		if s.authority_error==.Too_Old {return "The saved party is older than this room's recovery limit."}
		if s.error==.Missing {return "This party has no stored progress to resume."}
		if s.error==.Denied {return "This player cannot host the saved party."}
		return "Saved party progress could not be restored. Retry or leave the party."
	case .Idle,.Complete:return ""
	}
	return ""
}
