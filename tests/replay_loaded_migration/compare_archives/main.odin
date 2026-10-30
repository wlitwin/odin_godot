package main
import "core:fmt"
import "core:os"
import "core:mem"
import "core:strconv"
import net "godot:replay/net"
import sc "godot:replay/schema"
import rec "godot:replay/recovery"
import cmp "godot:replay/compress"
import game "sample:game"

// Offline diagnostic. Args: wire-file raw-size layout-id output-raw, repeated.
main :: proc(){
 assert((len(os.args)-1)%4==0 && len(os.args)>=5)
 codec:net.Checkpoint_Codec;assert(net.checkpoint_codec_init(&codec,game.World,game.Control,game.Action,game.Event,game.SEATS)==.None);defer net.checkpoint_codec_destroy(&codec)
 schema,offset,ready:=net.checkpoint_frame_layout(&codec);assert(ready)
 work:=new(cmp.Workspace);defer free(work)
 base:[]u8;defer delete(base)
 for arg:=1;arg<len(os.args);arg+=4 {
  wire,read:=os.read_entire_file(os.args[arg],context.allocator);assert(read==nil);defer delete(wire)
  size,valid:=strconv.parse_int(os.args[arg+1]);assert(valid&&size>0&&size<=cmp.MAX_BYTES)
  layout,parsed:=strconv.parse_uint(os.args[arg+2]);assert(parsed)
  raw:=make([]u8,size);scratch:=make([]u8,size);defer delete(scratch)
  assert(cmp.decode(wire,raw,scratch))
  if layout!=0 {
   assert(offset+schema.wire_size<=len(raw))
   assert(sc.unshuffle(schema,raw[offset:offset+schema.wire_size],scratch[:schema.wire_size]))
   copy(raw[offset:offset+schema.wire_size],scratch[:schema.wire_size])
  }
  cp:=new(net.Checkpoint(game.World,game.Control,game.Action,game.SEATS));defer free(cp);defer net.checkpoint_destroy(cp)
  assert(net.checkpoint_decode(cp,raw,game.model(),game.CONTENT)==.None)
  sender:rec.Sender;assert(rec.sender_init(&sender,{48,cp.header.epoch,3,game.CONTENT},2,{})==.None);defer rec.sender_destroy(&sender)
  sender.compress,sender.shuffle=true,layout!=0
  assert(rec.sender_publish(&sender,cp,game.model(),0,&codec)==.None)
  assert(mem.compare(sender.bytes,raw)==0 && sender.wire_layout==u64(layout) && mem.compare(sender.wire_bytes,wire)==0)
  assert(os.write_entire_file(os.args[arg+3],raw)==nil)
  fmt.printf("CHECKPOINT_ARRAY_REGIONS tick=%d regions=%v\n",cp.header.tick,schema.arrays)
  copy(scratch,raw);assert(sc.shuffle(schema,raw[offset:offset+schema.wire_size],scratch[offset:offset+schema.wire_size]))
  assert(os.write_entire_file(fmt.tprintf("%s.grouped",os.args[arg+3]),scratch)==nil)
  for mode in 0..<4 {
   transformed:=make([]u8,size);encoded:=make([]u8,size+128);decoded:=make([]u8,size);defer delete(transformed);defer delete(encoded);defer delete(decoded)
   copy(transformed,raw)
   for region in schema.arrays {
    start:=offset+region.offset
    for lane in 0..<region.stride {
     previous,older:=u8(0),u8(0)
     for row in 0..<region.count {
      value:=raw[start+row*region.stride+lane]
      transformed[start+lane*region.count+row]=mode==0 ? value-previous : mode==1 ? value~previous : mode==3 && region.stride<256 ? value : value-previous-previous+older
      older,previous=previous,value
     }
    }
   }
   if mode==0 {assert(os.write_entire_file(fmt.tprintf("%s.predicted",os.args[arg+3]),transformed)==nil)}
   count,valid:=cmp.encode(transformed,encoded,work);assert(valid && cmp.decode(encoded[:count],decoded,scratch))
   copy(scratch,decoded)
   for region in schema.arrays {
    start:=offset+region.offset
    for lane in 0..<region.stride {
     previous,older:=u8(0),u8(0)
     for row in 0..<region.count {
      value:=decoded[start+lane*region.count+row]
      restored:=mode==0 ? previous+value : mode==1 ? previous~value : mode==3 && region.stride<256 ? value : value+previous+previous-older
      older,previous=previous,restored
      scratch[start+row*region.stride+lane]=restored
     }
    }
   }
   assert(mem.compare(scratch,raw)==0)
   fmt.printf("CHECKPOINT_ARRAY_PREDICTOR tick=%d mode=%d full_wire=%d predicted_wire=%d exact=true\n",cp.header.tick,mode,len(wire),count)
  }
  if len(base)>0 {
   xor:=make([]u8,size);grouped:=make([]u8,size);encoded:=make([]u8,size+128);defer delete(xor);defer delete(grouped);defer delete(encoded)
   for &byte,i in xor {byte=raw[i]~(i<len(base)?base[i]:u8(0))}
   copy(grouped,xor);assert(sc.shuffle(schema,xor[offset:offset+schema.wire_size],grouped[offset:offset+schema.wire_size]))
   count,ok:=cmp.encode(grouped,encoded,work);assert(ok)
   decoded:=make([]u8,size);defer delete(decoded)
   assert(cmp.decode(encoded[:count],decoded,scratch))
   assert(sc.unshuffle(schema,decoded[offset:offset+schema.wire_size],scratch[:schema.wire_size]));copy(decoded[offset:offset+schema.wire_size],scratch[:schema.wire_size])
   for &byte,i in decoded {byte~=i<len(base)?base[i]:u8(0)}
   assert(mem.compare(decoded,raw)==0)
   fmt.printf("CHECKPOINT_DELTA_DIAGNOSTIC tick=%d base_raw=%d raw=%d full_wire=%d delta_wire=%d exact=true\n",cp.header.tick,len(base),len(raw),len(wire),count)
  }else {fmt.printf("CHECKPOINT_CAPTURE_VERIFIED tick=%d raw=%d wire=%d layout=%d\n",cp.header.tick,len(raw),len(wire),layout)}
  delete(base);base=raw
 }
}
