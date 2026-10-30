package main
import "core:crypto"
import "core:fmt"
import "core:os"
import "core:time"
import auth "godot:replay/authority"
import sql "godot:replay/authority/sqlite"
import p "godot:replay/provision"
import pp "godot:replay/p2p/provision"
import db "godot:replay/p2p/provision/sqlite"
import sc "godot:replay/schema"

ADMIN :: p.Secret{0=41}
INVITE :: p.Secret{0=42}
CLAIM :: p.Secret{0=43}
Owner :: struct {store:db.Store, phase:string}
clock :: proc(_:rawptr)->(u64,bool) {return 0,true}
entropy :: proc(_:rawptr,dst:[]u8)->bool {crypto.rand_bytes(dst);return true}
address :: proc()->auth.Endpoint {e,_:=auth.endpoint("127.0.0.1",45001);return e}
commit :: proc(user:rawptr,expected:u64,next:pp.Bundle)->bool {
    o:=cast(^Owner)user
    if o.phase == "" {return db.commit(&o.store,expected,next)}
    if o.phase == "committed" {
        assert(db.commit(&o.store,expected,next))
        // No caller sees the successful commit or receives the new grant.
        fmt.println("P2P_PROVISION_COMMITTED")
    } else {
        s:=&o.store
        assert(sql.sqlite3_exec(s.connection.db,"BEGIN IMMEDIATE;",nil,nil,nil) == 0)
        assert(sc.pack(&s.codec,next,{kind=0x5050,epoch=u64(pp.VERSION),tick=next.enrollment.record.revision,content=55},s.buffer).error == .None)
        statement:sql.Statement
        assert(sql.sqlite3_prepare_v2(s.connection.db,"UPDATE replay_p2p_provision SET value=?1;",-1,&statement,nil) == 0)
        assert(sql.sqlite3_bind_blob(statement,1,raw_data(s.buffer),i32(len(s.buffer)),nil) == 0)
        assert(sql.sqlite3_step(statement) == 101);sql.sqlite3_finalize(statement)
        fmt.println("P2P_PROVISION_UNCOMMITTED")
    }
    for {time.sleep(100*time.Millisecond)}
}
main :: proc() {
    assert(len(os.args) == 3);mode,path:=os.args[1],os.args[2]
    o:Owner;r:pp.Room
    assert(db.open(&o.store,path,mode=="create") == .None)
    defer db.close(&o.store);defer pp.close(&r)
    if mode=="create" {
        b,error:=pp.make_room(871,55,2,ADMIN,address(),{read=entropy});assert(error == .None)
        assert(pp.open(&r,b,commit,&o,{read=clock},{},{read=entropy}) == .None)
        _,error=pp.invite(&r,ADMIN,INVITE);assert(error == .None)
        fmt.println("P2P_PROVISION_CREATED");return
    }
    b,found,error:=db.load(&o.store,871,55);assert(found && error == .None && b.players == 2)
    if mode=="verify-uncommitted" {assert(b.enrollment.record.members[1] == (auth.Member{}) && b.enrollment.invites[0].remaining == 1)}
    if mode=="verify-committed" {assert(b.enrollment.record.members[1].identity.member == 2 && b.enrollment.invites[0].remaining == 0)}
    assert(pp.open(&r,b,commit,&o,{read=clock},{},{read=entropy}) == .None)
    if mode=="uncommitted" || mode=="committed" {o.phase=mode}
    g,joined:=pp.join(&r,{871,INVITE},CLAIM,address());assert(joined == .None)
    if mode=="verify-committed" {assert(g.key == b.enrollment.enrollments[1].key && g.token == b.enrollment.enrollments[1].token)}
    reg,ready:=pp.registry(&r)
    assert(ready == .None && reg.match.count == 2 && !g.can_host && !g.trusted_authority && r.bundle.enrollment.record.epoch == 0)
    fmt.printf("P2P_PROVISION_CRASH_OK mode=%s generation=%d players=2 epoch=0\n",mode,r.bundle.enrollment.record.coordinator_generation)
}
