//gd:extends Node
//gd:class MethodValues
package method_values

import gd "godot:godot"
import "godot:gdext"

MethodValues :: struct {
 owner:gd.Node,kept:gd.Array,has_kept:bool,last:gd.Int,
 title:gd.String `gd:"export,get=method_values_title"`,
 payload:gd.Array `gd:"export,get=method_values_get_payload"`,
 incoming:gd.Array `gd:"export,set=method_values_set_incoming"`,
}

// Explicit ownership is opt-in so existing borrowed returns remain valid.
@(gd_method="owned_return")
method_values_new_text :: proc(self:^MethodValues)->gd.String {
 bytes:[1024]u8;for &b in bytes {b='x'}
 return gd.new_string_odin(string(bytes[:]))
}
@(gd_method="owned_return")
method_values_new_array :: proc(self:^MethodValues)->gd.Array {return new_payload(self)}
@(gd_method)
method_values_borrowed_array :: proc(self:^MethodValues)->gd.Array {
 if !self.has_kept {self.kept=new_payload(self);self.has_kept=true}
 return self.kept
}
@(gd_method)
method_values_clear :: proc(self:^MethodValues) {
 if self.has_kept {gd.free_array(self.kept);self.kept={};self.has_kept=false}
}
@(gd_method)
method_values_last_id :: proc(self:^MethodValues)->gd.Int {return self.last}
@(gd_method="borrowed_args")
method_values_borrowed_input :: proc(self:^MethodValues,value:gd.Array)->gd.Int {
 value:=value;return gd.array_size(&value)
}
@(gd_method)
method_values_legacy_owned_input :: proc(self:^MethodValues,value:gd.Array)->gd.Int {
 value:=value;defer gd.free_array(value);return gd.array_size(&value)
}
new_payload :: proc(self:^MethodValues)->gd.Array {
 array:=gd.new_array_default()
 resource:=gd.new_resource();gd.ref_counted_init_ref(resource)
 self.last=gd.Int(gd.object_get_instance_id(cast(gd.Object)resource))
 object:=cast(gd.Object)resource;value:=gd.variant_from_object(&object)
 gd.array_push_back(&array,value);gd.variant_destroy(&value)
 if gd.ref_counted_unreference(resource) {gdext.object_destroy(resource)}
 return array
}

@(gd_method)
method_values_echo :: proc(self:^MethodValues,value:string)->string {return value}
@(gd_method="owned_return")
method_values_new_resource :: proc(self:^MethodValues)->gd.Resource {
 resource:=gd.new_resource();gd.ref_counted_init_ref(resource)
 self.last=gd.Int(gd.object_get_instance_id(cast(gd.Object)resource));return resource
}
@(gd_method="owned_return")
method_values_get_payload :: proc(self:^MethodValues)->gd.Array {return new_payload(self)}
@(gd_method="borrowed_args")
method_values_set_incoming :: proc(self:^MethodValues,value:gd.Array) {
 copy:=gd.new_array_array(value);gd.free_array(self.incoming);self.incoming=copy
}
@(gd_method="owned_return")
method_values_new_bytes :: proc(self:^MethodValues)->gd.Packed_Byte_Array {
 bytes:=gd.new_packed_byte_array();gd.packed_byte_array_resize(&bytes,4096)
 gd.packed_byte_array_view(&bytes)[5]=73;return bytes
}
@(gd_method="owned_return")
method_values_new_dictionary :: proc(self:^MethodValues)->gd.Dictionary {
 data:=gd.new_dictionary_default();array:=new_payload(self);defer gd.free_array(array)
 key:=gd.new_string_odin("resource");defer gd.free_string(key)
 k:=gd.variant_from_string(&key);defer gd.variant_destroy(&k)
 v:=gd.variant_from_array(&array);defer gd.variant_destroy(&v)
 gd.dictionary_set(&data,k,v);return data
}

@(gd_method="borrowed_args,owned_return")
method_values_clone_text :: proc(self:^MethodValues,value:gd.String)->gd.String {return gd.new_string_string(value)}
@(gd_method="owned_return")
method_values_new_callable :: proc(self:^MethodValues)->gd.Callable {
 resource:=gd.new_resource();gd.ref_counted_init_ref(resource)
 self.last=gd.Int(gd.object_get_instance_id(cast(gd.Object)resource))
 info:=gdext.ExtensionCallableCustomInfo2{token=gdext.library,callable_userdata=resource,call_func=call_value,free_func=free_value}
 result:gd.Callable;gdext.callable_custom_create2(&result,&info);return result
}
call_value :: proc "c"(user:rawptr,args:[^]gdext.VariantPtr,argc:i64,ret:gdext.VariantPtr,error:^gdext.CallError) {
 context=gdext.godot_context();gdext.variant_new_nil(ret);error^={}
}
free_value :: proc "c"(user:rawptr) {
 context=gdext.godot_context();resource:=cast(gd.Ref_Counted)user
 if gd.ref_counted_unreference(resource) {gdext.object_destroy(resource)}
}

method_values_title :: proc(self:^MethodValues)->string {return "héllo 🌏"}
