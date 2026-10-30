//gd:extends Node
//gd:class ReplayBrowserStoreProbe
package replay_browser_store_probe

import gd "godot:godot"
import rgd "godot:replay/godot"
import sc "godot:replay/schema"

ReplayBrowserStoreProbe :: struct {owner:gd.Node,op:rgd.Browser_Store_Op,size:int,hash:u64,consumed:bool}
@(gd_method)
replay_browser_store_probe_begin :: proc(self:^ReplayBrowserStoreProbe,reading:bool,key:string,expected,size,pattern,limit:gd.Int)->bool {
	rgd.browser_store_close(&self.op);self.size,self.hash,self.consumed=0,0,false
	if reading {return rgd.browser_store_read(&self.op,"acceptance",key,int(limit))}
	if size<0 || size>rgd.STORAGE_LIMIT {return false}
	bytes:=make([]u8,int(size));defer delete(bytes)
	for &b,i in bytes {b=u8((i*31+int(pattern))%251)}
	return rgd.browser_store_write(&self.op,"acceptance",key,bytes,u64(expected),int(limit))
}
replay_browser_store_probe_process :: proc(self:^ReplayBrowserStoreProbe,dt:f64) {
	if rgd.browser_store_poll(&self.op)==.Complete && self.op.reading && self.op.error==.None && !self.consumed {
		bytes,err:=rgd.browser_store_bytes(&self.op);defer delete(bytes)
		self.op.error=err;self.size=len(bytes);self.hash=sc.digest(bytes)&0x7fff_ffff_ffff_ffff;self.consumed=true
	}
}
@(gd_method)
replay_browser_store_probe_probe :: proc(self:^ReplayBrowserStoreProbe,key:string)->gd.Int {
	switch key {case "phase":return gd.Int(self.op.phase);case "error":return gd.Int(self.op.error);case "revision":return gd.Int(self.op.revision);case "size":return gd.Int(self.size);case "hash":return gd.Int(self.hash)}
	return -1
}
replay_browser_store_probe_exit_tree :: proc(self:^ReplayBrowserStoreProbe) {rgd.browser_store_close(&self.op)}
