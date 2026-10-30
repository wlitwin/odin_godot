package replay_scrapyard

import gd "godot:godot"
import "godot:gdext"
import "core:fmt"
import a "godot:replay/assets"
import game "../shared/game"
import scenegd "godot:replay/godot/scene"
import storagegd "godot:replay/godot/storage"

web_spray_pick :: proc() {
	when gd.IS_WEB {
		code := gd.new_string_odin(
			`(()=>{
   const old=document.getElementById('replay-spray-picker');if(old)old.remove();
   const input=document.createElement('input');input.type='file';input.accept='image/png';input.id='replay-spray-picker';input.style.display='none';
   input.onchange=async()=>{try{
    const file=input.files[0];if(!file)return;
    if(file.size<1||file.size>131072)throw new Error('Choose a PNG up to 128 KiB.');
    globalThis.replayScrapSpray=new Uint8Array(await file.arrayBuffer());
   }catch(e){globalThis.replayScrapSprayError=String(e);}};
   document.body.appendChild(input);input.click();return 0;
  })()`,
		)
		defer gd.free_string(code)
		value := gd.java_script_bridge_eval(gd.singleton_java_script_bridge(), code, true)
		gd.variant_destroy(&value)
	}
}

web_spray_poll :: proc(self: ^ReplayScrapyard) {
	when gd.IS_WEB {
		js := gd.singleton_java_script_bridge()
		code := gd.new_string_odin(
			"globalThis.replayScrapSprayError ? -1 : (globalThis.replayScrapSpray ? globalThis.replayScrapSpray.byteLength : 0)",
		)
		defer gd.free_string(code)
		value := gd.java_script_bridge_eval(js, code, true)
		defer gd.variant_destroy(&value)
		count := gd.variant_to_float(&value)
		if count == 0 {
			return
		}
		clear_code := gd.new_string_odin("globalThis.replayScrapSpray=null;globalThis.replayScrapSprayError=null;0")
		defer gd.free_string(clear_code)
		defer {
			v := gd.java_script_bridge_eval(js, clear_code, true)
			gd.variant_destroy(&v)
		}
		if !(count > 0 && count <= f64(game.SPRAY_MAX)) {
			self.spray_local[0].error = true
			self.spray_local[0].notice_until = gd.time_get_ticks_msec(gd.singleton_time()) + 3000
			return
		}
		name := gd.new_string_odin("replayScrapSpray")
		defer gd.free_string(name)
		object := gd.java_script_bridge_get_interface(js, name)
		if object == nil {
			return
		}
		defer if gd.ref_counted_unreference(object) {
			gdext.object_destroy(object)
		}
		if !gd.java_script_bridge_is_js_buffer(js, object) {
			return
		}
		bytes := gd.java_script_bridge_js_buffer_to_packed_byte_array(js, object)
		defer gd.free_packed_byte_array(bytes)
		// This is explicit local file selection; normal PNG validation and asset
		// admission still run. Browser persistence is separate from network caching.
		if self.local_profile[0].enabled {
			web_spray_save(self, gd.packed_byte_array_view(&bytes))
		} else {
			spray_adopt(self, gd.packed_byte_array_view(&bytes), false)
		}
	}
}

Browser_Spray_Phase :: enum {
	Idle,
	Loading,
	Checking,
	Writing,
}

Browser_Spray :: struct {
	phase: Browser_Spray_Phase,
	op: storagegd.Browser_Store_Op,
	revision: u64,
	known: bool,
	bytes: []u8,
	pinned: a.Ref,
}

web_spray_error :: proc(self: ^ReplayScrapyard) {
	local := &self.spray_local[0]
	web := &local.web
	gd.print_str(fmt.tprintf("RSY_SPRAY_BAD storage=%v", web.op.error))
	storagegd.browser_store_close(&web.op)
	delete(web.bytes)
	web.bytes = nil
	web.phase = .Idle
	if web.pinned != (a.Ref{}) {
		a.cache_unpin(&self.assets[0].cache, web.pinned)
		web.pinned = {}
	}
	local.error = true
	local.notice_until = gd.time_get_ticks_msec(gd.singleton_time()) + 3000
}

web_spray_load :: proc(self: ^ReplayScrapyard) {
	web := &self.spray_local[0].web
	if web.phase != .Idle {
		return
	}
	if !storagegd.browser_store_read(
		&web.op,
		browser_data_namespace(self),
		browser_data_key(self, "spray"),
		game.SPRAY_MAX,
	) {
		web_spray_error(self)
		return
	}
	web.phase = .Loading
}

web_spray_write :: proc(self: ^ReplayScrapyard) -> bool {
	web := &self.spray_local[0].web
	if !storagegd.browser_store_write(
		&web.op,
		browser_data_namespace(self),
		browser_data_key(self, "spray"),
		web.bytes,
		web.revision,
		game.SPRAY_MAX,
	) {
		web_spray_error(self)
		return false
	}
	web.phase = .Writing
	return true
}

web_spray_save :: proc(self: ^ReplayScrapyard, bytes: []u8) -> bool {
	web := &self.spray_local[0].web
	if web.phase != .Idle {
		return false
	}
	if !scenegd.asset_png_valid(nil, {}, bytes) {
		web.op.error = .Corrupt
		web_spray_error(self)
		return false
	}
	ref, err := a.cache_put(&self.assets[0].cache, bytes)
	if err != .None || a.cache_pin(&self.assets[0].cache, ref) != .None {
		web.op.error = .Size
		web_spray_error(self)
		return false
	}
	web.pinned = ref
	web.bytes = make([]u8, len(bytes))
	copy(web.bytes, bytes)
	if web.known {
		return web_spray_write(self)
	}
	if !storagegd.browser_store_read(
		&web.op,
		browser_data_namespace(self),
		browser_data_key(self, "spray"),
		game.SPRAY_MAX,
	) {
		web_spray_error(self)
		return false
	}
	web.phase = .Checking
	return true
}

web_spray_store_poll :: proc(self: ^ReplayScrapyard) {
	when gd.IS_WEB {
		local := &self.spray_local[0]
		web := &local.web
		if web.phase == .Idle || storagegd.browser_store_poll(&web.op) != .Complete {
			return
		}
		phase := web.phase
		if phase == .Loading || phase == .Checking {
			if web.op.error != .None && web.op.error != .Missing {
				web_spray_error(self)
				return
			}
			web.revision = web.op.error == .Missing ? 0 : web.op.revision
			web.known = true
			if phase == .Loading && web.op.error == .None {
				bytes, err := storagegd.browser_store_bytes(&web.op)
				defer delete(bytes)
				if err != .None {
					web.op.error = err
					web_spray_error(self)
					return
				}
				if !spray_adopt(self, bytes, false) {
					web.op.error = .Corrupt
					web_spray_error(self)
					return
				}
			}
			storagegd.browser_store_close(&web.op)
			web.phase = .Idle
			if phase == .Checking {
				web_spray_write(self)
			}
			return
		}
		if web.op.error != .None {
			web_spray_error(self)
			return
		}
		web.revision = web.op.revision
		if !spray_adopt(self, web.bytes, false) {
			web.op.error = .Corrupt
			web_spray_error(self)
			return
		}
		delete(web.bytes)
		web.bytes = nil
		storagegd.browser_store_close(&web.op)
		web.phase = .Idle
		if web.pinned != (a.Ref{}) {
			a.cache_unpin(&self.assets[0].cache, web.pinned)
			web.pinned = {}
		}
		gd.print_str(fmt.tprintf("RSY_SPRAY_SAVED revision=%d bytes=%d", web.revision, local.ref.bytes))
	}
}
