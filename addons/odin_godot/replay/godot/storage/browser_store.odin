package replay_godot_storage

import gd "godot:godot"
import "godot:gdext"
import "core:encoding/base64"

// Explicit asynchronous IndexedDB operations. Keep an operation until Complete,
// consume any read bytes, then close it. Closing discards the receipt; a write
// may already have committed. Successful submission is never a save receipt.
Browser_Store_Phase :: enum {
    Idle,
    Pending,
    Complete,
}

Browser_Store_Error :: enum {
    None,
    Missing,
    Conflict,
    Size,
    Corrupt,
    Open,
    Read,
    Write,
    Busy,
    Unsupported,
    Invalid_Key,
}

Browser_Store_Op :: struct {
    phase:    Browser_Store_Phase,
    error:    Browser_Store_Error,
    revision: u64,
    id:       i64,
    reading:  bool,
    limit:    int,
}

BROWSER_STORE_REVISION_MAX :: u64(9007199254740991)

browser_store_read :: proc(op: ^Browser_Store_Op, namespace, key: string, limit := STORAGE_LIMIT) -> bool {
    return browser_store_begin(op, namespace, key, nil, 0, limit, true)
}

// Revision zero creates only if absent. Otherwise compare-and-swap protects a
// newer record written by another tab. Each successful write increments it once.
browser_store_write :: proc(
    op: ^Browser_Store_Op,
    namespace, key: string,
    bytes: []u8,
    expected: u64,
    limit := STORAGE_LIMIT,
) -> bool {
    return browser_store_begin(op, namespace, key, bytes, expected, limit, false)
}

@(private)
browser_store_begin :: proc(
    op: ^Browser_Store_Op,
    namespace, key: string,
    bytes: []u8,
    expected: u64,
    limit: int,
    reading: bool,
) -> bool {
    reading := reading

    if op.phase != .Idle {
        return false
    }

    op.phase, op.reading, op.limit = .Complete, reading, limit

    if !browser_store_key_valid(namespace) || !browser_store_key_valid(key) {
        op.error = .Invalid_Key
        return false
    }

    if limit < 1 ||
       limit > STORAGE_LIMIT ||
       (!reading && (len(bytes) < 1 || len(bytes) > limit)) ||
       expected >= BROWSER_STORE_REVISION_MAX {
        op.error = .Size
        return false
    }

    when !gd.IS_WEB {
        op.error = .Unsupported
        return false
    } else {
        code := gd.new_string_odin(BROWSER_STORE_JS)
        defer gd.free_string(code)
        installed := gd.java_script_bridge_eval(gd.singleton_java_script_bridge(), code, true)
        defer gd.variant_destroy(&installed)

        if gd.variant_to_int(&installed) != 1 {
            op.error = .Unsupported
            return false
        }

        ns, k := gd.new_string_odin(namespace), gd.new_string_odin(key)
        defer gd.free_string(ns)
        defer gd.free_string(k)
        // JavaScriptObject method arguments do not convert PackedByteArray.
        // Use a bounded base64 string; the read path uses the buffer bridge.
        encoded := base64.encode(bytes)
        defer delete(encoded)
        payload := gd.new_string_odin(encoded)
        defer gd.free_string(payload)
        rev, n := i64(expected), i64(limit)
        args := [6]gd.Variant {
            gd.variant_from_string(&ns),
            gd.variant_from_string(&k),
            gd.variant_from_string(&payload),
            gd.variant_from_int(&rev),
            gd.variant_from_int(&n),
            gd.variant_from_bool(&reading),
        }

        defer for &arg in args {
            gd.variant_destroy(&arg)
        }

        value := browser_store_call("begin", ..args[:])
        defer gd.variant_destroy(&value)
        op.id = gd.variant_to_int(&value)

        if op.id <= 0 {
            op.error = .Busy
            return false
        }

        op.phase, op.error = .Pending, .None
        return true
    }
}

browser_store_poll :: proc(op: ^Browser_Store_Op) -> Browser_Store_Phase {
    when gd.IS_WEB {
        if op.phase != .Pending {
            return op.phase
        }

        arg := gd.variant_from_int(&op.id)
        defer gd.variant_destroy(&arg)
        value := browser_store_call("status", arg)
        defer gd.variant_destroy(&value)
        status := gd.variant_to_int(&value)

        if status == 0 {
            return .Pending
        }

        op.phase = .Complete

        if status < 1 || status > 9 {
            op.error = .Read
            return .Complete
        }

        op.error = Browser_Store_Error(status - 1)

        if op.error == .None {
            revision := browser_store_call("revision", arg)
            defer gd.variant_destroy(&revision)
            op.revision = u64(gd.variant_to_int(&revision))

            if op.revision < 1 || op.revision > BROWSER_STORE_REVISION_MAX {
                op.error = .Corrupt
            }
        }
    }

    return op.phase
}

// Returns owned bytes only after a successful read. Size was checked in JS
// before materializing the stored Blob; check again before copying into Odin.
browser_store_bytes :: proc(op: ^Browser_Store_Op, allocator := context.allocator) -> ([]u8, Browser_Store_Error) {
    if op.phase != .Complete || op.error != .None || !op.reading {
        return nil, .Read
    }

    when !gd.IS_WEB {
        return nil, .Unsupported
    } else {
        arg := gd.variant_from_int(&op.id)
        defer gd.variant_destroy(&arg)
        value := browser_store_call("bytes", arg)
        defer gd.variant_destroy(&value)
        object := cast(gd.Java_Script_Object)gd.variant_to_object(&value)

        if object == nil {
            return nil, .Read
        }

        js := gd.singleton_java_script_bridge()

        if !gd.java_script_bridge_is_js_buffer(js, object) {
            return nil, .Read
        }

        packet := gd.java_script_bridge_js_buffer_to_packed_byte_array(js, object)
        defer gd.free_packed_byte_array(packet)
        view := gd.packed_byte_array_view(&packet)

        if len(view) < 1 || len(view) > op.limit {
            return nil, .Size
        }

        bytes := make([]u8, len(view), allocator)
        copy(bytes, view)
        return bytes, .None
    }
}

