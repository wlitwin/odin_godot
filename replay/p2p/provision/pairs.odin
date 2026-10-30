package replay_p2p_provision

import "core:crypto"
import "core:crypto/hmac"
import auth "godot:replay/authority"
import lk "godot:replay/p2p/link"
import p "godot:replay/provision"
import rec "godot:replay/recovery"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

PAIR_VERSION :: u16(1)
PAIR_REQUEST :: u16(0x5054)
PAIR_REPLY :: u16(0x5055)
PAIR_BYTES :: 2048
Pair_Request :: struct {version:u16,room,content:u64,identity:auth.Identity,registration,challenge:auth.Nonce,remote:u64}
Pair_Reply :: struct {version:u16,room,content:u64,request_hash:[32]u8,result:p.Error,grant:lk.Grant,endpoint:auth.Endpoint}
Pair_Codecs :: struct {request,reply:sc.Schema}
Pair_Service :: struct {
    ready,failed:bool,
    hub:^Hub,
    codecs:Pair_Codecs,
    now:u64,
    budgets:[MAX_ROOMS][8]Pair_Budget,
    received,rejected,limited,replies:u64,
    txb:[PAIR_BYTES]u8,
}
@(private)
Pair_Budget :: struct {initialized:bool,at:u64,budget:f64}

pair_codecs_init :: proc(c:^Pair_Codecs,allocator:=context.allocator)->bool {
    if c.request.initialized || c.reply.initialized {return false}
    if sc.init(&c.request,Pair_Request,allocator=allocator).error!=.None || sc.init(&c.reply,Pair_Reply,allocator=allocator).error!=.None ||
       max(c.request.wire_size,c.reply.wire_size)+sc.HEADER_BYTES+32>PAIR_BYTES {pair_codecs_destroy(c);return false}
    return true
}
pair_codecs_destroy :: proc(c:^Pair_Codecs) {sc.destroy(&c.request);sc.destroy(&c.reply)}
pair_service_open :: proc(s:^Pair_Service,hub:^Hub,allocator:=context.allocator)->bool {
    if s.ready || hub==nil || !hub.ready || !pair_codecs_init(&s.codecs,allocator) {return false}
    now,ok:=hub.clock.read(hub.clock.user);if !ok {pair_service_close(s);return false}
    s.hub,s.now,s.ready=hub,now,true;return true
}
pair_service_close :: proc(s:^Pair_Service) {pair_codecs_destroy(&s.codecs);crypto.zero_explicit(s,size_of(Pair_Service))}

