package replay_godot_storage
import "core:strings"
import lb "godot:replay/lobby"
import gd "godot:godot"

Name_Profile_Phase :: enum {Ready,Reading,Writing}
Name_Profile :: struct {value:lb.Name,phase:Name_Profile_Phase,enabled,failed,dirty:bool,path,namespace:string,op:Browser_Store_Op,revision:u64}
name_profile_open :: proc(p:^Name_Profile,path,namespace:string,enabled:bool,initial:lb.Name)->bool {
	if p.path!="" || !lb.name_valid(initial,false) {return false}
	p.value,p.enabled=initial,enabled;p.path=strings.clone(path);p.namespace=strings.clone(namespace)
	if !enabled {return true}
	when gd.IS_WEB {
		if !browser_store_read(&p.op,p.namespace,"display-name",4096) {p.failed=true;return false};p.phase=.Reading
	} else {
		text:=gd.new_string_odin(path);exists:=gd.file_access_file_exists(text);gd.free_string(text)
		if exists {
			bytes,err:=storage_read(path,4096);defer delete(bytes);value,ok:=lb.profile_decode(bytes)
			if err!=.None || !ok {p.failed=true;return false};p.value=value
		} else {p.dirty=true}
	}
	return true
}
name_profile_set :: proc(p:^Name_Profile,value:lb.Name)->bool {
	if p.failed || p.phase==.Reading || !lb.name_valid(value,false) {return false}
	if p.value!=value {p.value=value;p.dirty=p.enabled};return true
}
name_profile_frame :: proc(p:^Name_Profile) {
	when gd.IS_WEB {
		if p.phase!=.Ready && browser_store_poll(&p.op)==.Complete {
			if p.phase==.Reading && p.op.error==.Missing {p.revision=0;p.dirty=true}
			else if p.op.error!=.None {p.failed=true}
			else if p.phase==.Reading {
				bytes,err:=browser_store_bytes(&p.op);defer delete(bytes);value,ok:=lb.profile_decode(bytes)
				if err!=.None || !ok {p.failed=true} else {p.value=value;p.revision=p.op.revision}
			} else {p.revision=p.op.revision}
			browser_store_close(&p.op);p.phase=.Ready
		}
	}
	if !p.enabled || p.failed || !p.dirty || p.phase!=.Ready {return}
	bytes,ok:=lb.profile_encode(p.value);if !ok {p.failed=true;return}
	when gd.IS_WEB {
		if browser_store_write(&p.op,p.namespace,"display-name",bytes[:],p.revision,4096) {p.phase=.Writing;p.dirty=false} else {p.failed=true}
	} else {
		if storage_write(p.path,bytes[:],4096)!=.None {p.failed=true} else {p.dirty=false}
	}
}
name_profile_close :: proc(p:^Name_Profile) {browser_store_close(&p.op);delete(p.path);delete(p.namespace);p^={}}