browser_store_close :: proc(op: ^Browser_Store_Op) {
    when gd.IS_WEB {
        if op.id > 0 {
            arg := gd.variant_from_int(&op.id)
            defer gd.variant_destroy(&arg)
            value := browser_store_call("close", arg)
            gd.variant_destroy(&value)
        }
    }

    op^ = {}
}

// Valid keys keep native and browser profile namespaces interchangeable.
browser_store_key_valid :: proc(key: string) -> bool {
    if len(key) < 1 || len(key) > 128 {
        return false
    }

    for b in key {
        if !((b >= 'a' && b <= 'z') ||
               (b >= 'A' && b <= 'Z') ||
               (b >= '0' && b <= '9') ||
               b == '_' ||
               b == '-' ||
               b == '.' ||
               b == '/') {
            return false
        }
    }

    return true
}

@(private)
browser_store_call :: proc(method: cstring, args: ..gd.Variant) -> gd.Variant {
    name := gd.new_string_odin("ReplayBrowserStoreV1")
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
BROWSER_STORE_JS :: `(()=>{
 if(globalThis.ReplayBrowserStoreV1)return 1;
 try{if(!globalThis.indexedDB || !globalThis.Blob)return 0;}catch(e){return 0;}
 const jobs=new Map();let next=0,reserved=0;
 const valid=k=>typeof k==='string' && /^[A-Za-z0-9_.\/-]{1,128}$/.test(k);
 // Status: pending=0, success=1; errors match Browser_Store_Error + 1.
 const finish=(j,status)=>{if(!jobs.has(j.id)||j.status!==0)return;j.status=status;if(j.db){j.db.close();j.db=null;}};
 const recordValid=r=>r && Number.isSafeInteger(r.revision) && r.revision>0 && r.bytes instanceof Blob;
 globalThis.ReplayBrowserStoreV1={
  begin(namespace,key,bytes,expected,limit,reading){
   if(!valid(namespace)||!valid(key)||!Number.isSafeInteger(limit)||limit<1||limit>16777216||
      !Number.isSafeInteger(expected)||expected<0||expected>=Number.MAX_SAFE_INTEGER||
      jobs.size>=16||reserved+limit>67108864||next>=Number.MAX_SAFE_INTEGER)return 0;
   if(!reading && (typeof bytes!=='string'||bytes.length<1||bytes.length>Math.ceil(limit/3)*4))return 0;
   const j={id:++next,status:0,revision:0,buffer:null,db:null,tx:null,limit};jobs.set(j.id,j);reserved+=limit;
   // Byte/string bounds are validated before creating the owned Blob.
   try{if(!reading){const raw=atob(bytes);if(raw.length<1||raw.length>limit){finish(j,4);return j.id;}const data=new Uint8Array(raw.length);for(let i=0;i<raw.length;i++)data[i]=raw.charCodeAt(i);j.value=new Blob([data]);}}catch(e){finish(j,8);return j.id;}
   let request;
   try{request=indexedDB.open('replay/'+namespace,1);}catch(e){finish(j,6);return j.id;}
   request.onupgradeneeded=()=>request.result.createObjectStore('blobs');
   request.onblocked=()=>finish(j,6);
   request.onerror=()=>finish(j,6);
   request.onsuccess=()=>{
    if(!jobs.has(j.id)||j.status!==0){request.result.close();return;}
    j.db=request.result;j.db.onversionchange=()=>{if(j.tx)try{j.tx.abort();}catch(e){}finish(j,reading?7:8);};
    let found,problem=0;
    try{
     const tx=j.db.transaction('blobs',reading?'readonly':'readwrite',{durability:'strict'});j.tx=tx;
     tx.onabort=()=>finish(j,problem||(reading?7:8));
     tx.oncomplete=()=>{
      j.tx=null;
      if(problem){finish(j,problem);return;}
      if(!reading){j.revision=expected+1;finish(j,1);return;}
      if(found===undefined){finish(j,2);return;}
      if(!recordValid(found)){finish(j,5);return;}
      if(found.bytes.size<1||found.bytes.size>limit){finish(j,4);return;}
      found.bytes.arrayBuffer().then(buffer=>{if(!jobs.has(j.id))return;j.buffer=new Uint8Array(buffer);j.revision=found.revision;finish(j,1);},()=>finish(j,7));
     };
     const store=tx.objectStore('blobs'),get=store.get(key);
     get.onsuccess=()=>{
      found=get.result;if(reading)return;
      if(found!==undefined&&!recordValid(found)){problem=5;tx.abort();return;}
      if((found===undefined?0:found.revision)!==expected){problem=3;tx.abort();return;}
      try{store.put({revision:expected+1,bytes:j.value},key);}catch(e){problem=8;tx.abort();}
     };
    }catch(e){finish(j,reading?7:8);}
   };
   return j.id;
  },
  status(id){return jobs.get(id)?.status??7;},
  revision(id){return jobs.get(id)?.revision??0;},
  bytes(id){return jobs.get(id)?.buffer??null;},
  close(id){const j=jobs.get(id);if(!j)return 0;jobs.delete(id);reserved-=j.limit;j.value=null;j.buffer=null;if(j.tx)try{j.tx.abort();}catch(e){}if(j.db)j.db.close();return 1;}
 };
 return 1;
})()`
