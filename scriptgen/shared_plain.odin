package scriptgen

import "core:strings"

// Shared vocabulary imports are not composition sources. Before refusing an
// unresolved embed, prove that its complete inline shape has no Godot metadata.
// Generic arguments retain their caller's package/import context: a T supplied
// by game.World must not accidentally resolve to a same-named type in replay.
Plain_Type :: struct {text:string,from:Struct_Def,bindings:^Plain_Bindings}
Plain_Bindings :: struct {values:map[string]Plain_Type}

shared_embed_plain :: proc(from:Struct_Def,text:string)->bool {
 budget:=4096
 return shared_plain_type({text,from,nil},0,&budget)
}

shared_plain_type :: proc(value:Plain_Type,depth:int,budget:^int)->bool {
 if depth>=64 || budget^<=0 {return false}
 budget^-=1
 t:=strings.trim_space(value.text)
 if t=="" {return false}
 if value.bindings!=nil {if bound,ok:=value.bindings.values[t];ok {return shared_plain_type(bound,depth+1,budget)}}
 // These shapes are already opaque to field/method composition. Pointer/slice
 // targets and callback parameters are not inline embedded components.
 if t[0]=='^' || t[0]=='[' || strings.has_prefix(t,"map[") || strings.has_prefix(t,"proc(") || strings.has_prefix(t,"proc ") {return true}
 switch t {
 case "bool","b8","b16","b32","b64","int","uint","uintptr","rune",
      "i8","i16","i32","i64","i128","u8","u16","u32","u64","u128",
      "f16","f32","f64","complex32","complex64","complex128","quaternion64","quaternion128","quaternion256",
      "string","cstring","rawptr","any","typeid":return true
 }
 if strings.has_prefix(t,"union ") || strings.has_prefix(t,"union{") || strings.has_prefix(t,"enum ") || strings.has_prefix(t,"bit_set[") {return true}
 if is_signal_field_type(t) {return false}
 // Engine and standard-library types cannot carry this generator's metadata.
 if dot:=strings.index_byte(t,'.');dot>=0 {
  alias:=t[:dot]
  if alias=="gd" || alias=="godot" {
   // Engine qualifiers are normalized to gd. An authored user import with that
   // spelling makes this context ambiguous, so it cannot prove a plain shape.
   if imp,shadowed:=value.from.imports[alias];shadowed && imp!="godot:godot" {return false}
   if value.from.imports["@engine"]=="godot:godot" {return true}
  }
  if imp,ok:=value.from.imports[alias];ok {
   if strings.has_prefix(imp,"core:") || strings.has_prefix(imp,"base:") || strings.has_prefix(imp,"vendor:") {return true}
  }
 }
 if named,ok:=wire_named_lookup(value.from,t);ok {
  if named.kind==.Enum {return true}
  return shared_plain_type({named.underlying,Struct_Def{dir=named.dir,imports=named.imports},nil},depth+1,budget)
 }
 base:=t;arguments:[dynamic]string
 if paren:=strings.index_byte(t,'(');paren>=0 {
  if !strings.has_suffix(t,")") {return false}
  base=strings.trim_space(t[:paren])
  arguments=split_type_params(t[paren+1:len(t)-1])
 }
 defer delete(arguments)
 def,ok:=wire_struct_lookup(value.from,base)
 if !ok || def.input_decl || len(def.commands)>0 || len(def.methods)>0 || def.tick.proc_name!="" || len(arguments)!=len(def.poly_params) {return false}
 bindings:=Plain_Bindings{values=make(map[string]Plain_Type)}
 defer delete(bindings.values)
 for parameter,i in def.poly_params {bindings.values[parameter]={strings.trim_space(arguments[i]),value.from,value.bindings}}
 for field in def.fields {
  if _,tagged:=tag_gd_value(field.tag);tagged {return false}
  if !shared_plain_type({field.type_text,def,&bindings},depth+1,budget) {return false}
 }
 return true
}
