package replay_comms

import tr "godot:replay/transport"
import sc "godot:replay/schema"
import lb "godot:replay/lobby"

// Bind only authenticated connection metadata. Epoch/connection changes discard
// pending requests; history remains local across an epoch change in the same room.
configure :: proc(c:^Comms,wire:tr.Transport,scope:Scope,authority:bool,local:Binding,connections:[]Binding,enabled:bool,now:u64)->bool {
	if !c.ready || !lb.name_valid(local.name) || scope.room==0 || scope.epoch==0 || scope.content==0 || len(connections)>MAX_PEERS || (c.time_set && now<c.now) {return false}
	if !authority && len(connections)>1 {return false}
	if c.bound && c.scope.room==scope.room && c.scope.content==scope.content && scope.epoch<c.scope.epoch {return false}
	for connection,i in connections {
		if connection.peer==0 || connection.generation==0 || !lb.name_valid(connection.name) {return false}
		for other in connections[:i] {if other.peer==connection.peer {return false}}
	}
	changed:=!c.bound || c.scope!=scope || c.authority!=authority || c.wire.user!=wire.user || !same_binding(c.local,local) || (c.enabled && !enabled)
	if changed {
		if c.pending_count>0 {c.scope_drops+=u64(c.pending_count);for c.pending_count>0 {settle(c,.Scope_Changed)}}
		c.pending_head,c.pending_count,c.request,c.next_send=0,0,0,0;c.request_active=false
		for &peer in c.peers {peer={}}
		if c.scope.room!=scope.room || c.scope.content!=scope.content {c.lines={};c.line_count=0;c.last_id={};c.history_serial+=1}
		if c.scope.epoch!=scope.epoch {c.sequence=0}
		c.marker_count=0;c.local_tokens=4;c.local_token_at=now
	}
	c.bound,c.wire,c.scope,c.authority,c.local,c.enabled,c.now,c.time_set=true,wire,scope,authority,local,enabled,now,true
	for &peer in c.peers {
		if peer.binding.peer==0 {continue}
		keep:=false;for binding in connections {if same_binding(binding,peer.binding) {keep=true;break}}
		if !keep {peer={}}
	}
	for binding in connections {
		found:=false;for &peer in c.peers {if same_binding(peer.binding,binding) {peer.binding=binding;found=true;break}}
		if found {continue}
		for &peer in c.peers {if peer.binding.peer==0 {
			peer.binding=binding;peer.tokens=4;peer.token_at=now
			if authority {for line in c.lines[:c.line_count] {peer.queue[peer.count]={line,true};peer.count+=1}}
			break
		}}
	}
	return true
}

