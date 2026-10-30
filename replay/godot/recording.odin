package replay_godot

import "core:fmt"
import gd "godot:godot"
import "godot:gdext"
import r "godot:replay"
import d "godot:replay/diagnostic"

Recording_Export :: struct {error:d.Recording_Error,storage:Storage_Error,bytes:int,first,last:u64,download_requested:bool}

// Explicit developer action: snapshot the latest replayable local suffix.
// Native writes use staged replacement. Web requests a browser download; that
// request is not a receipt that the user retained the downloaded file.
recording_export :: proc(t:^r.Timeline($S,$I,$E),identity:d.Recording_Context,path,filename:string,max_ticks:int=120)->Recording_Export {
 recording:d.Recording(S,I,E);defer d.recording_destroy(&recording)
 if result:=d.recording_capture(&recording,t,identity,max_ticks);result.error!=.None {return {error=result.error}}
 bytes,error:=d.recording_encode(&recording);defer delete(bytes)
 if error!=.None {return {error=error}}
 result:=Recording_Export{bytes=len(bytes),first=recording.base.tick,last=recording.header.head}
 when gd.IS_WEB {
  packet:=gd.new_packed_byte_array();defer gd.free_packed_byte_array(packet)
  if gd.packed_byte_array_resize(&packet,gd.Int(len(bytes)))!=0 {return {error=.Capacity}}
  copy(gd.packed_byte_array_view(&packet),bytes)
  name:=gd.new_string_odin(filename);defer gd.free_string(name)
  mime:=gd.new_string_cstring("application/octet-stream");defer gd.free_string(mime)
  gd.java_script_bridge_download_buffer(gd.singleton_java_script_bridge(),packet,name,mime)
  result.download_requested=true
 } else {result.storage=storage_write(path,bytes,d.MAX_RECORDING_BYTES)}
 return result
}

// Optional button, usually attached to the history dock's command row. Stable
// address required until destruction disconnects its Godot callable.
Debug_Recording :: struct {button:gd.Button,call:gd.Callable,connected,pending:bool,exports:u64,last:Recording_Export}
debug_recording_init :: proc(debug:^Debug_Recording,parent:gd.Node)->bool {
 if parent==nil || debug.button!=nil {return false}
 debug.button=gd.new_button();gd.add_child(parent,debug.button);gd.set_string(debug.button,"name","ReplayRecordingExport")
 gd.set_string(debug.button,"text","Export recording");gd.control_set_focus_mode(debug.button,.Focus_None)
 info:=gdext.ExtensionCallableCustomInfo2{token=gdext.library,call_func=debug_recording_pressed,callable_userdata=debug}
 gdext.callable_custom_create2(&debug.call,&info)
 pressed:=gd.new_string_name("pressed");defer gd.free_string_name(pressed)
 debug.connected=gd.object_connect(cast(gd.Object)debug.button,pressed,debug.call,0)==.Ok
 if !debug.connected {debug_recording_destroy(debug);return false}
 return true
}
debug_recording_frame :: proc(debug:^Debug_Recording,t:^r.Timeline($S,$I,$E),identity:d.Recording_Context,path,filename:string,max_ticks:int=120) {
 if debug.button==nil || !debug.pending {return};debug.pending=false
 debug.last=recording_export(t,identity,path,filename,max_ticks)
 result:=debug.last
 if result.error!=.None || result.storage!=.None {
  gd.set_string(debug.button,"text","Export failed")
  gd.set_string(debug.button,"tooltip_text",fmt.ctprintf("Recording: %v | storage: %v",result.error,result.storage))
 } else {
  debug.exports+=1
  gd.set_string(debug.button,"text",result.download_requested ? "Download requested" : "Recording saved")
  gd.set_string(debug.button,"tooltip_text",fmt.ctprintf("Ticks %d..%d | %d bytes | %s\nExports original recorded history; Apply changes only the preview until Branch.",result.first,result.last,result.bytes,result.download_requested ? filename : path))
 }
}
debug_recording_destroy :: proc(debug:^Debug_Recording) {
 if debug.button==nil {return}
 if debug.connected {pressed:=gd.new_string_name("pressed");gd.object_disconnect(cast(gd.Object)debug.button,pressed,debug.call);gd.free_string_name(pressed)}
 gd.free_callable(debug.call);gd.node_queue_free(debug.button);debug^={}
}
@(private)
debug_recording_pressed :: proc "c" (raw:rawptr,args:[^]gdext.VariantPtr,argc:i64,ret:gdext.VariantPtr,error:^gdext.CallError) {
 context=gdext.godot_context();gdext.variant_new_nil(ret);error^={}
 if argc==0 {debug:=cast(^Debug_Recording)raw;debug.pending=true}
}