// This response contains a pair secret. Use the same verified confidential
// transport as enrollment (or explicit loopback fixtures). Keys never go into
// public rosters or gameplay archives. This read performs no durable mutation.
pair_service_receive :: proc(s:^Pair_Service,from:tr.Peer_Id,bytes:[]u8)->bool {
    if !s.ready || s.failed || !s.hub.ready || s.hub.poisoned || from==0 {return false}
    s.received+=1
    if len(bytes)!=sc.HEADER_BYTES+s.codecs.request.wire_size+32 {s.rejected+=1;return false}
    q:Pair_Request
    meta,report:=sc.unpack(&s.codecs.request,&q,bytes[:len(bytes)-32],{kind=PAIR_REQUEST,epoch=u64(PAIR_VERSION),content=s.hub.config.content})
    if report.error!=.None || meta.tick!=0 || !pair_request_valid(q) || q.content!=s.hub.config.content {s.rejected+=1;return false}
    room:^Room;room_index:=-1
    for candidate,i in s.hub.rooms {if candidate!=nil && candidate.bundle.enrollment.record.room==q.room {room,room_index=candidate,i;break}}
    if room==nil {s.rejected+=1;return false}
    slot:=int(q.identity.member)-1
    if slot<0 || slot>=int(room.bundle.players) {s.rejected+=1;return false}
    key:=room.bundle.enrollment.enrollments[slot].key
    defer crypto.zero_explicit(&key,size_of(key))
    if !pair_authenticated(key,PAIR_REQUEST,bytes) {s.rejected+=1;return false}
    result:=usable(room);grant:lk.Grant;endpoint:auth.Endpoint
    member:=room.bundle.enrollment.record.members[slot]
    if result==.None && (!member.enabled || member.identity!=q.identity || room.bundle.enrollment.record.requests[slot].nonce!=q.registration) {result=.Denied}
    now,ok:=s.hub.clock.read(s.hub.clock.user)
    if !ok || now<s.now {s.failed=true;return false};s.now=now
    if result==.None {
        budget:=&s.budgets[room_index][slot]
        if !budget.initialized {budget^={true,now,8}}
        budget.budget=min(8,budget.budget+f64(now-budget.at)*4/1000);budget.at=now
        if budget.budget<1 {result=.Rate_Limited;s.limited+=1} else {budget.budget-=1}
    }
    if result==.None {
        reg,error:=registry(room);defer crypto.zero_explicit(&reg,size_of(reg))
        result=error
        if result==.None {
            remote:=int(q.remote)-1
            if remote<0 || remote>=int(reg.match.count) || !reg.enabled[remote] {result=.Denied}
            else if room.bundle.enrollment.record.requests[remote].nonce==(auth.Nonce{}) {result=.Not_Ready}
            else {
                derived:bool;grant,derived=lk.derive(reg.match,reg.credentials[slot],reg.credentials[remote])
                if !derived {result=.Invalid} else {endpoint=room.bundle.enrollment.record.members[remote].endpoint}
            }
        }
    }
    if result!=.None {grant,endpoint={},{};s.rejected+=1}
    reply:=Pair_Reply{PAIR_VERSION,q.room,q.content,rec.hash(bytes),result,grant,endpoint}
    defer crypto.zero_explicit(&reply,size_of(reply));defer crypto.zero_explicit(&grant,size_of(grant))
    count:=pair_pack(&s.codecs.reply,reply,key,PAIR_REPLY,q.content,s.txb[:])
    if count!=0 && tr.send(&s.hub.wire,from,.Reliable,s.txb[:count])==.Sent {s.replies+=1}
    crypto.zero_explicit(&s.txb,size_of(s.txb));return true
}