@(private)
broadcast :: proc(c:^Comms,value:Payload,author:Binding)->Result {
	if !c.ready || !c.enabled || !c.authority {return .Not_Ready}
	if c.sequence==max(u64) {return .Capacity}
	for peer in c.peers {if peer.binding.peer!=0 && peer.count==OUTBOX {return .Capacity}}
	c.sequence+=1
	delivery:=Delivery{entry={id={c.scope.epoch,c.sequence},seat=author.seat,identity=author.identity,name=author.name,value=value}}
	for &peer in c.peers {if peer.binding.peer!=0 {
		peer.queue[(peer.head+peer.count)%OUTBOX]=delivery;peer.count+=1
	}}
	record(c,delivery);return .None
}
@(private)
consume_token :: proc(tokens:^f64,at:^u64,now:u64)->bool {
	tokens^=min(f64(4),tokens^+f64(now-at^)*0.002);at^=now
	if tokens^<1 {return false};tokens^-=1;return true
}
@(private)
settle :: proc(c:^Comms,result:Result) {
	assert(c.receipt_count<PENDING)
	c.receipts[(c.receipt_head+c.receipt_count)%PENDING]={c.pending_ids[c.pending_head],result,c.pending[c.pending_head]};c.receipt_count+=1
	c.pending_head=(c.pending_head+1)%PENDING;c.pending_count-=1
	c.last_result=result;c.result_serial+=1;c.next_send=0;c.request_active=false
}
@(private)
send :: proc(c:^Comms,peer:^Peer,packet:Packet)->tr.Send_Result {
	p:=packet;p.version=2;p.room=c.scope.room;p.binding=peer.binding.generation
	if sc.pack(&c.codec,p,{kind=PACKET_KIND,epoch=c.scope.epoch,content=c.scope.content},c.txb[:]).error!=.None {return .Invalid}
	return tr.send(&c.wire,peer.binding.peer,.Reliable,c.txb[:c.codec.wire_size+sc.HEADER_BYTES])
}
// Advanced ingress for a caller-owned packet router. Ordinary consumers use
// configure/frame; this entry point still validates the complete wire packet.
receive :: proc(c:^Comms,from:tr.Peer_Id,channel:tr.Channel,bytes:[]u8) {
	if !c.enabled || channel!=.Reliable {c.rejected+=1;return}
	peer:^Peer
	for &candidate in c.peers {if candidate.binding.peer==from {peer=&candidate;break}}
	if peer==nil {c.rejected+=1;return}
	p:Packet
	_,report:=sc.unpack(&c.codec,&p,bytes,{kind=PACKET_KIND,epoch=c.scope.epoch,content=c.scope.content})
	if report.error!=.None || p.version!=2 || p.room!=c.scope.room || p.binding!=peer.binding.generation {c.rejected+=1;return}
	if c.authority {
		// Identity and seat always come from admission. An opted-in observer
  // may supply only a validated display label, never authority or identity.
		if p.kind!=.Request || p.request==0 || p.result!=.None || p.delivery.historical || p.delivery.entry.id!=(Id{}) || p.delivery.entry.seat!=0 || (!lb.name_valid(p.delivery.entry.name) || (p.delivery.entry.name!=(lb.Name{}) && (!peer.binding.spectator || !peer.binding.observer_name_allowed))) || p.delivery.entry.identity!=([32]u8{}) || !valid(p.delivery.entry.value) {c.rejected+=1;return}
		if p.request==peer.request_seen {peer.reply=true;c.duplicates+=1;return}
		if p.request!=peer.request_seen+1 {c.rejected+=1;return}
		result:Result
		if peer.binding.spectator && p.delivery.entry.value.kind==.Marker {result=.Permission} else if !consume_token(&peer.tokens,&peer.token_at,c.now) {result=.Rate_Limited} else {
			author:=peer.binding
   if author.spectator && author.observer_name_allowed && p.delivery.entry.name.length>0 {author.name=p.delivery.entry.name}
   result=broadcast(c,p.delivery.entry.value,author)
		}
		peer.request_seen,peer.last_result,peer.reply=p.request,result,true
	} else {
		#partial switch p.kind {
		case .Ack:
			if p.delivery!=(Delivery{}) || p.request==0 || p.result>.Scope_Changed {c.rejected+=1;return}
			if c.request_active && c.pending_count>0 && p.request==c.request {settle(c,p.result)}
		case .Deliver:
			e:=p.delivery.entry
			if p.request!=0 || p.result!=.None || e.id.epoch==0 || e.id.epoch>c.scope.epoch || e.id.sequence==0 || !valid(e.value,true) || !lb.name_valid(e.name) || (p.delivery.historical && e.value.kind==.Marker) {c.rejected+=1;return}
			if e.value.kind==.System && (e.seat!=0 || e.identity!=([32]u8{}) || e.name!=(lb.Name{})) {c.rejected+=1;return}
			record(c,p.delivery)
		case:c.rejected+=1
		}
	}
}
frame :: proc(c:^Comms) {
	if !c.ready || !c.bound {return}
	for _ in 0..<128 {
		packet:=tr.receive(&c.wire,c.rxb[:])
		if packet.state==.Empty || packet.state==.Disconnected {break}
		if packet.state!=.Received {c.rejected+=1;continue}
		receive(c,packet.from,packet.channel,c.rxb[:packet.count])
	}
	if !c.enabled {return}
	if c.authority {
		for c.pending_count>0 {
			value:=c.pending[c.pending_head]
			result:=consume_token(&c.local_tokens,&c.local_token_at,c.now) ? broadcast(c,value,c.local) : Result.Rate_Limited
			settle(c,result)
		}
		for &peer in c.peers {
			if peer.binding.peer==0 {continue}
			if peer.reply && send(c,&peer,Packet{kind=.Ack,request=peer.request_seen,result=peer.last_result})==.Sent {peer.reply=false}
			for _ in 0..<16 {
				if peer.count==0 {break}
				if send(c,&peer,Packet{kind=.Deliver,delivery=peer.queue[peer.head]})!=.Sent {break}
				peer.head=(peer.head+1)%OUTBOX;peer.count-=1
			}
		}
	} else if c.pending_count>0 && c.now>=c.next_send {
		peer:^Peer;for &candidate in c.peers {if candidate.binding.peer!=0 {peer=&candidate;break}}
		if peer==nil {return}
		if !c.request_active {
			if c.request==max(u64) {settle(c,.Capacity);return}
			c.request+=1;c.request_active=true
		}
		// One request at a time. A lost acknowledgement retries the same identity;
		// the host repeats its result without broadcasting twice.
		packet:=Packet{kind=.Request,request=c.request,delivery={entry={value=c.pending[c.pending_head],name=c.pending_names[c.pending_head]}}}
		send(c,peer,packet);c.next_send=c.now+250
	}
}

// Display metadata can change without changing the admitted connection or its
// retry frontier. Queued/history entries retain their original stamped name.
@(private)
same_binding :: proc(a,b:Binding)->bool {return a.peer==b.peer && a.generation==b.generation && a.seat==b.seat && a.identity==b.identity && a.spectator==b.spectator}
