"""Run unchanged original gun procedures in isolation alongside the Replay FSM."""
from pathlib import Path
import re
import sys

root, work = map(Path, sys.argv[1:3])
original = (root / 'play/gun.odin').read_text().replace('package play', 'package main', 1)
original = re.sub(r'^@\(gd_command[^\n]*\)\n', '', original, flags=re.M)
driver = '''
main :: proc() {
 defs := [4]Gun_Def{{mag=1, reload_ticks=3, jam_per_mille=1000, jam_taps=2}, {mag=8, reload_ticks=72, jam_per_mille=12, jam_taps=3}, {mag=20, reload_ticks=108, jam_per_mille=30, jam_taps=3}, {mag=4, reload_ticks=96, jam_per_mille=0, jam_taps=3}}
 salts := [4]u32{0, 42, 2654435761, 0xffffffff}
 for d, di in defs {for salt in salts {
  g: Gun; gun_equip(&g, d, salt)
  hash := u64(0xcbf29ce484222325)
  for tick in 0 ..< 4096 {
   gun_tick(&g)
   for pull in 0 ..< (tick % 4) {
    gun_fire(&g, 1, 0, 0, 0)
    values := [7]u64{u64(g.ammo), u64(g.mode), u64(g.reload_cd), u64(g.taps), u64(g.salt), u64(g.spent), u64(g.pull)}
    for v in values {hash = (hash ~ v) * 0x100000001b3}
   }
  }
  fmt.printf("GUN %d %d %d\\n", di, salt, hash)
 }}
}
'''
new = '''package main
import "core:fmt"
import p "godot:replay/play"
Gun_Def :: p.Gun_Def
Gun :: struct {using state: p.Gun_State, def: Gun_Def, reload_cd: u16, pull: p.Gun_Pull}
gun_equip :: proc(g: ^Gun, d: Gun_Def, salt: u32) {g.def=d; assert(p.gun_equip(&g.state,d,salt)==.None)}
gun_tick :: proc(g: ^Gun) {assert(p.gun_tick(&g.state,g.def)==.None); g.reload_cd=g.reload_left}
gun_fire :: proc(g: ^Gun, dx,dy,ox,oy:f32) {v:=p.gun_pull(&g.state,g.def); assert(v.error==.None); g.pull=v.pull; g.reload_cd=g.reload_left}
'''
for name, source in [('old', original.replace('package main', 'package main\nimport "core:fmt"', 1)), ('new', new)]:
    directory = work / name
    directory.mkdir(parents=True, exist_ok=True)
    (directory / 'main.odin').write_text(source + driver)
