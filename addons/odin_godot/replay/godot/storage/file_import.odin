package replay_godot_storage

import "core:mem"
import gd "godot:godot"
import "godot:gdext"

File_Import_Phase :: enum {
    Idle,
    Pending,
    Selected,
    Ready,
    Canceled,
    Failed,
}

// Stable owner for an explicit file chooser. No reads occur before user selection.
File_Import :: struct {
    dialog:     gd.File_Dialog,
    calls:      [2]gd.Callable,
    connected:  [2]bool,
    count:      int,
    phase:      File_Import_Phase,
    limit:      int,
    path:       string,
    bytes:      []u8,
    allocator:  mem.Allocator,
    browser_id: i64,
}

file_import_init :: proc(f: ^File_Import, parent: gd.Node, limit: int = STORAGE_LIMIT) -> bool {
    if parent == nil || limit < 1 || limit > STORAGE_LIMIT || f.limit != 0 {
        return false
    }

    f.limit = limit
    f.allocator = context.allocator

    when !gd.IS_WEB {
        f.dialog = gd.new_file_dialog()
        gd.add_child(parent, f.dialog)
        gd.set_string(f.dialog, "name", "ReplayRecordingFileDialog")
        gd.file_dialog_set_access(f.dialog, .Access_Filesystem)
        gd.file_dialog_set_file_mode(f.dialog, .File_Mode_Open_File)
        gd.file_dialog_set_use_native_dialog(f.dialog, false)
        filter := gd.new_string_cstring("*.rplrec")
        description := gd.new_string_cstring("Replay recording")
        gd.file_dialog_add_filter(f.dialog, filter, description, gd.string_empty())
        gd.free_string(filter)
        gd.free_string(description)
        signals := [2]cstring{"file_selected", "canceled"}
        callbacks := [2]gdext.ExtensionCallableCustomCall{file_import_selected, file_import_canceled}

        for signal, index in signals {
            info := gdext.ExtensionCallableCustomInfo2 {
                token             = gdext.library,
                call_func         = callbacks[index],
                callable_userdata = f,
            }
            gdext.callable_custom_create2(&f.calls[index], &info)
            f.count += 1
            name := gd.new_string_name_cstring(signal, false)
            f.connected[index] = gd.object_connect(cast(gd.Object)f.dialog, name, f.calls[index], 0) == .Ok
            gd.free_string_name(name)

            if !f.connected[index] {
                file_import_destroy(f)
                return false
            }
        }
    }

    return true
}

file_import_begin :: proc(f: ^File_Import) -> bool {
    if f.limit == 0 || f.phase != .Idle {
        return false
    }

    f.phase = .Pending

    when gd.IS_WEB {
        script := gd.new_string_odin(FILE_IMPORT_JS)
        defer gd.free_string(script)
        installed := gd.java_script_bridge_eval(gd.singleton_java_script_bridge(), script, true)
        defer gd.variant_destroy(&installed)

        if gd.variant_to_int(&installed) != 1 {
            f.phase = .Failed
            return false
        }

        limit := i64(f.limit)
        arg := gd.variant_from_int(&limit)
        defer gd.variant_destroy(&arg)
        value := file_import_call("open", arg)
        defer gd.variant_destroy(&value)
        f.browser_id = gd.variant_to_int(&value)

        if f.browser_id <= 0 {
            f.phase = .Failed
            return false
        }
    } else {
        gd.window_popup_centered_clamped(f.dialog, {600, 400}, 0.85)
    }

    return true
}

file_import_poll :: proc(f: ^File_Import) -> File_Import_Phase {
    when gd.IS_WEB {
        if f.phase != .Pending {
            return f.phase
        }

        arg := gd.variant_from_int(&f.browser_id)
        defer gd.variant_destroy(&arg)
        status := file_import_call("state", arg)
        defer gd.variant_destroy(&status)

        switch gd.variant_to_int(&status) {
        case 0:
            return .Pending
        case 2:
            f.phase = .Canceled
            return f.phase
        case 1:
        case:
            f.phase = .Failed
            return f.phase
        }

        value := file_import_call("bytes", arg)
        defer gd.variant_destroy(&value)
        object := cast(gd.Java_Script_Object)gd.variant_to_object(&value)
        js := gd.singleton_java_script_bridge()

        if object == nil || !gd.java_script_bridge_is_js_buffer(js, object) {
            f.phase = .Failed
            return f.phase
        }

        packet := gd.java_script_bridge_js_buffer_to_packed_byte_array(js, object)
        defer gd.free_packed_byte_array(packet)
        view := gd.packed_byte_array_view(&packet)

        if len(view) < 1 || len(view) > f.limit {
            f.phase = .Failed
            return f.phase
        }

        f.bytes = make([]u8, len(view), f.allocator)
        copy(f.bytes, view)
        f.phase = .Ready
    } else {
        if f.phase == .Selected {
            bytes, error := storage_read(f.path, f.limit, f.allocator)

            if error == .None {
                f.bytes = bytes
                f.phase = .Ready
            } else {
                f.phase = .Failed
            }
        }
    }

    return f.phase
}

