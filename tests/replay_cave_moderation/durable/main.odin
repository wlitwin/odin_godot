package main
import "core:fmt"
import "core:os"
import "core:time"
import auth "godot:replay/authority"
import sql "godot:replay/authority/sqlite"
import p "godot:replay/provision"
import db "godot:replay/provision/sqlite"
import sc "godot:replay/schema"
ADMIN :: p.Secret{0=41}
INVITE :: p.Secret{0=42}
CLAIM :: p.Secret{0=43}
Owner :: struct {store:db.Store,boundary:string}
clock :: proc(_:rawptr)->(u64,bool) {return 0,true}
address :: proc(port:u16)->auth.Endpoint {e,_:=auth.endpoint("127.0.0.1",port);return e}
commit :: proc(raw:rawptr,expected:u64,next:p.Bundle)->bool {
 o:=cast(^Owner)raw
 if o.boundary=="before" {
  s:=&o.store
  assert(sql.sqlite3_exec(s.connection.db,"BEGIN IMMEDIATE;",nil,nil,nil)==0)
  assert(sc.pack(&s.codec,next,{kind=0x5052,epoch=1,tick=next.record.revision,content=55},s.buffer).error==.None)
  statement:sql.Statement
  assert(sql.sqlite3_prepare_v2(s.connection.db,"UPDATE replay_provision SET value=?1;",-1,&statement,nil)==0)
  assert(sql.sqlite3_bind_blob(statement,1,raw_data(s.buffer),i32(len(s.buffer)),nil)==0)
  assert(sql.sqlite3_step(statement)==101);sql.sqlite3_finalize(statement)
  fmt.println("MODERATION_DURABLE_BEFORE")
  for {time.sleep(100*time.Millisecond)}
 }
 ok:=db.commit(&o.store,expected,next)
 if ok && o.boundary=="after" {
  fmt.println("MODERATION_DURABLE_AFTER")
  for {time.sleep(100*time.Millisecond)}
 }
 return ok
}
main :: proc() {
 assert(len(os.args)==3);mode,path:=os.args[1],os.args[2]
 owner:Owner;room:p.Room;assert(db.open(&owner.store,path,mode=="before" || mode=="after")==.None)
 defer db.close(&owner.store);defer p.close(&room)
 if mode=="before" || mode=="after" {
  bundle,error:=p.make_room(44,55,ADMIN,address(45001));assert(error==.None)
  assert(p.open(&room,bundle,commit,&owner,{read=clock})==.None)
  ticket,e:=p.invite(&room,ADMIN,INVITE,.Trusted_Peer);assert(e==.None)
  guest,e2:=p.join(&room,ticket,CLAIM,address(45002));assert(e2==.None)
  creator,e3:=p.creator_grant(&room,ADMIN);assert(e3==.None)
  assert(auth.coordinator_start(&room.service.coordinator,creator.identity,1,0)==.None)
  assert(auth.coordinator_nominate(&room.service.coordinator,creator.identity,1,guest.identity,9,0)==.None)
  point:=auth.Point{{44,1,9,55},{sequence=1,tick=0,bytes=512,hash={0=17}}}
  assert(auth.coordinator_prepare(&room.service.coordinator,guest.identity,point,0)==.None)
  lease:auth.Lease;assert(auth.lease_init(&lease,creator.identity,44,55,{read=clock},true)==.None)
  rpc:auth.Rpc_Client;assert(auth.rpc_client_init(&rpc,&lease,creator.key,{0=11},{}));defer auth.rpc_client_destroy(&rpc)
  // Sequence one is independently unconsumed in the service request frontier.
  assert(auth.rpc_remove(&rpc,1,guest.identity)==.None)
  owner.boundary=mode
  auth.service_receive(&room.service,2,rpc.txb[:rpc.count]);assert(false,"expected process kill");return
 }
 bundle,found,error:=db.load(&owner.store,44,55);assert(found && error==.None)
 removed:=mode=="verify-after"
 assert(bundle.record.members[1].enabled==!removed)
 assert(bundle.record.prepared==!removed)
 assert((bundle.record.requests[0].sequence==1)==removed)
 if removed {assert(bundle.record.requests[0].result==.None && bundle.record.nominee==(auth.Identity{}))}
 assert(p.open(&room,bundle,commit,&owner,{read=clock})==.None)
 _,join:=p.join(&room,{44,INVITE},CLAIM,address(45002));assert(join==(removed ? p.Error.Denied : p.Error.None))
 fmt.printf("REPLAY_MODERATION_DURABLE_OK mode=%s removed=%v frontier=%d\n",mode,removed,bundle.record.requests[0].sequence)
}
