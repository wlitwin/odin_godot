package replay_transfer_test

import "core:testing"
import rec "godot:replay/recovery"
import tf "godot:replay/transfer"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

Capture :: struct {bytes: [1200]u8, count: int}
capture_wire :: proc(c: ^Capture) -> tr.Transport {
 return {user=c, connected=proc(user:rawptr,peer:tr.Peer_Id)->bool{return true},
 send=proc(user:rawptr,to:tr.Peer_Id,channel:tr.Channel,bytes:[]u8)->tr.Send_Result {
  c := cast(^Capture)user; c.count=len(bytes); copy(c.bytes[:],bytes); return .Sent
 }}
}

@(test)
recovery_offer_wire_bytes_match_the_pre_extraction_fixture :: proc(t: ^testing.T) {
 codec: sc.Schema; sc.init(&codec,u64); defer sc.destroy(&codec)
 bytes: [128]u8; sc.pack(&codec,u64(9),{kind=777,epoch=2,tick=42,content=4},bytes[:])
 c: Capture; s: rec.Sender; defer rec.sender_destroy(&s)
 testing.expect_value(t, rec.sender_init(&s,{1,2,3,4},2,capture_wire(&c),archive_kind=777), rec.Error.None)
 testing.expect_value(t, rec.sender_begin(&s,bytes[:sc.HEADER_BYTES+codec.wire_size],0), rec.Error.None)
 testing.expect_value(t, rec.sender_update(&s,0), rec.Error.None)
 testing.expect_value(t,c.count,164)
 expected := [32]u8{28,218,243,152,242,29,117,114,90,146,37,203,52,78,2,186,216,236,221,46,53,199,17,218,153,14,172,23,15,217,199,190}
 testing.expect_value(t,tf.hash(c.bytes[:c.count]),expected)
 testing.expect(t, rec.handles(c.bytes[:c.count]) && !tf.handles(c.bytes[:c.count]))
}
