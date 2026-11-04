package replay_physics_net_test

import "core:testing"
import net "godot:replay/net"
import bd "godot:box3d/diagnostics"

@(test)
local_revision_proof_requires_same_complete_signature_and_packet_scope :: proc(t:^testing.T){
	expected:=bd.Signature{epoch=3,tick=12}
	expected.identity.profile=7;expected.complete[0]=1
	proof:=net.Physics_Verification{valid=true,signature=expected,pending_id=9,generation=2,serial=4}
	testing.expect(t,net.physics_verification_matches(proof,expected,9,2,4))
	changed:=expected;changed.complete[0]=2
	testing.expect(t,!net.physics_verification_matches(proof,changed,9,2,4))
	changed=expected;changed.epoch+=1
	testing.expect(t,!net.physics_verification_matches(proof,changed,9,2,4))
	changed=expected;changed.identity.profile+=1
	testing.expect(t,!net.physics_verification_matches(proof,changed,9,2,4))
	testing.expect(t,!net.physics_verification_matches(proof,expected,10,2,4))
	testing.expect(t,!net.physics_verification_matches(proof,expected,9,3,4))
	testing.expect(t,!net.physics_verification_matches(proof,expected,9,2,5))
	testing.expect(t,!net.physics_verification_matches(proof,expected,0,2,4)) // reset/dropped pending owner
	proof.valid=false
	testing.expect(t,!net.physics_verification_matches(proof,expected,9,2,4)) // failed/later-aborted operation
}
