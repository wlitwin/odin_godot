package kit_chunk_batch_test

import "core:fmt"
import "core:mem"
import "core:testing"
import b "godot:box3d"
import k "godot:kit/sim"
import p "godot:kit/physics"
import s "godot:kit/session"
import n "godot:kit/net"
import f "godot:tests/kit_box3d_net"

open_pair :: proc(t:^testing.T,host,client:^f.Box,cat:^b.Recovery_Catalog,count:=3) {
 f.start_pair(host,client);cat^=f.catalog();f.setup(host,count,cat);f.setup(client,count,cat);f.bootstrap(t,host,client)
}
close_pair :: proc(t:^testing.T,host,client:^f.Box,cat:^b.Recovery_Catalog) {
 f.destroy(client);f.destroy(host);b.recovery_catalog_destroy(cat)
 a,_:=b.engine_allocation_stats();z,_:=b.snapshot_allocation_stats()
 testing.expect(t,a.live_bytes==0 && z.live_bytes==0 && p.owned_bytes()==0 && k.world_checkpoint_owned_bytes()==0 && k.world_diagnostic_frame_owned_bytes()==0)
}
take :: proc(host,client:^f.Box)->[dynamic]f.Parcel {
 result:[dynamic]f.Parcel
 for parcel in host.out {
  if parcel.channel==.Reliable && len(parcel.bytes)>2 && parcel.bytes[2]==k.SIM_WORLD_CHUNK {append(&result,parcel)}else{deliver(client,parcel);delete(parcel.bytes)}
 }
 clear(&host.out);return result
}
release :: proc(packets:^[dynamic]f.Parcel) {for packet in packets^ {delete(packet.bytes)};delete(packets^);packets^=nil}
capture :: proc(t:^testing.T,host,client:^f.Box)->[dynamic]f.Parcel {
 testing.expect_value(t,k.lane_world_send_checkpoint(&host.lane,client.peer,.Correction),k.World_Error.Ok)
 return take(host,client)
}
payload :: proc(net:^k.World_Network)->int {
 bytes:=len(net.transfer)+len(net.applying_transfer.bytes);for entry in net.completed {bytes+=len(entry.bytes)};return bytes
}
expect_current_same :: proc(t:^testing.T,client:^f.Box,before:^k.World_Checkpoint) {
 after,e:=k.lane_world_checkpoint(&client.lane,client.lane.ticker.tick);testing.expect_value(t,e,k.World_Error.Ok)
 same,se:=k.world_checkpoint_equal(before,&after);testing.expect_value(t,se,k.World_Error.Ok);testing.expect(t,same);k.world_checkpoint_destroy(&after)
}
recover :: proc(t:^testing.T,host,client:^f.Box) {
 testing.expect_value(t,k.lane_world_request_reset(&client.lane),k.World_Error.Ok)
 for packet in client.out {r:=n.reader_make(packet.bytes);s.session_handle_packet(&host.ses,client.peer,&r,packet.channel);delete(packet.bytes)};clear(&client.out)
 _=k.lane_frame(&host.lane,0);f.pump({host,client});_=k.lane_frame(&client.lane,0)
 testing.expect(t,k.lane_world_network_status(&client.lane).ready && !k.lane_world_needs_resync(&client.lane))
}

@(private) spy_lane:^k.Lane
@(private) spy_decode:proc(rawptr,[]u8,[]u8,[]u8)->(rawptr,k.World_Error)
@(private) spy_expected:u64
@(private) spy_calls:int
selected_decode :: proc(user:rawptr,solver,side,observations:[]u8)->(rawptr,k.World_Error) {
 net:=spy_lane.world.network
 assert(net.applying && len(net.applying_transfer.bytes)>0)
 assert(k.lane_world_network_status(spy_lane).owned_bytes>=spy_expected)
 count:=net.completed_count;selected:=raw_data(net.applying_transfer.bytes)
 assert(k.lane_world_network_detach(spy_lane)==.Busy)
 assert(k.lane_world_request_reset(spy_lane)==.Busy)
 assert(net.completed_count==count && raw_data(net.applying_transfer.bytes)==selected)
 spy_calls+=1;return spy_decode(user,solver,side,observations)
}

