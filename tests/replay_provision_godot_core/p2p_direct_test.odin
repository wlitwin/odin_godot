package provision_godot_test

import "core:testing"
import lk "godot:replay/p2p/link"
import p "godot:replay/provision"
import rgd "godot:replay/godot"
import auth "godot:replay/authority"

@(test)
native_listener_can_differ_from_advertised_address_and_port :: proc(t:^testing.T) {
    advertised,_:=auth.endpoint("game.example",45000)
    listen,_:=auth.endpoint("0.0.0.0",46000)
    before:=advertised
    selected,ok:=rgd.p2p_direct_listen_endpoint(advertised,{listen=listen})
    testing.expect(t,ok && selected==listen && advertised==before)
    selected,ok=rgd.p2p_direct_listen_endpoint(advertised)
    testing.expect(t,ok && selected==advertised)
    for variation in 0..<5 {
        bad:=listen
        switch variation {
        case 0:bad.port=0
        case 1:bad.host[0]=0
        case 2:bad.host[95]=1
        case 3:bad.host[0]=' '
        case 4:bad,_=auth.endpoint("rtc",1)
        }
        _,ok=rgd.p2p_direct_listen_endpoint(advertised,{listen=bad});testing.expect(t,!ok)
    }
    _,ok=rgd.p2p_direct_listen_endpoint({},{listen=listen});testing.expect(t,!ok)
}

@(test)
signed_registration_refusal_retires_native_link_keys :: proc(t:^testing.T) {
    for error in ([2]p.Error{.Denied,.Invalid}) {
        party:=new(rgd.P2P_Party);direct:=new(rgd.P2P_Direct)
        party.registration.phase,party.registration.error=.Failed,error
        party.control.client.clock.read=proc(_:rawptr)->(u64,bool) {return 1,true}
        direct.ready,direct.admitted,direct.party=true,true,party
        direct.link.config.grant.key={0=99}
        direct.link.plain[0]=42
        rgd.p2p_direct_frame(direct)
        testing.expect(t,direct.error==.Provision && !direct.admitted && direct.link.config.grant.key==(lk.Key{}) && direct.link.plain[0]==0)
        free(direct);free(party)
    }
}
