package dockyard_short_party_test

import "core:testing"
import p "godot:replay/provision"
import rgd "godot:replay/godot"
import auth "godot:replay/authority"

SERVICE :: "wss://rooms.example.test"
FIRST :: p.Secret{0=0x76,1=0x05}
SECOND :: p.Secret{0=0x17,1=0x10}
Ledger :: struct {record:p.Enrollment_Record,writes:int,recent_room:u64}
load :: proc(user:rawptr)->(p.Enrollment_Record,bool,p.Enrollment_Error){l:=cast(^Ledger)user;return l.record,l.record.version!=0,.None}
write :: proc(user:rawptr,expected:u64,next:p.Enrollment_Record)->(u64,p.Enrollment_Error){l:=cast(^Ledger)user;l.writes+=1;return 0,.Conflict}
slot :: proc(user:rawptr,name:string)->(rgd.Enrollment_Backing,bool){return {user,load,write},true}
recent :: proc(user:rawptr,key:string)->(u64,u64,rgd.Party_Error){l:=cast(^Ledger)user;return l.recent_room,l.recent_room!=0?1:0,.None}
select :: proc(user:rawptr,key:string,room,expected:u64)->rgd.Party_Error{return .None}
entropy :: proc(user:rawptr,dst:[]u8)->bool{for &byte in dst{byte=1};secret:=SECOND;copy(dst,secret[:]);return true}
config :: proc(l:^Ledger)->rgd.Party_Config{
	endpoint,ok:=auth.endpoint("127.0.0.1",45001);assert(ok)
	return {service=SERVICE,namespace="short-room-test",content=55,endpoint=endpoint,invite_role=.Player,invite_uses=1,
	        entropy={read=entropy},storage={l,slot,recent,select},short_codes=true}
}

@(test)
five_character_collision_preserves_an_existing_local_enrollment :: proc(t:^testing.T){
	l:Ledger;o:rgd.Party;defer rgd.party_close(&o)
	cfg:=config(&l);code,_:=p.short_code(FIRST,55);ticket,_:=p.short_ticket_parse(string(code[:]),55)
	url,_:=p.service_url(SERVICE)
	l.record={version=p.ENROLLMENT_VERSION,revision=2,state=.Ready,service=url,
	 request={version=p.PROTOCOL,verb=.Create,room=ticket.room,content=55,claim=FIRST,endpoint=cfg.endpoint},
	 grant={room=ticket.room,content=55,identity={1,1},key={0=51},token={0=61},can_host=true,trusted_authority=true}}
	assert(p.enrollment_record_valid(l.record))
	before:=l.record
	assert(rgd.party_open(&o,cfg));assert(rgd.party_begin(&o,.Create))
	testing.expect(t,o.request.claim==SECOND&&o.request.room==ticket.room)
	rgd.party_frame(&o)
	testing.expect(t,o.failed&&o.error==.Conflict&&!o.connection.ready&&l.writes==0&&l.record==before)
}

@(test)
short_codes_do_not_accept_privileged_or_reusable_invite_configuration :: proc(t:^testing.T){
	l:Ledger;o:rgd.Party;defer rgd.party_close(&o)
	cfg:=config(&l);cfg.invite_role=.Trusted_Peer
	testing.expect(t,!rgd.party_open(&o,cfg))
	cfg.invite_role=.Player;cfg.invite_uses=2
	testing.expect(t,!rgd.party_open(&o,cfg))
}

@(test)
existing_guest_can_rejoin_with_short_codes_enabled_without_a_provisioning_socket :: proc(t:^testing.T){
	l:=Ledger{recent_room=44};o:rgd.Party;defer rgd.party_close(&o)
	cfg:=config(&l);url,_:=p.service_url(SERVICE)
	l.record={version=p.ENROLLMENT_VERSION,revision=2,state=.Ready,service=url,
	 request={version=p.PROTOCOL,verb=.Join,room=44,content=55,claim=FIRST,ticket={0=91},endpoint=cfg.endpoint},
	 grant={room=44,content=55,identity={2,3},key={0=51},token={0=61}}}
	assert(p.enrollment_record_valid(l.record))
	assert(rgd.party_open(&o,cfg));assert(rgd.party_begin(&o,.Rejoin));rgd.party_frame(&o)
	g,ready:=rgd.party_grant(&o)
	testing.expect(t,ready&&g==l.record.grant&&!o.failed&&!o.connection.ready&&l.writes==0)
}
