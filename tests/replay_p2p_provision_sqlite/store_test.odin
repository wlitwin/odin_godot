package p2p_store_test

import "core:crypto"
import "core:fmt"
import "core:os"
import "core:testing"
import auth "godot:replay/authority"
import sql "godot:replay/authority/sqlite"
import p "godot:replay/provision"
import pp "godot:replay/p2p/provision"
import db "godot:replay/p2p/provision/sqlite"

DIRECTORY :: #config(REPLAY_P2P_PROVISION_TEST_DIR, "/tmp")
ADMIN :: p.Secret{0=41}
INVITE :: p.Secret{0=42}
CLAIM :: p.Secret{0=43}
clock :: proc(_: rawptr) -> (u64,bool) {return 0,true}
entropy :: proc(_: rawptr, dst: []u8) -> bool {crypto.rand_bytes(dst); return true}
address :: proc() -> auth.Endpoint {e,_:=auth.endpoint("127.0.0.1",45001); return e}
setup :: proc(s: ^db.Store, r: ^pp.Room, path: string, players: u8 = 2, room: u64 = 871) {
    assert(db.open(s,path,true) == .None)
    b,error:=pp.make_room(room,55,players,ADMIN,address(),{read=entropy}); assert(error == .None)
    assert(pp.open(r,b,db.commit,s,{read=clock},{},{read=entropy}) == .None)
}

@(test)
restart_preserves_count_keys_and_exact_enrollment_retry :: proc(t: ^testing.T) {
    path:=fmt.aprintf("%s/restart.sqlite3",DIRECTORY); defer delete(path)
    s:db.Store; r:pp.Room; setup(&s,&r,path); defer db.close(&s); defer pp.close(&r)
    ticket,error:=pp.invite(&r,ADMIN,INVITE); testing.expect_value(t,error,p.Error.None)
    g,joined:=pp.join(&r,ticket,CLAIM,address()); testing.expect_value(t,joined,p.Error.None)
    before:=r.bundle
    pp.close(&r); db.close(&s)
    testing.expect_value(t,db.open(&s,path),db.Error.None)
    loaded,found,err:=db.load(&s,871,55)
    testing.expect(t,found && err == .None && loaded == before)
    testing.expect_value(t,pp.open(&r,loaded,db.commit,&s,{read=clock},{},{read=entropy}),p.Error.None)
    retry,retried:=pp.join(&r,ticket,CLAIM,address())
    testing.expect(t,retried == .None && retry == g && !g.can_host && !g.trusted_authority)
    reg,ready:=pp.registry(&r)
    testing.expect(t,ready == .None && reg.match.count == 2 && reg.credentials[1].key == g.key)
    // A caller cannot silently reinterpret the room as a larger match.
    changed:=r.bundle; changed.players=3; changed.enrollment.record.revision+=1
    testing.expect(t,!db.commit(&s,r.bundle.enrollment.record.revision,changed) && s.error == .Conflict)
    _,_,wrong:=db.load(&s,871,56); testing.expect_value(t,wrong,db.Error.Read)
}

@(test)
concurrent_owner_and_readonly_store_fence_unpublished_credentials :: proc(t: ^testing.T) {
    for mode in 0..<2 {
        path:=fmt.aprintf("%s/conflict-%d.sqlite3",DIRECTORY,mode); defer delete(path)
        s,other:db.Store; r,restarted:pp.Room; setup(&s,&r,path)
        ticket,_:=pp.invite(&r,ADMIN,INVITE)
        if mode==0 {
            assert(db.open(&other,path) == .None)
            b,found,error:=db.load(&other,871,55); assert(found && error == .None)
            assert(pp.open(&restarted,b,db.commit,&other,{read=clock},{},{read=entropy}) == .None)
        } else {assert(sql.sqlite3_exec(s.connection.db,"PRAGMA query_only=ON;",nil,nil,nil) == 0)}
        g,error:=pp.join(&r,ticket,CLAIM,address())
        testing.expect(t,error == .Storage && g == (p.Grant{}))
        _,unavailable:=pp.registry(&r); testing.expect_value(t,unavailable,p.Error.Storage)
        b,found,err:=db.load(&s,871,55)
        testing.expect(t,found && err == .None && b.players == 2 && b.enrollment.invites[0].remaining == 1 && b.enrollment.record.members[1] == (auth.Member{}))
        pp.close(&restarted); pp.close(&r); db.close(&other); db.close(&s)
    }
}

@(test)
inventory_and_private_file_validation_fail_without_partial_results :: proc(t: ^testing.T) {
    path:=fmt.aprintf("%s/inventory.sqlite3",DIRECTORY); defer delete(path)
    s:db.Store; r,other:pp.Room; setup(&s,&r,path); defer db.close(&s); defer pp.close(&r); defer pp.close(&other)
    b,error:=pp.make_room(872,55,3,{0=50},address(),{read=entropy}); testing.expect_value(t,error,p.Error.None)
    testing.expect_value(t,pp.open(&other,b,db.commit,&s,{read=clock},{},{read=entropy}),p.Error.None)
    dst:[2]pp.Bundle
    count,err:=db.load_all(&s,55,dst[:]); testing.expect(t,err == .None && count == 2 && dst[0].players == 2 && dst[1].players == 3)
    before:=dst
    count,err=db.load_all(&s,55,dst[:1]); testing.expect(t,err == .Configuration && count == 0 && dst == before)
    count,err=db.load_all(&s,56,dst[:]); testing.expect(t,err == .Read && count == 0 && dst == before)
    testing.expect(t,sql.sqlite3_exec(s.connection.db,"UPDATE replay_p2p_provision SET value=zeroblob(1);",nil,nil,nil) == 0)
    count,err=db.load_all(&s,55,dst[:]); testing.expect(t,err == .Read && count == 0 && dst == before)
    pp.close(&other); pp.close(&r); db.close(&s)
    info,e:=os.lstat(path,context.allocator); defer os.file_info_delete(info,context.allocator)
    testing.expect(t,e == nil && info.mode == (os.Permissions{.Read_User,.Write_User}))
    testing.expect(t,os.chmod(path,os.perm(0o644)) == nil)
    testing.expect_value(t,db.open(&s,path),db.Error.Configuration)
}
