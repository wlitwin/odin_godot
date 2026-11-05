package replay_provision_sqlite_test

import "core:fmt"
import "core:testing"
import p "godot:replay/provision"
import db "godot:replay/provision/sqlite"
import sql "godot:replay/authority/sqlite"
import sc "godot:replay/schema"

@(test)
archived_bundle_is_exact_private_history_and_remains_reserved_after_restart :: proc(t:^testing.T){
    path:=fmt.aprintf("%s/room-archive.sqlite3",DIRECTORY);defer delete(path)
    s:db.Store;r:p.Room;setup(&s,&r,path);defer db.close(&s);defer p.close(&r)
    before:=r.bundle
    testing.expect(t,db.archive(&s,before))
    _,found,error:=db.load(&s,44,55)
    testing.expect(t,!found&&error==.None)
    testing.expect_value(t,db.creation_guard(&s,44),p.Error.Denied)
    statement:sql.Statement
    assert(sql.sqlite3_prepare_v2(s.connection.db,"SELECT value FROM replay_provision_archive;",-1,&statement,nil)==0)
    assert(sql.sqlite3_step(statement)==100)
    size:=sql.sqlite3_column_bytes(statement,0);data:=sql.sqlite3_column_blob(statement,0)
    archived:p.Bundle
    _,decoded:=sc.unpack(&s.codec,&archived,(cast([^]u8)data)[:int(size)],{kind=0x5052,epoch=u64(p.VERSION),content=55})
    testing.expect(t,decoded.error==.None&&archived==before)
    sql.sqlite3_finalize(statement)
    db.close(&s);assert(db.open(&s,path)==.None)
    testing.expect_value(t,db.creation_guard(&s,44),p.Error.Denied)
    inventory:[p.MAX_ROOMS]p.Bundle;count,loaded:=db.load_all(&s,55,inventory[:])
    testing.expect(t,loaded==.None&&count==0)
    replacement,created:=p.make_room(44,55,{0=99},address());assert(created==.None)
    testing.expect(t,!db.commit(&s,0,replacement))
}

@(test)
archive_cas_and_ignored_delete_cannot_remove_or_duplicate_active_state :: proc(t:^testing.T){
    path:=fmt.aprintf("%s/room-archive-atomic.sqlite3",DIRECTORY);defer delete(path)
    s:db.Store;r:p.Room;setup(&s,&r,path);defer db.close(&s);defer p.close(&r)
    stale:=r.bundle
    _,issued:=p.invite(&r,ADMIN,INVITE,.Player);assert(issued==.None)
    current:=r.bundle
    testing.expect(t,!db.archive(&s,stale))
    assert(sql.sqlite3_exec(s.connection.db,"CREATE TRIGGER refuse_archive BEFORE DELETE ON replay_provision BEGIN SELECT RAISE(IGNORE); END;",nil,nil,nil)==0)
    testing.expect(t,!db.archive(&s,current))
    loaded,found,error:=db.load(&s,44,55)
    testing.expect(t,found&&error==.None&&loaded==current)
    testing.expect_value(t,db.creation_guard(&s,44),p.Error.None)
}
