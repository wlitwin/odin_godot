package kit_recovery_flows_test

import "core:testing"
import b "godot:box3d"
import k "godot:kit/sim"
import s "godot:kit/session"
import f "godot:tests/kit_box3d_net"
import wp "godot:tests/kit_world_protocol"

@(test)
progressed_authority_late_spectator_adopts_and_confirms_with_zero_only_ingress :: proc(t:^testing.T){
 diagnostics:=k.world_diagnostic_frame_owned_bytes()
 pair:wp.Pair;wp.open_pair(t,&pair)
 defer {wp.close_pair(t,&pair);testing.expect_value(t,k.world_diagnostic_frame_owned_bytes(),diagnostics)}
 pair.client.axis=1
 old:=wp.advance_pair_to(t,&pair,12);defer wp.destroy_packets(&old)
 parts_at(t,&pair.host,&pair.client,12)
 observer:f.Box
 enroll(&observer,200,0x5678,true)
 f.pump({&pair.host,&pair.client,&observer})
 testing.expect(t,observer.ses.joined&&observer.ses.me!=pair.client.ses.me)
 member,known:=s.session_player(&pair.host.ses,observer.ses.me)
 testing.expect(t,known&&member.connected&&member.spectator&&member.peer==observer.peer)
 f.setup(&observer,3,&pair.catalog);defer f.destroy(&observer)
 k.lane_set_sim(&observer.lane,&observer,no_observer_sample,f.step)
 testing.expect_value(t,k.lane_world_send_checkpoint(&pair.host.lane,observer.peer,.Welcome),k.World_Error.Ok)
 f.pump({&pair.host,&pair.client,&observer})
 _=k.lane_frame(&observer.lane,0)
 testing.expect(t,k.lane_world_network_status(&observer.lane).ready)
 testing.expect_value(t,k.lane_now(&observer.lane),u64(12))
 testing.expect_value(t,k.lane_world_confirmed(&observer.lane),u64(12))
 testing.expect_value(t,observer.effects,0)
 parts_at(t,&pair.host,&observer,12)
 scope:=k.lane_world_protocol_status(&observer.lane).bootstrap_sequence
 testing.expect(t,scope!=0)
 // Consumer policy is explicitly zero-only. Generic World positive Frame is
 // NOT claimed to block prediction merely because Session marks a spectator.
 for k.lane_now(&pair.host.lane)<24{
  if !wp.advance_one(t,&pair.client){return}
  f.pump({&pair.host,&pair.client,&observer})
  if !wp.advance_one(t,&pair.host){return}
  packets:=wp.take_packets(&pair.host)
  wp.expect_small_normal(t,packets[:])
  wp.deliver_all(&pair.client,pair.host.peer,packets[:])
  wp.deliver_all(&observer,pair.host.peer,packets[:]);wp.destroy_packets(&packets)
  _=k.lane_frame(&pair.client.lane,0)
  testing.expect_value(t,k.lane_frame(&observer.lane,0),0)
  testing.expect_value(t,k.lane_now(&observer.lane),k.lane_world_confirmed(&observer.lane))
  testing.expect_value(t,wp.count_kind(observer.out[:],k.SIM_WORLD_INPUT),0)
 }
 testing.expect_value(t,k.lane_world_confirmed(&observer.lane),u64(24))
 testing.expect_value(t,k.lane_world_protocol_status(&observer.lane).bootstrap_sequence,scope)
 parts_at(t,&pair.host,&pair.client,24);parts_at(t,&pair.host,&observer,24)
 expect_control(t,&pair.host,24,pair.client.ses.me,1)
 expect_control(t,&observer,24,pair.client.ses.me,1)
 testing.expect_value(t,observer.effects,2) // eligible ticks15/20, never5/10
 testing.expect(t,!k.lane_world_needs_resync(&observer.lane))
}

