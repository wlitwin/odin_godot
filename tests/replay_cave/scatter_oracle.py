"""Compile the original unmodified integer recipe beside a small print harness."""
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
s=(root/'examples/cavecrawl/scripts/world.odin').read_text();start=s.index('splitmix32 :: proc');end=s.index('\n}\n',start)+3
recipe=s[start:end]
(out/'main.odin').write_text('''package main
import "core:fmt"
'''+recipe+'''
main :: proc() {
 seeds:=[4]u32{1,1337,123456,max(u32)}
 for seed in seeds {for depth in u32(1)..=2 {
  state:=seed~(depth*0x9E3779B9);sum:=u32(0);points:[20]u32
  for i in 0..<10 {x:=splitmix32(&state)%560+30;y:=splitmix32(&state)%230+60;points[2*i],points[2*i+1]=x,y;sum=sum*31+x*7+y}
  fmt.printf("%d %d %d",seed,depth,sum);for point in points {fmt.printf(" %d",point)};fmt.println()
 }}
}
''')
