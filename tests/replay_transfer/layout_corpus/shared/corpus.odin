package layout_corpus
import "core:mem"
import sc "godot:replay/schema"
import tf "godot:replay/transfer"
import tr "godot:replay/transport"
Row :: struct {x:u32,spare:u64,health:u8}
Rows :: struct {rows:[256]Row}
Fixture :: struct {memory:tr.Memory,ends:[2]tr.Memory_Endpoint,sender:tf.Sender,receiver:tf.Blob_Receiver,schema:sc.Schema,expected:[]u8,installed:u32}
verify :: proc()->(code:u32,hash:u64) {
 hash=0xcbf29ce484222325
 for mode in 0..<4 {
  f:=new(Fixture);defer free(f)
  if sc.init(&f.schema,Rows).error!=.None {return 1,0};defer sc.destroy(&f.schema)
  data:Rows;for &row,i in data.rows {row.x=u32(i)*0x123457;row.health=u8(i%5)}
  body:=make([]u8,f.schema.wire_size);defer delete(body)
  if report:=sc.encode(&f.schema,data,body);report.error!=.None {return 100+u32(report.error),u64(f.schema.wire_size)}
  f.expected=make([]u8,sc.HEADER_BYTES+len(body));defer delete(f.expected)
  if sc.pack_bytes(f.schema.fingerprint,{kind=777,epoch=2,tick=12,content=4},body,f.expected).error!=.None {return 3,0}
  if !tr.memory_init(&f.memory,717,{2,256,1200,65536},{latency_ticks=30,jitter_ticks=20,loss_permyriad=1000,duplicate_permyriad=1000,retry_ticks=3}) {return 4,0};defer tr.memory_destroy(&f.memory)
  for &end,i in f.ends {if !tr.memory_open(&f.memory,&end,tr.Peer_Id(i+1)) {return 5,0}}
  a,b:=tr.memory_transport(&f.ends[0]),tr.memory_transport(&f.ends[1])
  if tf.sender_init(&f.sender,{7,2,3,4},2,a,archive_kind=777,max_bytes=4096)!=.None {return 6,0};defer tf.sender_destroy(&f.sender)
  if tf.blob_init(&f.receiver,{7,2,3,4},1,b,777,proc(user:rawptr,archive:tf.Archive,bytes:[]u8)->bool {
   f:=cast(^Fixture)user;if mem.compare(f.expected,bytes)!=0 {return false};f.installed+=1;return true
  },f,max_bytes=4096)!=.None {return 7,0};defer tf.blob_destroy(&f.receiver)
  f.sender.compress,f.sender.shuffle=true,mode!=1
  f.sender.layout={&f.schema,sc.HEADER_BYTES};f.receiver.layout=f.sender.layout
  if mode==2 {f.receiver.layout={}}
  if tf.sender_begin(&f.sender,f.expected,0,mode==3 ? tr.Channel.Reliable : tr.Channel.Unreliable)!=.None {return 8,0}
  if (f.sender.wire_layout!=0)!=(mode!=1) {return 9,0}
  hash=sc.digest(f.sender.wire_bytes,hash~f.sender.wire_layout)
  packet:[1200]u8
  for now:=u64(10);now<10000;now+=10 {
   tr.memory_advance(&f.memory,now)
   for {p:=tr.receive(&a,packet[:]);if p.state!=.Received {break};tf.sender_receive(&f.sender,p.from,packet[:p.count],now)}
   for {p:=tr.receive(&b,packet[:]);if p.state!=.Received {break};tf.blob_receive(&f.receiver,p.from,packet[:p.count],now,p.channel)}
   tf.sender_update(&f.sender,now);tf.blob_update(&f.receiver,now)
   if f.sender.phase==.Complete {break}
  }
  if mode==3 && !f.receiver.reliable_replies {return 12,0}
  if mode==2 {
   if f.installed!=0 || f.receiver.stats.rejected==0 || f.receiver.active {return 10,0}
  } else if f.sender.phase!=.Complete || f.installed!=1 || f.receiver.latest.archive!=f.sender.archive {return 11,0}
 }
 return
}
