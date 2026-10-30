"""Compare the original director procedures in isolation with Replay's values."""
from pathlib import Path
import sys
root, output = map(Path,sys.argv[1:3])
text=(root/'kit/ai/ai.odin').read_text()
def procedure(name):
 start=text.index(name+' ::');brace=text.index('{',start);depth=0
 for i in range(brace,len(text)):
  depth+=(text[i]=='{')-(text[i]=='}')
  if depth==0:return text[start:i+1]
 raise ValueError(name)
old='''package main
import "core:fmt"
Wave :: struct {count,rest:u16}
Director :: struct {wave:int,pending:u16,alive:int,rest_until:u64,done:bool}
'''+procedure('director_tick')+'\n'+procedure('director_note_death')
new='''package main
import "core:fmt"
import p "godot:replay/play"
Wave :: p.Wave
Director :: p.Director
director_tick :: proc(d:^Director,tick:u64,waves:[]Wave)->(int,bool) {n,started:=p.director_tick(d,tick,waves);return int(n),started}
director_note_death :: proc(d:^Director,tick:u64,waves:[]Wave) {assert(p.director_note_death(d,tick,waves))}
'''
driver='''
main :: proc() {
 for count in 0..=9 {for cadence in 1..=5 {
  waves:=[3]Wave{{u16(count),3},{u16(count/2),7},{u16(count+1),5}}
  d:Director;hash:=u64(0xcbf29ce484222325)
  for tick in u64(1)..=400 {
   n,started:=director_tick(&d,tick,waves[:])
   if tick%u64(cadence)==0 && d.alive>0 {director_note_death(&d,tick,waves[:])}
   values:=[7]u64{u64(n),u64(started),u64(d.wave),u64(d.pending),u64(d.alive),d.rest_until,u64(d.done)}
   for v in values {hash=(hash~v)*0x100000001b3}
  }
  fmt.printf("DIRECTOR %d %d %d\\n",count,cadence,hash)
 }}
}
'''
for name,source in [('old',old),('new',new)]:
 directory=output/name;directory.mkdir(parents=True,exist_ok=True);(directory/'main.odin').write_text(source+driver)