@(test)
fifo_three_frames_one_per_ingest_selected_charged_and_protected :: proc(t:^testing.T) {
 host,client:f.Box;cat:b.Recovery_Catalog;open_pair(t,&host,&client,&cat)
 packets:=capture(t,&host,&client)
 for _ in 0..<2 {
  _=k.lane_frame(&client.lane,1.0/60);for packet in client.out {delete(packet.bytes)};clear(&client.out)
  _=k.lane_frame(&host.lane,1.0/60)
  more:=capture(t,&host,&client);for packet in more {append(&packets,packet)};delete(more)
 }
 before,e:=k.lane_world_checkpoint(&client.lane,2);testing.expect_value(t,e,k.World_Error.Ok)
 fields,fx:=client.proxies,client.effects
 for packet in packets {deliver(&client,packet)}
 testing.expect_value(t,client.lane.world.network.completed_count,3)
 expect_current_same(t,&client,&before);testing.expect_value(t,client.proxies,fields);testing.expect_value(t,client.effects,fx)
 k.world_checkpoint_destroy(&before)
 spy_lane=&client.lane;spy_decode=client.lane.world.network.config.codec.decode;spy_calls=0
 client.lane.world.network.config.codec.decode=selected_decode
 for tick in 0..<3 {
  spy_expected=k.lane_world_network_status(&client.lane).owned_bytes
  _=k.lane_frame(&client.lane,0)
  testing.expect_value(t,k.lane_world_confirmed(&client.lane),u64(tick));testing.expect_value(t,client.lane.world.network.completed_count,2-tick)
  testing.expect_value(t,len(client.lane.world.network.applying_transfer.bytes),0);expect_pair(t,&host,&client,u64(tick))
 }
 testing.expect_value(t,spy_calls,3);client.lane.world.network.config.codec.decode=spy_decode;spy_lane=nil;spy_decode=nil
 release(&packets);close_pair(t,&host,&client,&cat)
}

@(test)
queued_duplicate_conflict_and_pending_reset_are_owned :: proc(t:^testing.T) {
 host,client:f.Box;cat:b.Recovery_Catalog;open_pair(t,&host,&client,&cat)
 packets:=capture(t,&host,&client);for packet in packets {deliver(&client,packet)}
 net:=client.lane.world.network;owned:=k.lane_world_network_status(&client.lane).owned_bytes;duplicates:=net.duplicates
 for packet in packets {deliver(&client,packet)}
 testing.expect_value(t,net.completed_count,1);testing.expect_value(t,k.lane_world_network_status(&client.lane).owned_bytes,owned);testing.expect(t,net.duplicates>duplicates)
 before,e:=k.lane_world_checkpoint(&client.lane,0);testing.expect_value(t,e,k.World_Error.Ok)
 changed:=make([]u8,len(packets[0].bytes));copy(changed,packets[0].bytes);changed[24]~=1
 deliver(&client,{bytes=changed,channel=.Reliable});testing.expect_value(t,net.status,k.World_Error.Conflict);testing.expect(t,!k.lane_world_needs_resync(&client.lane))
 copy(changed,packets[0].bytes);changed[72]~=1
 deliver(&client,{bytes=changed,channel=.Reliable});delete(changed)
 testing.expect(t,k.lane_world_needs_resync(&client.lane));_=k.lane_frame(&client.lane,0);expect_current_same(t,&client,&before)
 testing.expect_value(t,net.completed_count,1);k.world_checkpoint_destroy(&before)
 testing.expect_value(t,k.lane_world_request_reset(&client.lane),k.World_Error.Ok);testing.expect_value(t,payload(net),0)
 for packet in client.out {r:=n.reader_make(packet.bytes);s.session_handle_packet(&host.ses,client.peer,&r,packet.channel);delete(packet.bytes)};clear(&client.out)
 _=k.lane_frame(&host.lane,0);reset:=take(&host,&client);for packet in reset {deliver(&client,packet)}
 reset_owned:=payload(net);for packet in packets {deliver(&client,packet)}
 testing.expect_value(t,payload(net),reset_owned);testing.expect_value(t,net.completed_count,1)
 _=k.lane_frame(&client.lane,0);testing.expect(t,net.ready && !k.lane_world_needs_resync(&client.lane));expect_pair(t,&host,&client,0)
 release(&reset);release(&packets);close_pair(t,&host,&client,&cat)
}

