package replay_assets_test

import "core:testing"
import a "godot:replay/assets"
import r "godot:replay"
import sc "godot:replay/schema"

@(test)
references_are_portable_and_cache_reads_do_not_mutate_content :: proc(t: ^testing.T) {
 c:a.Cache; testing.expect_value(t,a.cache_init(&c),a.Error.None); defer a.cache_destroy(&c)
 bytes:=[4]u8{1,2,3,4}; ref,err:=a.cache_put(&c,bytes[:]); testing.expect_value(t,err,a.Error.None)
 bytes[0]=9
 copy1,read:=a.cache_copy(&c,ref); defer delete(copy1); testing.expect_value(t,read,a.Error.None)
 testing.expect_value(t,copy1[0],u8(1)); copy1[0]=8
 copy2,_:=a.cache_copy(&c,ref); defer delete(copy2); testing.expect_value(t,copy2[0],u8(1))
 testing.expect_value(t,a.reference(copy2),ref)
 codec:sc.Schema; defer sc.destroy(&codec)
 testing.expect_value(t,sc.init(&codec,a.Ref).error,sc.Error.None); testing.expect_value(t,codec.wire_size,a.REF_BYTES)
 timeline:r.Timeline(a.Ref,u8,u8)
 testing.expect_value(t,r.init(&timeline,r.Frame(a.Ref){state=ref},proc(s:^a.Ref,i:u8,ctx:^r.Step(u8)){}),r.Error.None)
 defer r.destroy(&timeline)
}

@(test)
corruption_and_capacity_preserve_existing_pinned_assets :: proc(t: ^testing.T) {
 c:a.Cache; a.cache_init(&c,{2,8,8}); defer a.cache_destroy(&c)
 first:=[4]u8{1,2,3,4}; other:=[4]u8{5,6,7,8}
 ref,_:=a.cache_put(&c,first[:]); a.cache_pin(&c,ref)
 _,err:=a.cache_put(&c,other[:],ref); testing.expect_value(t,err,a.Error.Integrity)
 testing.expect_value(t,c.count,1); testing.expect(t,a.cache_has(&c,ref))
 second,_:=a.cache_put(&c,other[:]); testing.expect_value(t,c.bytes,8)
 other[0]=9; _,err=a.cache_put(&c,other[:]); testing.expect_value(t,err,a.Error.Capacity)
 testing.expect_value(t,c.bytes,8); testing.expect_value(t,a.cache_discard(&c,ref),a.Error.Pinned)
 testing.expect_value(t,a.cache_discard(&c,second),a.Error.None)
 _,err=a.cache_put(&c,other[:]); testing.expect_value(t,err,a.Error.None)
 a.cache_unpin(&c,ref); testing.expect_value(t,a.cache_discard(&c,ref),a.Error.None)
 testing.expect(t,!a.cache_has(&c,ref))
}
