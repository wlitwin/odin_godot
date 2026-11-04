// Copies detached debug lines into an owning JSON payload. No Godot/Native API.
package box3d_godot_debugdraw

import "core:encoding/json"
import "core:math"
import "core:mem"
import d "godot:box3d/debugdraw"

MAX_JSON_BYTES :: 2*1024*1024
Error :: enum {None,Invalid,Capacity,Allocation,Encoding}
@(private)
Wire_Frame :: struct {version:u32,epoch_hex,tick_hex,revision_hex,source:string,points:[]d.Vec3,colors:[]d.Color}
@(private)
hex16 :: proc(value:u64)->[16]u8{
 digits:="0123456789abcdef";out:[16]u8
 for i in 0..<16{out[15-i]=digits[(value>>uint(4*i))&15]}
 return out
}
@(private)
finite :: proc(value:f32)->bool{return !math.is_nan(value)&&!math.is_inf(value)}

// Caller deletes the returned bytes with the same allocator. Wide stamp values
// are exactly16 hex digits; Godot never roundtrips them through JSON floats.
frame_json :: proc(batch:d.Batch,lines:[]d.Line,allocator:mem.Allocator=context.allocator)->([]u8,Error){
 if batch.stamp.epoch==0||batch.stamp.source>.Observed||batch.count>d.MAX_LINES||batch.count>u32(len(lines))||batch.required!=batch.count{return nil,.Invalid}
 for line in lines[:batch.count]{
  for v in line.a{if !finite(v){return nil,.Invalid}}
  for v in line.b{if !finite(v){return nil,.Invalid}}
  for v in line.color{if !finite(v)||v<0||v>1{return nil,.Invalid}}
 }
 points,pe:=make([]d.Vec3,int(batch.count)*2,allocator);if pe!=nil{return nil,.Allocation};defer delete(points,allocator)
 colors,ce:=make([]d.Color,int(batch.count),allocator);if ce!=nil{return nil,.Allocation};defer delete(colors,allocator)
 for line,index in lines[:batch.count]{points[index*2]=line.a;points[index*2+1]=line.b;colors[index]=line.color}
 epoch,tick,revision:=hex16(batch.stamp.epoch),hex16(batch.stamp.tick),hex16(batch.stamp.revision)
 source:="Predicted"
 switch batch.stamp.source{case .Predicted:case .Confirmed:source="Confirmed";case .Observed:source="Observed"}
 bytes,error:=json.marshal(Wire_Frame{d.VERSION,string(epoch[:]),string(tick[:]),string(revision[:]),source,points,colors},allocator=allocator)
 if error!=nil{delete(bytes,allocator);return nil,.Encoding}
 if len(bytes)>MAX_JSON_BYTES{delete(bytes,allocator);return nil,.Capacity}
 return bytes,.None
}
