package replay_assets_test
import "core:testing"
import "core:hash"
import a "godot:replay/assets"
header :: proc(width,height:u32) -> [33]u8 {
 bytes:[33]u8;prefix:=[16]u8{137,80,78,71,13,10,26,10,0,0,0,13,'I','H','D','R'};copy(bytes[:],prefix[:])
 for i in 0..<4 {bytes[16+i]=u8(width>>uint((3-i)*8));bytes[20+i]=u8(height>>uint((3-i)*8))}
 bytes[24],bytes[25]=8,6
 checksum:=hash.crc32(bytes[12:29]);for i in 0..<4 {bytes[29+i]=u8(checksum>>uint((3-i)*8))}
 return bytes
}
@(test)
image_dimensions_and_crc_are_checked_before_decoding :: proc(t:^testing.T) {
 bytes:=header(64,64);info,ok:=a.png_info(bytes[:]);testing.expect(t,ok);testing.expect_value(t,info,a.PNG_Info{64,64})
 bytes[16]~=1;_,ok=a.png_info(bytes[:]);testing.expect(t,!ok)
 bytes=header(2048,2048);_,ok=a.png_info(bytes[:]);testing.expect(t,!ok)
 bytes=header(4096,1);_,ok=a.png_info(bytes[:]);testing.expect(t,!ok)
 bytes=header(0,1);_,ok=a.png_info(bytes[:]);testing.expect(t,!ok)
 bytes=header(64,64);_,ok=a.png_info(bytes[:20]);testing.expect(t,!ok)
}
