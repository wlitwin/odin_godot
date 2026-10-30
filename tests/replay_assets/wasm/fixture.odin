package replay_assets_wasm
import a "godot:replay/assets"
check :: proc() {
 c:a.Cache; a.cache_init(&c); defer a.cache_destroy(&c)
 bytes:=[2]u8{1,2}; ref,_:=a.cache_put(&c,bytes[:]); a.cache_pin(&c,ref)
 root:=[1]u8{3};refs:=[1]a.Ref{ref}
 bundle,_:=a.bundle_encode(root[:],refs[:],&c,{epoch=1,content=7});defer delete(bundle)
 replaced,_:=a.bundle_replace_root(bundle,bytes[:],7);defer delete(replaced)
 a.cache_read(&c,ref,bytes[:]); a.cache_unpin(&c,ref); a.cache_discard(&c,ref)
}
