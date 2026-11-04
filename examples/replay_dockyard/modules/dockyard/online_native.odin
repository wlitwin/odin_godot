#+build darwin, linux
package dockyard_duo

import gd "godot:godot"
import meter "godot:box3d/godot/meter"
import adapter "godot:replay/godot/provision_sqlite"
import rgd "godot:replay/godot"

online_native_init :: proc(self:^DockyardDuo,local:bool)->(rgd.Party_Storage,bool){
 allocator:=meter.allocator(self.scope);context.allocator=allocator;o:=&self.state.online
 store:=new(adapter.Party_Store,allocator);if store==nil{return {},false};o.native=store
 path:=gd.new_string_odin(gd.launch_param("DOCKYARD_ROOMS_DB","", "user://dockyard-rooms.sqlite3"));defer gd.free_string(path)
 absolute:=gd.project_settings_globalize_path(gd.singleton_project_settings(),path);defer gd.free_string(absolute)
 if !adapter.party_store_open(store,gd.gd_string_to_odin(absolute),o.content,true,local){return {},false}
 ca:=gd.launch_param("DOCKYARD_ROOM_CA","")
 if ca!=""{
  cert:=gd.new_x509_certificate();gd.ref_counted_init_ref(cert);defer gd.release_ref(cert)
  name:=gd.new_string_odin(ca);defer gd.free_string(name)
  if gd.x509_certificate_load(cert,name)!=.Ok{return {},false}
  o.tls=gd.tls_options_client(cert,gd.string_empty())
 }
 return adapter.party_storage(store),true
}
online_native_close :: proc(self:^DockyardDuo){
 o:=&self.state.online
 if o.native!=nil{store:=cast(^adapter.Party_Store)o.native;adapter.party_store_close(store);free(store);o.native=nil}
}