@(test)
fifo_eight_capacity_failure_preserves_publication_and_reset_cleans :: proc(t:^testing.T) {
 host,client:f.Box;cat:b.Recovery_Catalog;open_pair(t,&host,&client,&cat)
 before,e:=k.lane_world_checkpoint(&client.lane,0);testing.expect_value(t,e,k.World_Error.Ok)
 for _ in 0..<k.WORLD_NETWORK_TRANSFERS {packets:=capture(t,&host,&client);for packet in packets {deliver(&client,packet)};release(&packets)}
 net:=client.lane.world.network;testing.expect_value(t,net.completed_count,8);queued_bytes:=payload(net)
 testing.expect(t,queued_bytes<=k.WORLD_NETWORK_BYTES)
 more:=capture(t,&host,&client);deliver(&client,more[0]);release(&more)
 testing.expect_value(t,net.status,k.World_Error.Capacity);testing.expect(t,k.lane_world_needs_resync(&client.lane));testing.expect_value(t,payload(net),queued_bytes)
 _=k.lane_frame(&client.lane,0);expect_current_same(t,&client,&before);k.world_checkpoint_destroy(&before)
 recover(t,&host,&client);testing.expect_value(t,payload(net),0)
 close_pair(t,&host,&client,&cat)
}

// Bounds-only incomplete transfer: copies a real header, changes seq/total/count
// and sends ONLY chunk0. No fabricated image ever reaches hash/decode/Native.
sized_first :: proc(source:f.Parcel,total:int)->f.Parcel {
 bytes:=make([]u8,72+min(total,k.WORLD_NETWORK_CHUNK));copy(bytes[:72],source.bytes[:72]);bytes[8]~=0x80
 for i in 0..<4 {bytes[32+i]=u8(u32(total)>>uint(i*8))}
 count:=u16((total+k.WORLD_NETWORK_CHUNK-1)/k.WORLD_NETWORK_CHUNK);bytes[38]=u8(count);bytes[39]=u8(count>>8)
 return {bytes=bytes,channel=.Reliable}
}
@(test)
combined_payload_exact_one_mib_and_plus_one_reject :: proc(t:^testing.T) {
 host,client:f.Box;cat:b.Recovery_Catalog;open_pair(t,&host,&client,&cat)
 for pass in 0..<2 {
  packets:[dynamic]f.Parcel
  for _ in 0..<7 {more:=capture(t,&host,&client);for packet in more {deliver(&client,packet)};if len(packets)==0 {packets=more}else{release(&more)}}
  net:=client.lane.world.network;used:=payload(net);room:=k.WORLD_NETWORK_BYTES-used;assert(room>k.WORLD_NETWORK_CHUNK)
  packet:=sized_first(packets[0],room+(pass==0?1:0));deliver(&client,packet);delete(packet.bytes)
  if pass==0 {testing.expect_value(t,net.status,k.World_Error.Capacity);testing.expect_value(t,payload(net),used);testing.expect(t,k.lane_world_needs_resync(&client.lane))
  }else{testing.expect_value(t,payload(net),k.WORLD_NETWORK_BYTES);testing.expect(t,!k.lane_world_needs_resync(&client.lane));testing.expect_value(t,net.transfer_received,1)}
  fmt.printf("KIT_FIFO_BYTE_BOUND pass=%d used=%d remaining=%d actual=%d status=%v\n",pass,used,room,payload(net),net.status)
  release(&packets);recover(t,&host,&client);testing.expect_value(t,payload(net),0)
 }
 close_pair(t,&host,&client,&cat)
}