@(test)
same_token_new_peer_retires_old_context_and_accepts_fresh_controls_once :: proc(t:^testing.T){
 diagnostics:=k.world_diagnostic_frame_owned_bytes()
 pair:wp.Pair;wp.open_pair(t,&pair)
 old_alive:=true;replacement_alive:=false;replacement:f.Box
 defer {
  if replacement_alive{f.destroy(&replacement)}
  if old_alive{f.destroy(&pair.client)}
  f.destroy(&pair.host);testing.expect_value(t,b.recovery_catalog_destroy(&pair.catalog),b.Status.Ok)
  expect_usage(t,pair.before,diagnostics)
 }
 pair.client.axis=1
 old_authority:=wp.advance_pair_to(t,&pair,12);defer wp.destroy_packets(&old_authority)
 testing.expect(t,wp.count_kind(old_authority[:],k.SIM_WORLD_ACCEPTED)>0&&wp.count_kind(old_authority[:],k.SIM_WORLD_SIGNATURE)>0)
 old_scope:=k.lane_world_protocol_status(&pair.client.lane).bootstrap_sequence
 if !wp.advance_one(t,&pair.client){return}
 old_proposal:=wp.take_packets(&pair.client);defer wp.destroy_packets(&old_proposal)
 testing.expect(t,wp.count_kind(old_proposal[:],k.SIM_WORLD_INPUT)>0)
 // Explicit supported diagnostic export, never an automatic bulk stream.
 testing.expect_value(t,k.lane_world_send_checkpoint(&pair.host.lane,pair.client.peer,.Correction),k.World_Error.Ok)
 old_chunks:=wp.take_packets(&pair.host);defer wp.destroy_packets(&old_chunks)
 testing.expect(t,wp.count_kind(old_chunks[:],k.SIM_WORLD_CHUNK)>0)
 identity:=pair.client.ses.me;old_peer:=pair.client.peer
 s.session_peer_disconnected(&pair.host.ses,old_peer)
 testing.expect_value(t,k.lane_world_protocol_peer_disconnected(&pair.host.lane,old_peer),k.World_Error.Ok)
 s.session_peer_disconnected(&pair.client.ses,s.HOST_PEER)
 testing.expect_value(t,k.lane_world_protocol_peer_disconnected(&pair.client.lane,s.HOST_PEER),k.World_Error.Ok)
 left,was:=s.session_player(&pair.host.ses,identity)
 testing.expect(t,was&&!left.connected)
 f.destroy(&pair.client);old_alive=false
 if !advance_authority(t,&pair.host,18){return}
 unused:=wp.take_packets(&pair.host);wp.destroy_packets(&unused)
 enroll(&replacement,300,0x1234,false) // actual original token, new transport peer
 f.pump({&pair.host,&replacement})
 testing.expect(t,replacement.ses.joined&&replacement.ses.me==identity)
 joined,ok:=s.session_player(&pair.host.ses,identity)
 testing.expect(t,ok&&joined.connected&&!joined.spectator&&joined.peer==replacement.peer&&joined.peer!=old_peer)
 rejoin:=false
 for {
  event,available:=s.session_poll(&pair.host.ses);if !available{break}
  #partial switch value in event{case s.Ev_Player_Joined:if value.id==identity&&value.rejoin{rejoin=true}}
 }
 testing.expect(t,rejoin,"real Session admission explicitly reports same-identity rejoin")
 f.setup(&replacement,3,&pair.catalog);replacement_alive=true
 testing.expect_value(t,k.lane_world_send_checkpoint(&pair.host.lane,replacement.peer,.Welcome),k.World_Error.Ok)
 f.pump({&pair.host,&replacement});_=k.lane_frame(&replacement.lane,0)
 scope:=k.lane_world_protocol_status(&replacement.lane).bootstrap_sequence
 testing.expect(t,scope>old_scope&&k.lane_world_network_status(&replacement.lane).ready)
 testing.expect_value(t,k.lane_now(&replacement.lane),u64(18))
 testing.expect_value(t,k.lane_world_confirmed(&replacement.lane),u64(18))
 testing.expect_value(t,replacement.effects,0)
 parts_at(t,&pair.host,&replacement,18)
 host_before,client_before:k.World_Diagnostic_Frame
 if !save_frame(t,&pair.host,18,&host_before){return};defer k.world_diagnostic_frame_destroy(&host_before)
 if !save_frame(t,&replacement,18,&client_before){return};defer k.world_diagnostic_frame_destroy(&client_before)
 host_fx,client_fx:=pair.host.effects,replacement.effects
 owned:=k.lane_world_owned_bytes(&replacement.lane)
 rejected:=k.lane_world_network_status(&pair.host.lane).rejected
 wp.deliver_all(&pair.host,old_peer,old_proposal[:]);_=k.lane_frame(&pair.host.lane,0)
 // Also replay the SAME old bytes via the now-valid replacement peer: the
 // embedded old bootstrap must still fail, independently of peer rejection.
 wp.deliver_all(&pair.host,replacement.peer,old_proposal[:]);_=k.lane_frame(&pair.host.lane,0)
 testing.expect(t,k.lane_world_network_status(&pair.host.lane).rejected>rejected)
 wp.deliver_all(&replacement,pair.host.peer,old_authority[:])
 wp.deliver_all(&replacement,pair.host.peer,old_chunks[:]);_=k.lane_frame(&replacement.lane,0)
 expect_saved(t,&pair.host,&host_before);expect_saved(t,&replacement,&client_before)
 testing.expect_value(t,k.lane_now(&pair.host.lane),u64(18))
 testing.expect_value(t,k.lane_now(&replacement.lane),u64(18))
 testing.expect_value(t,k.lane_world_confirmed(&replacement.lane),u64(18))
 testing.expect_value(t,k.lane_world_protocol_status(&replacement.lane).bootstrap_sequence,scope)
 testing.expect_value(t,pair.host.effects,host_fx);testing.expect_value(t,replacement.effects,client_fx)
 testing.expect_value(t,k.lane_world_owned_bytes(&replacement.lane),owned)
 replacement.axis=2;replacement.action_at=19;replacement.action_kind=1
 final_packets:[dynamic]f.Parcel;defer wp.destroy_packets(&final_packets)
 for k.lane_now(&pair.host.lane)<21{
  if !wp.advance_one(t,&replacement){return}
  f.pump({&pair.host,&replacement})
  if !wp.advance_one(t,&pair.host){return}
  packets:=wp.take_packets(&pair.host)
  wp.destroy_packets(&final_packets);final_packets=wp.copy_packets(packets[:])
  wp.deliver_all(&replacement,pair.host.peer,packets[:]);wp.destroy_packets(&packets)
  _=k.lane_frame(&replacement.lane,0)
 }
 parts_at(t,&pair.host,&replacement,21)
 expect_control(t,&pair.host,21,identity,2);expect_control(t,&replacement,21,identity,2)
 testing.expect_value(t,pair.host.effects-host_fx,2) // Spawn19 and periodic20
 testing.expect_value(t,replacement.effects-client_fx,2)
 wp.deliver_all(&replacement,pair.host.peer,final_packets[:]);_=k.lane_frame(&replacement.lane,0)
 testing.expect_value(t,replacement.effects-client_fx,2)
 parts_at(t,&pair.host,&replacement,21)
}

