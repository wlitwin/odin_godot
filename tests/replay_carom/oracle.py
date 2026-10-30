"""Compile the unchanged original motion/judge expressions, without presentation."""
from pathlib import Path
import sys
old, output = map(Path, sys.argv[1:3])

def procedure(text, name):
    start=text.index(name+' ::'); brace=text.index('{',start); depth=0
    for i in range(brace,len(text)):
        depth+=(text[i]=='{')-(text[i]=='}')
        if depth==0:return text[start:i+1]
    raise ValueError(name)

combat=(old/'scripts/combat.odin').read_text()
lobber=(old/'scripts/gun_lobber.odin').read_text()
rail=(old/'scripts/gun_rail.odin').read_text()
move=procedure(lobber,'nade_step')
# Retain the exact movement block; visual nodes/trails and contact damage are
# exercised in the game tests, not stubbed out as fictitious oracle behavior.
move=move[:move.index('\tgd.node2d_set_position')]+'\n return false\n}'
old_source='''package main
import "core:fmt"
import arena "godot:examples/replay_scrapyard/shared/arena"
ARENA_W :: f32(1920)
ARENA_H :: f32(1088)
NADE_BOUNCE :: f32(0.72)
Cover :: arena.Cover
Scrapyard :: struct {covers: []Cover}
Nade :: struct {x,y,vx,vy:f32}
''' + procedure(combat,'cover_clip')+'\n'+move
new_source='''package main
import "core:fmt"
import arena "godot:examples/replay_scrapyard/shared/arena"
import p "godot:replay/play"
Scrapyard :: struct {covers: []arena.Cover}
Nade :: struct {x,y,vx,vy:f32}
nade_step :: proc(yard:^Scrapyard,n:^Nade,dt:f32)->bool {
 boxes:[arena.COVER_COUNT]p.Aabb2
 for c,i in yard.covers {boxes[i]={{f32(c.x),f32(c.y)},{f32(c.x)+f32(c.w),f32(c.y)+f32(c.h)}}}
 body:=p.Carom2{{n.x,n.y},{n.vx,n.vy}}
 assert(p.carom2_step(&body,dt,0.72,0.1,{{24,24},{1896,1064}},boxes[:]))
 n.x,n.y,n.vx,n.vy=body.position[0],body.position[1],body.velocity[0],body.velocity[1]
 return false
}
'''
old_source += '\nFire :: struct {origin: [3]f32}\n' + procedure(rail, 'beam_judge').replace('kcombat.Fire', 'Fire')
old_source += '\nbeam :: proc(from,segment,center:[2]f32,radius:f32)->(f32,bool) {return beam_judge(Fire{{from[0],from[1],0}}, {segment[0],segment[1],0}, segment[0]*segment[0]+segment[1]*segment[1], center, radius)}\n'
new_source += '\nbeam :: proc(from,segment,center:[2]f32,radius:f32)->(f32,bool) {return p.beam_circle(from,segment,center,radius)}\n'
driver='''
main :: proc() {
 beam_hash:=u64(0xcbf29ce484222325)
 for x in -4..=14 {for y in -4..=4 {for radius in 1..=3 {
  at,hit:=beam({0,0},{10,0},{f32(x),f32(y)},f32(radius))
  beam_hash=(beam_hash~u64(transmute(u32)at))*0x100000001b3
  beam_hash=(beam_hash~u64(hit))*0x100000001b3
 }}}
 fmt.printf("BEAM %d\\n",beam_hash)
 seeds:=[4]u32{0,1,1337,0xffffffff}
 steps:=[3]f32{0.5,1,2}
 starts:=[6]Nade{{25,25,-7,-7},{840,544,7,3},{400,400,20,-6},{1880,1050,8,10},{110,110,3,8},{100,100,0,0}}
 for seed in seeds {for dt in steps {for start, scenario in starts {
  layout:=arena.generate(seed,1); yard:=Scrapyard{layout.covers[:]}; n:=start
  hash:=u64(0xcbf29ce484222325)
  for _ in 0..<300 {
   nade_step(&yard,&n,dt)
   values:=[4]u32{transmute(u32)n.x,transmute(u32)n.y,transmute(u32)n.vx,transmute(u32)n.vy}
   for value in values {hash=(hash~u64(value))*0x100000001b3}
  }
  fmt.printf("CAROM %d %d %d %d\\n",seed,transmute(u32)dt,scenario,hash)
 }}}
}
'''
for name, source in [('old',old_source),('new',new_source)]:
 directory=output/name;directory.mkdir(parents=True,exist_ok=True)
 (directory/'main.odin').write_text(source+driver)
