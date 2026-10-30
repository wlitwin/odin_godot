package replay_provision_sqlite_test

import "core:fmt"
import "core:testing"
import a "godot:replay/assets"
import auth "godot:replay/authority"
import ck "godot:replay/provision/checkpoint"
import db "godot:replay/provision/sqlite"
import sql "godot:replay/authority/sqlite"
import p "godot:replay/provision"
import net "godot:replay/net"
import sc "godot:replay/schema"
import tf "godot:replay/transfer"
import f "publication_fixture"

asset_policy :: proc()->ck.Asset_Policy {
	return {collect=proc(_:rawptr,root:[]u8,dst:[]a.Ref,codec:^net.Checkpoint_Codec)->(int,bool) {
		cp:net.Checkpoint(f.World,u8,u8,1);defer net.checkpoint_destroy(&cp)
		if len(dst)<2 || net.checkpoint_decode(&cp,root,f.model(),55,codec=codec)!=.None {return 0,false}
		copy(dst,cp.frame.state.images[:]);return 2,true
	},validate=proc(_:rawptr,_:a.Ref,bytes:[]u8)->bool {return len(bytes)>0 && bytes[0]=='A'}}
}
asset_cache :: proc(cache:^a.Cache)->[2]a.Ref {
	assert(a.cache_init(cache)==.None)
	first,e1:=a.cache_put(cache,transmute([]u8)string("Asset first"));assert(e1==.None)
	second,e2:=a.cache_put(cache,transmute([]u8)string("Asset second"));assert(e2==.None)
	return {first,second}
}
asset_unchecked_package :: proc(root:[]u8,point:auth.Point,refs:[]a.Ref,cache:^a.Cache)->[]u8 {
	body,error:=a.bundle_encode(root,refs,cache,{epoch=point.scope.epoch,tick=point.archive.tick,content=point.scope.content});assert(error==.None);defer delete(body)
	bytes:=make([]u8,sc.HEADER_BYTES+len(body))
	assert(sc.pack_bytes(ck.PACKAGE_SCHEMA,{kind=ck.PACKAGE_KIND,epoch=point.scope.epoch,tick=point.archive.tick,content=point.scope.content},body,bytes).error==.None)
	return bytes
}

@(test)
asset_complete_publication_reopens_into_an_empty_cache_without_granting_authority :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/assets-reopen.sqlite3",DIRECTORY);defer delete(path)
	cache:a.Cache;refs:=asset_cache(&cache);defer a.cache_destroy(&cache)
	x:f.Fixture;f.open(&x,path,refs);defer f.close(&x)
	point,root:=f.checkpoint(&x,1);defer delete(root)
	_,missing:=db.checkpoint_publish(&x.store,x.room.bundle.record,0,point,root,f.model(),assets=asset_policy());testing.expect_value(t,missing,db.Error.Schema)
	payload,encoded:=ck.package_encode(root,point,&cache,asset_policy());assert(encoded==.None);defer delete(payload)
	before:=x.room.bundle.record
	publication,error:=db.checkpoint_publish(&x.store,before,0,point,root,f.model(),payload=payload,assets=asset_policy());testing.expect_value(t,error,db.Error.None)
	retry,replayed:=db.checkpoint_publish(&x.store,before,0,point,root,f.model(),payload=payload,assets=asset_policy());testing.expect(t,replayed==.None && retry==publication)
	a.cache_destroy(&cache);p.close(&x.room);db.close(&x.store)
	assert(db.open(&x.store,path)==.None)
	saved,found,loaded:=db.checkpoint_load(&x.store,44,55,f.model(),assets=asset_policy());defer db.stored_checkpoint_destroy(&saved)
	testing.expect(t,found && loaded==.None && saved.publication==publication && len(saved.payload)>len(saved.bytes))
	assert(a.cache_init(&cache)==.None)
	testing.expect_value(t,ck.package_install(saved.payload,saved.bytes,point,&cache,asset_policy()),ck.Error.None)
	testing.expect(t,a.cache_has(&cache,refs[0]) && a.cache_has(&cache,refs[1]) && cache.count==2)
	stored,exists,read:=db.load(&x.store,44,55);testing.expect(t,exists && read==.None && stored.record==before)
}

