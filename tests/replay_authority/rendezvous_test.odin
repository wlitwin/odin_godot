package replay_authority_test

import "core:testing"
import auth "godot:replay/authority"

@(test)
rendezvous_creation_requires_current_owner_and_join_requires_registered_identity :: proc(t:^testing.T) {
 f:Rpc_Fixture;rpc_setup(&f);defer rpc_destroy(&f)
 reply:=rpc_call(&f,0,{verb=.Start});testing.expect_value(t,reply.result,auth.Error.None)
 challenge:=auth.Nonce{0=42}
 owner:=auth.rendezvous_proof(reply.view,A,{0=21},challenge,true)
 identity,code,err:=auth.rendezvous_verify(&f.service,owner[:],challenge,true)
 testing.expect_value(t,err,auth.Error.None);testing.expect(t,identity==A && code==auth.rendezvous_code(reply.view))
 join:=auth.rendezvous_proof(reply.view,B,{0=22},challenge,false)
 identity,_,err=auth.rendezvous_verify(&f.service,join[:],challenge,false)
 testing.expect(t,err==.None && identity==B)
 hijack:=auth.rendezvous_proof(reply.view,B,{0=22},challenge,true)
 _,_,err=auth.rendezvous_verify(&f.service,hijack[:],challenge,true);testing.expect_value(t,err,auth.Error.Denied)
 old:=auth.rendezvous_proof(reply.view,{B.member,B.incarnation-1},{0=22},challenge,false)
 _,_,err=auth.rendezvous_verify(&f.service,old[:],challenge,false);testing.expect_value(t,err,auth.Error.Denied)
}
@(test)
rendezvous_proofs_bind_connection_challenge_content_and_authority_term :: proc(t:^testing.T) {
 f:Rpc_Fixture;rpc_setup(&f);defer rpc_destroy(&f)
 view:=rpc_call(&f,0,{verb=.Start}).view
 nonce:=auth.Nonce{0=42};proof:=auth.rendezvous_proof(view,A,{0=21},nonce,true)
 _,_,err:=auth.rendezvous_verify(&f.service,proof[:],{0=43},true);testing.expect_value(t,err,auth.Error.Denied)
 proof[len(proof)-1]~=1
 _,_,err=auth.rendezvous_verify(&f.service,proof[:],nonce,true);testing.expect_value(t,err,auth.Error.Denied)
 changed:=view;changed.content+=1;proof=auth.rendezvous_proof(changed,A,{0=21},nonce,true)
 _,_,err=auth.rendezvous_verify(&f.service,proof[:],nonce,true);testing.expect_value(t,err,auth.Error.Denied)
 changed=view;changed.epoch+=1;proof=auth.rendezvous_proof(changed,A,{0=21},nonce,true)
 _,_,err=auth.rendezvous_verify(&f.service,proof[:],nonce,true);testing.expect_value(t,err,auth.Error.Stale)
 proof=auth.rendezvous_proof(view,A,{0=21},nonce,true);f.clock.now+=2000
 _,_,err=auth.rendezvous_verify(&f.service,proof[:],nonce,true);testing.expect_value(t,err,auth.Error.Stale)
}