@(test)
explicit_reset_retires_partial_corrupt_stale_transfer_then_source_free_future :: proc(t:^testing.T){
 diagnostics:=k.world_diagnostic_frame_owned_bytes()
 pair:wp.Pair;pair.before=wp.usage(t);pair.catalog=f.catalog()
 f.start_pair(&pair.host,&pair.client)
 f.setup(&pair.host,32,&pair.catalog);f.setup(&pair.client,32,&pair.catalog)
 host_alive,cat_alive:=true,true
 defer {
  f.destroy(&pair.client)
  if host_alive{f.destroy(&pair.host)}
  if cat_alive{testing.expect_value(t,b.recovery_catalog_destroy(&pair.catalog),b.Status.Ok)}
  expect_usage(t,pair.before,diagnostics)
 }
 f.bootstrap(t,&pair.host,&pair.client)
 old:=wp.advance_pair_to(t,&pair,6);defer wp.destroy_packets(&old)
 before:k.World_Diagnostic_Frame
 if !save_frame(t,&pair.client,6,&before){return};defer k.world_diagnostic_frame_destroy(&before)
 old_scope:=k.lane_world_protocol_status(&pair.client.lane).bootstrap_sequence
 fx:=pair.client.effects
 if !advance_authority(t,&pair.host,9){return}
 backlog:=wp.take_packets(&pair.host);defer wp.destroy_packets(&backlog)
 testing.expect_value(t,k.lane_world_send_checkpoint(&pair.host.lane,pair.client.peer,.Correction),k.World_Error.Ok)
 stale:=wp.take_packets(&pair.host);defer wp.destroy_packets(&stale)
 testing.expect(t,wp.count_kind(stale[:],k.SIM_WORLD_CHUNK)>1)
 first_old:f.Parcel
 for packet in stale{kind,ok:=wp.app_kind(packet);if ok&&kind==k.SIM_WORLD_CHUNK{first_old=packet;break}}
 if len(first_old.bytes)==0{testing.expect(t,false);return}
 wp.deliver(&pair.client,pair.host.peer,first_old);_=k.lane_frame(&pair.client.lane,0)
 expect_saved(t,&pair.client,&before)
 testing.expect_value(t,k.lane_world_request_reset(&pair.client.lane),k.World_Error.Ok)
 expect_saved(t,&pair.client,&before)
 request:=wp.take_packets(&pair.client);defer wp.destroy_packets(&request)
 if !advance_authority(t,&pair.host,18){return}
 delayed:=wp.take_packets(&pair.host);defer wp.destroy_packets(&delayed)
 wp.deliver_all(&pair.host,pair.client.peer,request[:]);_=k.lane_frame(&pair.host.lane,0)
 response:=wp.take_packets(&pair.host);defer wp.destroy_packets(&response)
 testing.expect(t,wp.count_kind(response[:],k.SIM_WORLD_CHUNK)>1)
 first:f.Parcel
 for packet in response{kind,ok:=wp.app_kind(packet);if ok&&kind==k.SIM_WORLD_CHUNK{first=packet;break}}
 if len(first.bytes)==0{testing.expect(t,false);return}
 wp.deliver_all(&pair.client,pair.host.peer,stale[:])
 wp.deliver_all(&pair.client,pair.host.peer,backlog[:])
 wp.deliver_all(&pair.client,pair.host.peer,delayed[:]);_=k.lane_frame(&pair.client.lane,0)
 expect_saved(t,&pair.client,&before)
 testing.expect_value(t,k.lane_world_confirmed(&pair.client.lane),u64(6))
 owned:=k.lane_world_owned_bytes(&pair.client.lane)
 wp.deliver(&pair.client,pair.host.peer,first)
 testing.expect(t,k.lane_world_owned_bytes(&pair.client.lane)<=owned+u64(k.WORLD_NETWORK_BYTES))
 rejected:=k.lane_world_network_status(&pair.client.lane).rejected
 bad:=wp.clone_packet(first);bad.bytes[len(bad.bytes)-1]~=1
 wp.deliver(&pair.client,pair.host.peer,bad);delete(bad.bytes);_=k.lane_frame(&pair.client.lane,0)
 testing.expect(t,k.lane_world_network_status(&pair.client.lane).rejected>rejected)
 expect_saved(t,&pair.client,&before)
 testing.expect_value(t,pair.client.effects,fx)
 testing.expect_value(t,k.lane_world_protocol_status(&pair.client.lane).bootstrap_sequence,old_scope)
 // Record genuine future authority traffic/oracles BEFORE source destruction.
 // Post-adoption controls below are these real accepted Host controls, not
 // invented admissions by a destroyed Host or a manufactured ACK.
 pair.host.axis=2
 if !advance_authority(t,&pair.host,24){return}
 future:=wp.take_packets(&pair.host);defer wp.destroy_packets(&future)
 expected:k.World_Diagnostic_Frame
 if !save_frame(t,&pair.host,24,&expected){return};defer k.world_diagnostic_frame_destroy(&expected)
 expect_control(t,&pair.host,24,pair.host.ses.me,2)
 f.destroy(&pair.host);host_alive=false
 testing.expect_value(t,b.recovery_catalog_destroy(&pair.catalog),b.Status.Ok);cat_alive=false
 wp.deliver_all(&pair.client,s.HOST_PEER,response[:]);_=k.lane_frame(&pair.client.lane,0)
 testing.expect(t,k.lane_world_network_status(&pair.client.lane).ready&&!k.lane_world_needs_resync(&pair.client.lane))
 testing.expect_value(t,k.lane_now(&pair.client.lane),u64(18))
 testing.expect_value(t,k.lane_world_confirmed(&pair.client.lane),u64(18))
 testing.expect(t,k.lane_world_protocol_status(&pair.client.lane).bootstrap_sequence>old_scope)
 testing.expect_value(t,pair.client.effects,fx) // no historical effect replay
 wp.deliver_all(&pair.client,s.HOST_PEER,future[:])
 for _ in 0..<4{_=k.lane_frame(&pair.client.lane,0);if k.lane_world_confirmed(&pair.client.lane)==24{break}}
 testing.expect_value(t,k.lane_world_confirmed(&pair.client.lane),u64(24))
 expect_saved(t,&pair.client,&expected)
 expect_control(t,&pair.client,24,1,2)
 testing.expect_value(t,pair.client.effects-fx,1) // newly eligible tick20 only
 wp.deliver_all(&pair.client,s.HOST_PEER,stale[:])
 wp.deliver_all(&pair.client,s.HOST_PEER,response[:])
 wp.deliver_all(&pair.client,s.HOST_PEER,future[:]);_=k.lane_frame(&pair.client.lane,0)
 testing.expect_value(t,k.lane_world_confirmed(&pair.client.lane),u64(24))
 testing.expect_value(t,pair.client.effects-fx,1)
 expect_saved(t,&pair.client,&expected)
}