Pair_Client :: struct {
    ready,pending,complete,sent:bool,
    owner:^Client,
    wire:tr.Transport,
    codecs:Pair_Codecs,
    request:Pair_Request,
    reply:Pair_Reply,
    last_challenge:auth.Nonce,
    request_hash:[32]u8,
    started,last_send,now:u64,
    count:int,
    error:p.Error,
    txb:[PAIR_BYTES]u8,
    rxb:[tr.MAX_PACKET_BYTES]u8,
}
// Owner and wire must stay alive. Use a router lane or separate connection so
// this pump and the registration client's pump cannot consume each other's RPCs.
pair_client_open :: proc(c:^Pair_Client,owner:^Client,wire:tr.Transport,allocator:=context.allocator)->bool {
    if c.ready || owner==nil || owner.phase!=.Ready || !pair_codecs_init(&c.codecs,allocator) {return false}
    c.owner,c.wire,c.ready=owner,wire,true;return true
}
pair_client_close :: proc(c:^Pair_Client) {pair_codecs_destroy(&c.codecs);crypto.zero_explicit(c,size_of(Pair_Client))}
pair_client_begin :: proc(c:^Pair_Client,remote:u64,challenge:auth.Nonce)->bool {
    if !c.ready || c.pending || c.owner.phase!=.Ready || challenge==(auth.Nonce{}) || challenge==c.last_challenge {return false}
    o:=c.owner
    q:=Pair_Request{PAIR_VERSION,o.grant.room,o.grant.content,o.lease.identity,o.rpc.nonce,challenge,remote}
    if !pair_request_valid(q) || remote>u64(o.players) {return false}
    now,ok:=o.lease.clock.read(o.lease.clock.user);if !ok || now<c.now {return false}
    count:=pair_pack(&c.codecs.request,q,o.grant.key,PAIR_REQUEST,q.content,c.txb[:])
    if count==0 {return false}
    c.request,c.count,c.request_hash,c.last_challenge=q,count,rec.hash(c.txb[:count]),challenge
    c.started,c.now,c.last_send=now,now,0;c.pending,c.complete,c.sent=true,false,false;c.reply={};c.error=.None
    return true
}
pair_client_receive :: proc(c:^Pair_Client,from:tr.Peer_Id,bytes:[]u8)->bool {
    if !c.ready || !c.pending || c.owner.phase!=.Ready || c.owner.lease.identity!=c.request.identity || from!=1 ||
       len(bytes)!=sc.HEADER_BYTES+c.codecs.reply.wire_size+32 || !pair_authenticated(c.owner.grant.key,PAIR_REPLY,bytes) {return false}
    reply:Pair_Reply
    meta,report:=sc.unpack(&c.codecs.reply,&reply,bytes[:len(bytes)-32],{kind=PAIR_REPLY,epoch=u64(PAIR_VERSION),content=c.request.content})
    if report.error!=.None || meta.tick!=0 || reply.version!=PAIR_VERSION || reply.room!=c.request.room || reply.content!=c.request.content || reply.request_hash!=c.request_hash {return false}
    if reply.result!=.None {if reply.grant!=(lk.Grant{}) || reply.endpoint!=(auth.Endpoint{}) {return false}}
    else {
        if !lk.grant_valid(reply.grant) || reply.grant.scope.match!=c.owner.match {return false}
        local_found,remote_found:=false,false
        for id in reply.grant.scope.members {if id==c.request.identity {local_found=true};if id.member==c.request.remote {remote_found=true}}
        endpoint:=reply.endpoint
        probe:=auth.record_make(reply.room,reply.content,c.request.identity);probe.members[0]={identity=c.request.identity,endpoint=endpoint}
        if !local_found || !remote_found || !auth.record_valid(probe) {return false}
    }
    c.reply,c.complete,c.pending=reply,true,false;return true
}
pair_client_pump :: proc(c:^Pair_Client)->p.Error {
    if !c.ready {return .Not_Ready}
    if c.owner.phase!=.Ready || (c.pending && c.owner.lease.identity!=c.request.identity) {c.pending=false;c.error=.Denied;return c.error}
    now,ok:=c.owner.lease.clock.read(c.owner.lease.clock.user)
    if !ok || now<c.now {c.pending=false;c.error=.Clock;return c.error};c.now=now
    tr.poll(&c.wire)
    for _ in 0..<32 {
        packet:=tr.receive(&c.wire,c.rxb[:]);if packet.state==.Empty || packet.state==.Disconnected {break}
        if packet.state==.Received {pair_client_receive(c,packet.from,c.rxb[:packet.count])}
    }
    if c.pending {
        if now-c.started>=10000 {c.pending=false;c.error=.Not_Ready;return c.error}
        if !c.sent || now-c.last_send>=250 {
            if tr.send(&c.wire,1,.Reliable,c.txb[:c.count])==.Sent {c.sent,c.last_send=true,now}
        }
    }
    return .None
}
@(private)
pair_request_valid :: proc(q:Pair_Request)->bool {
    return q.version==PAIR_VERSION && q.room!=0 && q.content!=0 && auth.identity_valid(q.identity) && q.identity.member<=8 &&
        q.registration!=(auth.Nonce{}) && q.challenge!=(auth.Nonce{}) && q.remote!=0 && q.remote<=8 && q.remote!=q.identity.member
}
@(private)
pair_mac :: proc(key:auth.Key,kind:u16,bytes:[]u8)->[32]u8 {
    k:=key;ctx:hmac.Context;hmac.init(&ctx,.SHA256,k[:])
    domain:=kind==PAIR_REQUEST ? "replay-p2p-pair-request-v1" : "replay-p2p-pair-reply-v1"
    hmac.update(&ctx,transmute([]u8)domain);hmac.update(&ctx,bytes)
    tag:[32]u8;hmac.final(&ctx,tag[:]);return tag
}
@(private)
pair_authenticated :: proc(key:auth.Key,kind:u16,bytes:[]u8)->bool {
    if len(bytes)<32 {return false}
    tag:=pair_mac(key,kind,bytes[:len(bytes)-32]);return crypto.compare_constant_time(tag[:],bytes[len(bytes)-32:])==1
}
@(private)
pair_pack :: proc(schema:^sc.Schema,value:$T,key:auth.Key,kind:u16,content:u64,dst:[]u8)->int {
    count:=sc.HEADER_BYTES+schema.wire_size
    if len(dst)<count+32 || sc.pack(schema,value,{kind=kind,epoch=u64(PAIR_VERSION),content=content},dst[:count]).error!=.None {return 0}
    tag:=pair_mac(key,kind,dst[:count]);copy(dst[count:count+32],tag[:]);return count+32
}
