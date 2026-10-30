package replay_p2p_link

import "core:crypto"
import "core:crypto/hkdf"
import "core:crypto/hmac"
import auth "godot:replay/authority"
import adm "godot:replay/p2p/admission"
import rec "godot:replay/recovery"

Key :: [32]u8
Nonce :: [32]u8
// The trusted provider binds both current incarnations to the immutable roster.
// Sorted member IDs make the same descriptor usable by both participants.
Scope :: struct {match: adm.Match, members: [2]auth.Identity}
Grant :: struct {scope: Scope, key: Key}

scope_valid :: proc(s: Scope) -> bool {
    if !adm.match_valid(s.match) || !auth.identity_valid(s.members[0]) || !auth.identity_valid(s.members[1]) ||
       s.members[0].member >= s.members[1].member {return false}
    found: [2]bool
    for member in s.match.members {for id,i in s.members {if member == id.member {found[i] = true}}}
    return found[0] && found[1]
}
grant_valid :: proc(g: Grant) -> bool {return scope_valid(g.scope) && g.key != (Key{})}

// Service-only derivation. Never give a participant the other enrollment key.
// Incarnation/content/roster changes derive a different pair key. Service restarts
// preserve it if the committed identities and enrollment keys are unchanged.
derive :: proc(match: adm.Match, a,b: auth.Credential) -> (Grant, bool) {
    low, high := a,b
    if low.identity.member > high.identity.member {low, high = high,low}
    scope := Scope{match,{low.identity,high.identity}}
    if !scope_valid(scope) || low.key == (auth.Key{}) || high.key == (auth.Key{}) || low.key == high.key {return {}, false}
    ikm: [64]u8; copy(ikm[:32],low.key[:]); copy(ikm[32:],high.key[:])
    defer crypto.zero_explicit(&ikm,size_of(ikm))
    salt := scope_hash(scope); key:Key
    info:="replay-p2p-pair-key-v1"
    hkdf.extract_and_expand(.SHA256,salt[:],ikm[:],transmute([]u8)info,key[:])
    return {scope,key},true
}
scope_hash :: proc(s: Scope) -> [32]u8 {
    bytes: [96]u8; code := adm.code(s.match); copy(bytes[:64],code[:])
    for id,i in s.members {put(bytes[64+i*16:72+i*16],id.member);put(bytes[72+i*16:80+i*16],id.incarnation)}
    return rec.hash(bytes[:])
}
@(private)
mac :: proc(key:Key,domain:string,bytes:[]u8)->[32]u8 {
    k:=key;ctx:hmac.Context;hmac.init(&ctx,.SHA256,k[:])
    hmac.update(&ctx,transmute([]u8)domain);hmac.update(&ctx,bytes)
    tag:[32]u8;hmac.final(&ctx,tag[:]);return tag
}
@(private)
equal :: proc(a,b:[]u8)->bool {return len(a)==len(b) && crypto.compare_constant_time(a,b)==1}
@(private)
put :: proc(bytes:[]u8,value:u64) {for &b,i in bytes {b=u8(value>>uint(8*i))}}
@(private)
get :: proc(bytes:[]u8)->u64 {value:u64;for b,i in bytes {value|=u64(b)<<uint(8*i)};return value}