@(test)
assembly_allocation_failure_keeps_queued_owner_and_publication :: proc(t:^testing.T) {
 gate:=f.Diagnostic_Allocation_Gate{base=context.allocator,remaining=-1}
 context.allocator=f.diagnostic_allocator(&gate)
 host,client:f.Box;cat:b.Recovery_Catalog;open_pair(t,&host,&client,&cat)
 first:=capture(t,&host,&client);for packet in first {deliver(&client,packet)}
 net:=client.lane.world.network;queued:=payload(net);before,e:=k.lane_world_checkpoint(&client.lane,0);testing.expect_value(t,e,k.World_Error.Ok)
 second:=capture(t,&host,&client)
 gate.remaining=0;deliver(&client,second[0]);gate.remaining=-1
 testing.expect_value(t,net.status,k.World_Error.Allocation_Failed);testing.expect_value(t,payload(net),queued);testing.expect_value(t,net.completed_count,1)
 testing.expect(t,k.lane_world_needs_resync(&client.lane));_=k.lane_frame(&client.lane,0);expect_current_same(t,&client,&before)
 k.world_checkpoint_destroy(&before);release(&first);release(&second);close_pair(t,&host,&client,&cat)
}

@(test)
held_receive_validates_inputs_without_replaying_then_allows_future_epoch_reset :: proc(t:^testing.T) {
 host,client:f.Box;cat:b.Recovery_Catalog;open_pair(t,&host,&client,&cat)
 _=k.lane_frame(&client.lane,1.0/60);for packet in client.out {delete(packet.bytes)};clear(&client.out)
 host.axis=2;_=k.lane_frame(&host.lane,1.0/60)
 accepted:=host.out;host.out=nil // real authority input changes the guessed velocity
 for _ in 0..<8 {packets:=capture(t,&host,&client);for packet in packets {deliver(&client,packet)};release(&packets)}
 excess:=capture(t,&host,&client);deliver(&client,excess[0]);release(&excess)
 testing.expect(t,k.lane_world_needs_resync(&client.lane))
 before,e:=k.lane_world_checkpoint(&client.lane,1);testing.expect_value(t,e,k.World_Error.Ok)
 for packet in accepted {deliver(&client,packet)};release(&accepted)
 _=k.lane_frame(&client.lane,0)
 expect_current_same(t,&client,&before);k.world_checkpoint_destroy(&before)
 testing.expect(t,!client.lane.world.network.accepted[1].valid)
 testing.expect_value(t,client.lane.world.network.completed_count,8)
 // An authenticated complete newer-epoch Reset still uses the full existing
 // import/validation path; a held ordinary queue must not block that recovery.
 testing.expect_value(t,k.lane_world_begin_epoch(&host.lane,2),k.World_Error.Ok)
 testing.expect_value(t,k.lane_world_send_checkpoint(&host.lane,client.peer,.Reset),k.World_Error.Ok)
 reset:=take(&host,&client);for packet in reset {deliver(&client,packet)};release(&reset)
 testing.expect_value(t,client.lane.world.network.completed_count,1)
 _=k.lane_frame(&client.lane,0)
 testing.expect_value(t,k.lane_world_epoch(&client.lane),u64(2));testing.expect(t,!k.lane_world_needs_resync(&client.lane))
 expect_pair(t,&host,&client,1);close_pair(t,&host,&client,&cat)
}
