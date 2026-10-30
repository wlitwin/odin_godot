#+build wasm32
package replay_duel
import rgd "godot:replay/godot"
duel_online_storage_open :: proc(self:^ReplayDuel,local:bool)->(rgd.Party_Storage,bool) {return {},true}
duel_online_storage_close :: proc(self:^ReplayDuel) {}
