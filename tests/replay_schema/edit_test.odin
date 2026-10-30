package replay_schema_test

import "core:testing"
import "core:reflect"
import sc "godot:replay/schema"
import game "../../examples/replay_hello/shared/hello"

@(test)
hello_editor_enforces_pool_invariants :: proc(t:^testing.T) {
 s:sc.Schema;sc.init(&s,game.World);defer sc.destroy(&s)
 value:=game.initial();before:=value
 index,ok:=sc.field_index(&s,"$.actors.count");testing.expect(t,ok)
 testing.expect(t,game.network_state_valid(value))
 testing.expect_value(t,sc.edit_scalar(&s,&value,index,"99",game.network_state_valid).error,sc.Edit_Error.Model)
 testing.expect(t,reflect.equal(value,before))
}

Edit_State :: struct {small:i8,big:u64,signed:i64,endian:u16be,precise:f64,real:f32be,half:f16,flag:bool,mode:Mode,flags:bit_set[Mode;u8],secret:u32 `replay:"authority"`}
edit_valid :: proc(v:Edit_State)->bool {return v.small<=50}

@(test)
scalar_edits_are_checked_and_transactional :: proc(t:^testing.T) {
 s:sc.Schema;testing.expect_value(t,sc.init(&s,Edit_State).error,sc.Error.None);defer sc.destroy(&s)
 value:=Edit_State{secret=99}
 Case :: struct {path,text:string,error:sc.Edit_Error}
 cases:=[]Case{
  {"$.small","-128",.None},{"$.small","128",.Out_Of_Range},{"$.small","51",.Model},
  {"$.big","18446744073709551615",.None},{"$.big","18446744073709551616",.Out_Of_Range},
  {"$.big","-1",.Out_Of_Range},{"$.big","0x10000000000000000",.Out_Of_Range},
  {"$.small","9223372036854775808",.Out_Of_Range},{"$.small","-9223372036854775809",.Out_Of_Range},
  {"$.signed","-9223372036854775808",.None},{"$.signed","9223372036854775807",.None},
  {"$.signed","-9223372036854775809",.Out_Of_Range},{"$.endian","0x1234",.None},
  {"$.precise","1.2345678901234567",.None},{"$.big","+",.Invalid_Text},{"$.big","0x",.Invalid_Text},{"$.big","_",.Invalid_Text},
  {"$.big","1junk",.Invalid_Text},{"$.big","1 2",.Invalid_Text},{"$.big","0xffff",.None},
  {"$.real"," 1.25 ",.None},{"$.real","1e39",.Out_Of_Range},{"$.real","NaN",.Out_Of_Range},
  {"$.real","Inf",.Out_Of_Range},{"$.real","1.2x",.Invalid_Text},
  {"$.half","65504",.None},{"$.half","1e10",.Out_Of_Range},
  {"$.flag","true",.None},{"$.flag","1",.Invalid_Text},
  {"$.mode","Attack",.None},{"$.mode","7",.None},{"$.mode","6",.Out_Of_Range},
  {"$.flags","0x80",.None},{"$.flags","0x02",.Invalid_Value},
 }
 for c in cases {
  index,found:=sc.field_index(&s,c.path);testing.expect(t,found)
  before:=value
  testing.expect_value(t,sc.edit_scalar(&s,&value,index,c.text,edit_valid).error,c.error)
  if c.error!=.None {testing.expect(t,reflect.equal(value,before))}
  testing.expect_value(t,value.secret,u32(99))
 }
 // Every displayed scalar can be submitted unchanged, including endian floats,
 // enum names, flags and the full u64 range.
 value.big=max(u64)
 for _,index in s.fields {
  text,error:=sc.scalar_text(&s,value,index);defer delete(text)
  testing.expect_value(t,error,sc.Edit_Error.None)
  before:=value;testing.expect_value(t,sc.edit_scalar(&s,&value,index,text,nil).error,sc.Edit_Error.None)
  testing.expect(t,reflect.equal(value,before))
 }
 before:=value
 wrong:=u32(0)
 testing.expect_value(t,sc.edit_scalar(&s,&wrong,0,"1",nil).error,sc.Edit_Error.Wrong_Type)
 testing.expect_value(t,sc.edit_scalar(&s,cast(^Edit_State)nil,0,"1",nil).error,sc.Edit_Error.Wrong_Type)
 absent:sc.Schema
 testing.expect_value(t,sc.edit_scalar(&absent,&value,0,"1",nil).error,sc.Edit_Error.Schema)
 testing.expect_value(t,sc.edit_scalar(&s,&value,-1,"0",nil).error,sc.Edit_Error.Missing_Field)
 testing.expect(t,reflect.equal(value,before))
 options:=sc.DEFAULT_OPTIONS;options.projection=.Public
 public:sc.Schema;sc.init(&public,Edit_State,options);defer sc.destroy(&public)
 testing.expect_value(t,sc.edit_scalar(&public,&value,0,"0",nil).error,sc.Edit_Error.Projection)
 testing.expect(t,reflect.equal(value,before))
}

@(test)
scalar_union_editor_only_changes_active_leaves :: proc(t:^testing.T) {
 s:sc.Schema;sc.init(&s,Choice);defer sc.destroy(&s)
 value:Choice=Small{7}
 for field,index in s.fields {
  before:=value
  if field.kind==.Union_Tag {
   testing.expect_value(t,sc.edit_scalar(&s,&value,index,"2",nil).error,sc.Edit_Error.Read_Only)
  } else {
   text,error:=sc.scalar_text(&s,value,index);defer delete(text)
   if error==.Inactive_Field {testing.expect_value(t,sc.edit_scalar(&s,&value,index,"9",nil).error,sc.Edit_Error.Inactive_Field)}
   else {testing.expect_value(t,error,sc.Edit_Error.None);testing.expect_value(t,sc.edit_scalar(&s,&value,index,text,nil).error,sc.Edit_Error.None)}
  }
  testing.expect(t,reflect.equal(value,before))
 }
}
