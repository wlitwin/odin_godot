"""Isolate original stack/expiry/telegraph procedures; never launch a baseline game."""
from pathlib import Path
import sys
root, old, output = map(Path, sys.argv[1:4])

def procedure(text, name):
    start=text.index(name+' ::'); brace=text.index('{',start); depth=0
    for i in range(brace,len(text)):
        depth+=(text[i]=='{')-(text[i]=='}')
        if depth==0:return text[start:i+1]
    raise ValueError(name)

original='''package main
import "core:fmt"
Effect :: struct {kind:u8,power:i8,left:u16}
Status_Row :: struct {max_stacks:u8}
EFFECT_NONE :: u8(0)
Telegraph :: struct {left,wind:u16}
'''
original += procedure((old/'scripts/combat.odin').read_text(),'status_stack').replace('kcombat.Effect','Effect').replace('kcombat.EFFECT_NONE','EFFECT_NONE')
original += '\n'+procedure((root/'kit/combat/combat.odin').read_text(),'effects_tick')
telegraph=(root/'play/telegraph.odin').read_text()
for name in ['telegraph_start','telegraph_tick','telegraph_cancel','telegraph_frac']:
 original += '\n'+procedure(telegraph,name)
new='''package main
import "core:fmt"
import p "godot:replay/play"
Effect :: p.Effect
Telegraph :: p.Telegraph
Status_Row :: struct {max_stacks:u8}
status_stack :: proc(fx:[]Effect,kind:u8,st:Status_Row,duration:u16)->bool {_,ok:=p.effect_stack(fx,kind,st.max_stacks,duration);return ok}
effects_tick :: p.effects_tick
telegraph_start :: p.telegraph_start
telegraph_tick :: p.telegraph_tick
telegraph_cancel :: p.telegraph_cancel
telegraph_frac :: proc(t:^Telegraph)->f32 {return p.telegraph_fraction(t^)}
'''
driver='''
main :: proc() {
 caps:=[3]u8{1,3,9}; durations:=[3]u16{30,60,240}
 for cap in caps {for duration in durations {
  effects:[4]Effect; tele:Telegraph
  hash:=u64(0xcbf29ce484222325)
  for tick in 0..<4096 {
   effects_tick(effects[:])
   if tick%3==0 {
    ok:=status_stack(effects[:],u8(tick%5+1),Status_Row{cap},duration)
    hash=(hash~u64(ok))*0x100000001b3
   }
   if tick%101==0 {telegraph_start(&tele,48)}
   if tick%107==0 {telegraph_cancel(&tele)}
   landed:=telegraph_tick(&tele)
   values:=[4]u64{u64(tele.left),u64(tele.wind),u64(landed),u64(transmute(u32)telegraph_frac(&tele))}
   for value in values {hash=(hash~value)*0x100000001b3}
   for e in effects {for value in ([3]u64{u64(e.kind),u64(e.power),u64(e.left)}) {hash=(hash~value)*0x100000001b3}}
  }
  fmt.printf("EFFECTS %d %d %d\\n",cap,duration,hash)
 }}
}
'''
for name,source in [('old',original),('new',new)]:
 directory=output/name;directory.mkdir(parents=True,exist_ok=True)
 (directory/'main.odin').write_text(source+driver)