// Caller owns returned bytes and frees them with f.allocator. Reset cancels any
// outstanding asynchronous selection/read and fences late browser completions.
file_import_take :: proc(f: ^File_Import) -> []u8 {
    if f.phase != .Ready {
        return nil
    }

    bytes := f.bytes
    f.bytes = nil
    file_import_reset(f)
    return bytes
}

file_import_reset :: proc(f: ^File_Import) {
    when gd.IS_WEB {
        if f.browser_id > 0 {
            arg := gd.variant_from_int(&f.browser_id)
            value := file_import_call("close", arg)
            gd.variant_destroy(&value)
            gd.variant_destroy(&arg)
        }
    } else {
        if f.dialog != nil {
            gd.window_set_visible(f.dialog, false)
        }
    }

    delete(f.bytes, f.allocator)
    delete(f.path, f.allocator)
    f.bytes = nil
    f.path = ""
    f.browser_id = 0
    f.phase = .Idle
}

file_import_destroy :: proc(f: ^File_Import) {
    file_import_reset(f)

    when !gd.IS_WEB {
        signals := [2]cstring{"file_selected", "canceled"}

        for index in 0 ..< f.count {
            if f.connected[index] {
                name := gd.new_string_name_cstring(signals[index], false)
                gd.object_disconnect(cast(gd.Object)f.dialog, name, f.calls[index])
                gd.free_string_name(name)
            }

            gd.free_callable(f.calls[index])
        }

        if f.dialog != nil {
            gd.node_queue_free(f.dialog)
        }
    }

    f^ = {}
}

@(private)
file_import_selected :: proc "c" (
    raw: rawptr,
    args: [^]gdext.VariantPtr,
    argc: i64,
    ret: gdext.VariantPtr,
    error: ^gdext.CallError,
) {
    context = gdext.godot_context()
    gdext.variant_new_nil(ret)
    error^ = {}
    f := cast(^File_Import)raw

    if argc != 1 || f.phase != .Pending {
        return
    }

    value := cast(^gd.Variant)args[0]
    path := gd.variant_to_string(value)
    defer gd.free_string(path)
    f.path = gd.gd_string_to_odin(path, f.allocator)
    f.phase = .Selected
}

@(private)
file_import_canceled :: proc "c" (
    raw: rawptr,
    args: [^]gdext.VariantPtr,
    argc: i64,
    ret: gdext.VariantPtr,
    error: ^gdext.CallError,
) {
    context = gdext.godot_context()
    gdext.variant_new_nil(ret)
    error^ = {}
    f := cast(^File_Import)raw

    if argc == 0 && f.phase == .Pending {
        f.phase = .Canceled
    }
}

@(private)
file_import_call :: proc(method: cstring, args: ..gd.Variant) -> gd.Variant {
    name := gd.new_string_odin("ReplayFileImportV1")
    defer gd.free_string(name)
    object := gd.java_script_bridge_get_interface(gd.singleton_java_script_bridge(), name)

    if object == nil {
        return {}
    }

    defer if gd.ref_counted_unreference(object) {
        gdext.object_destroy(object)
    }

    m := gd.new_string_name_cstring(method, false)
    defer gd.free_string_name(m)
    return gd.object_call(cast(gd.Object)object, m, ..args)
}

@(private)
FILE_IMPORT_JS :: `(()=>{
 if(globalThis.ReplayFileImportV1)return 1;
 const jobs=new Map();let next=1;
 globalThis.ReplayFileImportV1={
  open(limit){
   if(jobs.size>=8||next>=Number.MAX_SAFE_INTEGER||!Number.isInteger(limit)||limit<1||limit>16777216)return 0;
   const id=next++,input=document.createElement('input'),job={state:0,bytes:null,input};jobs.set(id,job);
   input.type='file';input.accept='.rplrec';input.style.display='none';document.body.appendChild(input);
   input.oncancel=()=>{if(jobs.get(id)===job)job.state=2;input.remove();};
   input.onchange=async()=>{
    const file=input.files?.[0];input.remove();
    if(!file){if(jobs.get(id)===job)job.state=2;return;}
    if(file.size<1||file.size>limit){if(jobs.get(id)===job)job.state=3;return;}
    try{const bytes=await file.arrayBuffer();if(jobs.get(id)!==job)return;
     if(bytes.byteLength!==file.size||bytes.byteLength>limit){job.state=3;return;}
     job.bytes=bytes;job.state=1;
    }catch(error){if(jobs.get(id)===job)job.state=3;}
   };
   try{input.click();}catch(error){job.state=3;input.remove();}
   return id;
  },
  state(id){return jobs.get(id)?.state??3;},bytes(id){return jobs.get(id)?.bytes??null;},
  close(id){const job=jobs.get(id);if(job)job.input.remove();jobs.delete(id);return 1;}
 };return 1;
})()`
