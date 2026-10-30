package replay_godot_wire

import gd "godot:godot"
import "godot:gdext"

// Internal signaling codec shared by adapters and control services.
// get returns an owned Variant; get_string returns an owned Odin string.
// set consumes its Variant value. JSON bounds, hexadecimal policy, and
// little-endian identity encoding are part of the existing wire contract.

get :: proc(d:^gd.Dictionary,key:cstring)->gd.Variant {
 s:=gd.new_string_cstring(key);defer gd.free_string(s);k:=gd.variant_from_string(&s);defer gd.variant_destroy(&k)
 nil_value:gd.Variant;return gd.dictionary_get(d,k,nil_value)
}

get_int :: proc(d:^gd.Dictionary,key:cstring)->i64 {
 v:=get(d,key);defer gd.variant_destroy(&v)
 typ:=gdext.variant_get_type(&v);if typ!=.Int && typ!=.Float {return -1}
 if typ==.Float {f:=gd.variant_to_float(&v);if f<0 || f>f64(max(i32)) || f!=f64(i64(f)) {return -1};return i64(f)}
 return gd.variant_to_int(&v)
}

get_string :: proc(d:^gd.Dictionary,key:cstring,limit:int)->string {
 v:=get(d,key);defer gd.variant_destroy(&v);if gdext.variant_get_type(&v)!=.String {return ""}
 s:=gd.variant_to_string(&v);defer gd.free_string(s)
 size:=gdext.string_to_utf8_chars(&s,nil,0);if size<0 || size>i64(limit) {return ""}
 bytes:=make([]u8,int(size));if size>0 {gdext.string_to_utf8_chars(&s,cstring(raw_data(bytes)),size)}
 return string(bytes)
}

set :: proc(d:^gd.Dictionary,key:cstring,value:gd.Variant) {
 value:=value;defer gd.variant_destroy(&value)
 s:=gd.new_string_cstring(key);defer gd.free_string(s);k:=gd.variant_from_string(&s);defer gd.variant_destroy(&k)
 gd.dictionary_set(d,k,value)
}

set_int :: proc(d:^gd.Dictionary,key:cstring,value:i64) {v:=value;set(d,key,gd.variant_from_int(&v))}

set_string :: proc(d:^gd.Dictionary,key:cstring,value:string) {s:=gd.new_string_odin(value);defer gd.free_string(s);set(d,key,gd.variant_from_string(&s))}

set_bool :: proc(d:^gd.Dictionary,key:cstring,value:bool) {v:=value;set(d,key,gd.variant_from_bool(&v))}

json_depth :: proc(bytes:[]u8)->bool {
 depth:=0;quoted,escape:bool
 for b in bytes {
  if quoted {if escape {escape=false} else if b=='\\' {escape=true} else if b=='"' {quoted=false};continue}
  if b=='"' {quoted=true} else if b=='{' || b=='[' {depth+=1;if depth>16 {return false}} else if b=='}' || b==']' {depth-=1;if depth<0 {return false}}
 }
 return depth==0 && !quoted
}

identity_hex :: proc(value:u64)->string {
 bytes:[8]u8;for &byte,i in bytes {byte=u8(value>>uint(i*8))};return hex_encode(bytes[:])
}

identity_value :: proc(text:string)->(u64,bool) {
 bytes:[8]u8;if !hex_decode(bytes[:],text) {return 0,false}
 value:u64;for byte,i in bytes {value|=u64(byte)<<uint(i*8)};return value,value!=0
}

hex_encode :: proc(bytes:[]u8)->string {
 out:=make([]u8,len(bytes)*2,context.temp_allocator);alphabet:="0123456789abcdef"
 for byte,i in bytes {out[2*i]=alphabet[byte>>4];out[2*i+1]=alphabet[byte&15]}
 return string(out)
}

hex_decode :: proc(dst:[]u8,src:string)->bool {
 if len(src)!=2*len(dst) {return false}
 nibble :: proc(b:u8)->(u8,bool) {
  if b>='0' && b<='9' {return b-'0',true};if b>='a' && b<='f' {return b-'a'+10,true};return 0,false
 }
 for &byte,i in dst {a,ok:=nibble(src[2*i]);b,valid:=nibble(src[2*i+1]);if !ok || !valid {return false};byte=(a<<4)|b}
 return true
}