@(test)
missing_extra_invalid_assets_and_readonly_storage_do_not_replace_previous_publication :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/assets-reject.sqlite3",DIRECTORY);defer delete(path)
	cache:a.Cache;refs:=asset_cache(&cache);defer a.cache_destroy(&cache)
	x:f.Fixture;f.open(&x,path,refs);defer f.close(&x)
	point,root:=f.checkpoint(&x,1);defer delete(root)
	payload,_:=ck.package_encode(root,point,&cache,asset_policy());defer delete(payload)
	_,error:=db.checkpoint_publish(&x.store,x.room.bundle.record,0,point,root,f.model(),payload=payload,assets=asset_policy());assert(error==.None)
	next,next_root:=f.checkpoint(&x,2);defer delete(next_root)
	missing:=asset_unchecked_package(next_root,next,refs[:1],&cache);defer delete(missing)
	_,e1:=db.checkpoint_publish(&x.store,x.room.bundle.record,1,next,next_root,f.model(),payload=missing,assets=asset_policy());testing.expect_value(t,e1,db.Error.Schema)
	extra_ref,_:=a.cache_put(&cache,transmute([]u8)string("Asset extra"))
	extra_refs:=[3]a.Ref{refs[0],refs[1],extra_ref}
	extra:=asset_unchecked_package(next_root,next,extra_refs[:],&cache);defer delete(extra)
	_,e2:=db.checkpoint_publish(&x.store,x.room.bundle.record,1,next,next_root,f.model(),payload=extra,assets=asset_policy());testing.expect_value(t,e2,db.Error.Schema)
	next_payload,_:=ck.package_encode(next_root,next,&cache,asset_policy());defer delete(next_payload)
	assert(sql.sqlite3_exec(x.store.connection.db,"PRAGMA query_only=ON;",nil,nil,nil)==0)
	_,e3:=db.checkpoint_publish(&x.store,x.room.bundle.record,1,next,next_root,f.model(),payload=next_payload,assets=asset_policy());testing.expect_value(t,e3,db.Error.Write)
	saved,found,loaded:=db.checkpoint_load(&x.store,44,55,f.model(),assets=asset_policy());defer db.stored_checkpoint_destroy(&saved)
	testing.expect(t,found && loaded==.None && saved.publication.point==point && tf.hash(saved.payload)==tf.hash(payload))
	assert(sql.sqlite3_exec(x.store.connection.db,"PRAGMA query_only=OFF;",nil,nil,nil)==0)
	assert(sql.sqlite3_exec(x.store.connection.db,"UPDATE replay_room_checkpoint_package SET bytes=zeroblob(0);",nil,nil,nil)==0)
	bad,exists,corrupt:=db.checkpoint_load(&x.store,44,55,f.model(),assets=asset_policy());defer db.stored_checkpoint_destroy(&bad)
	testing.expect(t,!exists && corrupt==.Read && !bad.ready && len(bad.bytes)==0 && len(bad.payload)==0)
	testing.expect_value(t,tf.hash(saved.payload),tf.hash(payload))
}

@(test)
signed_asset_bundle_roundtrip_restores_from_durable_bytes_after_old_cache_is_destroyed :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/assets-protocol.sqlite3",DIRECTORY);defer delete(path)
	cache:a.Cache;refs:=asset_cache(&cache);defer a.cache_destroy(&cache)
	x:=new(Protocol_Fixture);defer free(x);protocol_open(x,path,refs);defer protocol_close(x);x.backend.assets=asset_policy()
	point,root:=f.checkpoint(&x.base,1);defer delete(root)
	payload,encoded:=ck.package_encode(root,point,&cache,asset_policy());assert(encoded==.None);defer delete(payload)
	q:=protocol_request(x,.Upload,1,0,point);q.payload=ck.payload_for(point,payload)
	assert(ck.client_begin(&x.client,q,payload)==.None);protocol_finish(x)
	testing.expect(t,x.client.phase==.Complete && x.client.reply.publication.point==point)
	a.cache_destroy(&cache);x.now=2500;restore_fresh_owner(x)
	prepared:auth.Prepared;defer auth.prepared_destroy(&prepared);publication:=restore_download(x,&prepared)
	assert(a.cache_init(&cache)==.None)
	testing.expect_value(t,ck.package_install(x.client.saved.payload,prepared.bytes,point,&cache,asset_policy()),ck.Error.None)
	testing.expect(t,cache.count==2 && a.cache_has(&cache,refs[0]) && a.cache_has(&cache,refs[1]))
	assert(ck.client_restore(&x.client,&x.lease,publication,&prepared)==.None);protocol_finish(x)
	testing.expect(t,x.client.phase==.Complete && x.lease.view.epoch==2)
}

