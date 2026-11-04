#+build freestanding, wasm32
package dockyard_duo
import rgd "godot:replay/godot"
online_native_init :: proc(self:^DockyardDuo,local:bool)->(rgd.Party_Storage,bool){return {},true}
online_native_close :: proc(self:^DockyardDuo){}
