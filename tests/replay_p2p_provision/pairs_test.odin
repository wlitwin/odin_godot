package p2p_provision_test

import "core:testing"
import auth "godot:replay/authority"
import lk "godot:replay/p2p/link"
import pp "godot:replay/p2p/provision"
import p "godot:replay/provision"
import tr "godot:replay/transport"

Pair_Fixture :: struct {hub:Hub_Fixture,service:pp.Pair_Service,owners:[2]pp.Client,pairs:[2]pp.Pair_Client}
pair_setup :: proc(f:^Pair_Fixture) {
    hub_setup(&f.hub)
    creator:=hub_call(&f.hub,create_request())
    q:=p.Request{version=p.PROTOCOL,verb=.Invite,room=871,content=55,claim=ADMIN,ticket=INVITE,uses=1}
    assert(hub_call(&f.hub,q).result==.None)
    joined:=hub_call(&f.hub,{version=p.PROTOCOL,verb=.Join,room=871,content=55,claim=CLAIM,ticket=INVITE,endpoint=address(45002)})
    grants:=[2]p.Grant{creator.grant,joined.grant}
    b:=&f.hub.base
    assert(pp.pair_service_open(&f.service,&f.hub.hub))
    for &owner,i in f.owners {
        assert(pp.client_open(&owner,grants[i],2,{0=u8(30+i)},{b,clock},tr.memory_transport(&b.endpoints[1])))
        for _ in 0..<100 {
            pair_tick(f);pp.client_frame(&owner);pair_server(f)
            if owner.phase==.Ready {break}
        }
        assert(owner.phase==.Ready)
        assert(pp.pair_client_open(&f.pairs[i],&owner,tr.memory_transport(&b.endpoints[1])))
    }
}
pair_destroy :: proc(f:^Pair_Fixture) {
    for &c in f.pairs {pp.pair_client_close(&c)}
    for &c in f.owners {pp.client_close(&c)}
    pp.pair_service_close(&f.service);hub_destroy(&f.hub)
}
pair_tick :: proc(f:^Pair_Fixture) {b:=&f.hub.base;b.now+=10;assert(tr.memory_advance(&b.memory,b.now/10))}
pair_server :: proc(f:^Pair_Fixture) {
    wire:=tr.memory_transport(&f.hub.base.endpoints[0]);buffer:[tr.MAX_PACKET_BYTES]u8
    for _ in 0..<32 {
        packet:=tr.receive(&wire,buffer[:]);if packet.state!=.Received {break}
        if !pp.hub_control_receive(&f.hub.hub,packet.from,buffer[:packet.count]) {pp.pair_service_receive(&f.service,packet.from,buffer[:packet.count])}
    }
}
pair_call :: proc(f:^Pair_Fixture,index:int,challenge:u8)->pp.Pair_Reply {
    c:=&f.pairs[index]
    assert(pp.pair_client_begin(c,u64(2-index),{0=challenge}))
    for _ in 0..<100 {
        pair_tick(f);assert(pp.pair_client_pump(c)==.None);pair_server(f)
        if c.complete {return c.reply}
    }
    panic("missing pair-key reply")
}

@(test)
registered_participants_receive_same_pair_secret_without_other_enrollment_keys :: proc(t:^testing.T) {
    f:=new(Pair_Fixture);defer free(f);pair_setup(f);defer pair_destroy(f)
    before:=f.hub.base.ledger.writes
    a:=pair_call(f,0,50);b:=pair_call(f,1,51)
    testing.expect(t,a.result==.None && b.result==.None && a.grant==b.grant && lk.grant_valid(a.grant))
    testing.expect_value(t,f.hub.base.ledger.writes,before)
    testing.expect(t,a.grant.key!=f.owners[0].grant.key && a.grant.key!=f.owners[1].grant.key)
    testing.expect(t,a.endpoint==address(45002) && b.endpoint==address())
    testing.expect_value(t,a.grant.scope.members,([2]auth.Identity{{1,2},{2,2}}))
    testing.expect(t,!pp.pair_client_begin(&f.pairs[0],2,{0=50}))
    // A newer remote incarnation changes the pair key while retaining the match.
    f.hub.base.now+=3000
    replacement:pp.Client;defer pp.client_close(&replacement)
    assert(pp.client_open(&replacement,f.owners[1].grant,2,{0=45},{&f.hub.base,clock},tr.memory_transport(&f.hub.base.endpoints[1])))
    for _ in 0..<100 {pair_tick(f);pp.client_frame(&replacement);pair_server(f);if replacement.phase==.Ready {break}}
    testing.expect(t,replacement.phase==.Ready && replacement.lease.identity==(auth.Identity{2,3}))
    newer:=pair_call(f,0,52)
    testing.expect(t,newer.result==.None && newer.grant.key!=a.grant.key && newer.grant.scope.match==a.grant.scope.match)
    stale:=pair_call(f,1,53)
    testing.expect(t,stale.result==.Denied && stale.grant==(lk.Grant{}) && stale.endpoint==(auth.Endpoint{}))
}

@(test)
pair_requests_require_current_registration_and_valid_mac :: proc(t:^testing.T) {
    f:=new(Pair_Fixture);defer free(f);pair_setup(f);defer pair_destroy(f)
    c:=&f.pairs[0]
    assert(pp.pair_client_begin(c,2,{0=60}))
    copied:=make([]u8,c.count);defer delete(copied);copy(copied,c.txb[:c.count]);copied[len(copied)-1]~=1
    writes,replies:=f.hub.base.ledger.writes,f.service.replies
    testing.expect(t,!pp.pair_service_receive(&f.service,2,copied) && f.hub.base.ledger.writes==writes && f.service.replies==replies)
    c.pending=false
    nonce:=f.owners[0].rpc.nonce;f.owners[0].rpc.nonce={0=99}
    denied:=pair_call(f,0,61)
    testing.expect(t,denied.result==.Denied && denied.grant==(lk.Grant{}))
    f.owners[0].rpc.nonce=nonce
    testing.expect(t,!pp.pair_client_begin(c,1,{0=62}) && !pp.pair_client_begin(c,3,{0=62}))
    accepted:=pair_call(f,0,62);testing.expect_value(t,accepted.result,p.Error.None)
}

@(test)
delayed_pair_reply_cannot_complete_a_new_request_and_budget_is_per_member :: proc(t:^testing.T) {
    f:=new(Pair_Fixture);defer free(f);pair_setup(f);defer pair_destroy(f)
    c:=&f.pairs[0]
    assert(pp.pair_client_begin(c,2,{0=70}))
    assert(pp.pair_service_receive(&f.service,2,c.txb[:c.count]))
    pair_tick(f)
    wire:=tr.memory_transport(&f.hub.base.endpoints[1]);bytes:[pp.PAIR_BYTES]u8
    packet:=tr.receive(&wire,bytes[:]);assert(packet.state==.Received)
    testing.expect(t,pp.pair_client_receive(c,packet.from,bytes[:packet.count]) && c.complete)
    assert(pp.pair_client_begin(c,2,{0=71}))
    testing.expect(t,!pp.pair_client_receive(c,packet.from,bytes[:packet.count]) && c.pending)
    c.pending=false
    limited:=false
    for i in 0..<12 {reply:=pair_call(f,0,u8(72+i));if reply.result==.Rate_Limited {limited=true}}
    testing.expect(t,limited && f.service.limited>0)
    other:=pair_call(f,1,90);testing.expect_value(t,other.result,p.Error.None)
}