@(test)
bundle_cache_install_and_transfer_size_limits_fail_without_partial_results :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/assets-capacity.sqlite3",DIRECTORY);defer delete(path)
	cache:a.Cache;refs:=asset_cache(&cache);defer a.cache_destroy(&cache)
	x:f.Fixture;f.open(&x,path,refs);defer f.close(&x)
	point,root:=f.checkpoint(&x,1);defer delete(root)
	payload,_:=ck.package_encode(root,point,&cache,asset_policy());defer delete(payload)
	small:a.Cache;assert(a.cache_init(&small,{1,128*1024,128*1024})==.None);defer a.cache_destroy(&small)
	testing.expect_value(t,ck.package_install(payload,root,point,&small,asset_policy()),ck.Error.Capacity)
	testing.expect(t,small.count==0 && small.bytes==0)
	bad_policy:=asset_policy();bad_policy.validate=proc(_:rawptr,_:a.Ref,_:[]u8)->bool{return false}
	testing.expect_value(t,ck.package_install(payload,root,point,&small,bad_policy),ck.Error.Schema)
	testing.expect(t,small.count==0)
	// The generic bundle's caller-selected limit is checked before allocation.
	too_large,limited:=a.bundle_encode(root,refs[:],&cache,{epoch=1,content=55,tick=point.archive.tick},limit=len(root))
	testing.expect(t,limited==.Capacity && len(too_large)==0)
}

@(test)
restore_commit_fails_if_asset_package_disappears_after_validation :: proc(t:^testing.T) {
	path:=fmt.aprintf("%s/assets-restore-guard.sqlite3",DIRECTORY);defer delete(path)
	cache:a.Cache;refs:=asset_cache(&cache);defer a.cache_destroy(&cache)
	x:f.Fixture;f.open(&x,path,refs);defer f.close(&x)
	point,root:=f.checkpoint(&x,1);defer delete(root)
	payload,_:=ck.package_encode(root,point,&cache,asset_policy());defer delete(payload)
	publication,error:=db.checkpoint_publish(&x.store,x.room.bundle.record,0,point,root,f.model(),payload=payload,assets=asset_policy());assert(error==.None)
	descriptor:=ck.payload_for(point,payload)
	candidate:=x.room.service.coordinator;candidate.commit=proc(_:rawptr,_:u64,_:auth.Record)->bool{return true}
	assert(auth.coordinator_recover_published(&candidate,{1,1},1,2,point,2500)==.None)
	next:=x.room.bundle;next.record=candidate.record
	x.store.recovery_publication,x.store.recovery_payload=&publication,&descriptor
	defer {x.store.recovery_publication,x.store.recovery_payload=nil,nil}
	assert(sql.sqlite3_exec(x.store.connection.db,"DELETE FROM replay_room_checkpoint_package;",nil,nil,nil)==0)
	testing.expect(t,!db.commit(&x.store,x.room.bundle.record.revision,next) && x.store.error==.Conflict)
	stored,found,loaded:=db.load(&x.store,44,55)
	testing.expect(t,found && loaded==.None && stored.record==x.room.bundle.record)
	bad,exists,invalid:=db.checkpoint_load(&x.store,44,55,f.model(),assets=asset_policy());defer db.stored_checkpoint_destroy(&bad)
	testing.expect(t,!exists && invalid==.Schema && !bad.ready)
}
