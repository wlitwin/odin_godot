"""Compile selected original pure rules in isolation; never launch or alter Scrapyard."""
from pathlib import Path
import sys

old, output = map(Path, sys.argv[1:3])
arena = (old / "scripts/arena.odin").read_text()
movement = (old / "scripts/input.odin").read_text()

def procedure(source, name):
    start = source.index(name + " ::")
    brace = source.index("{", start)
    depth = 0
    for i in range(brace, len(source)):
        depth += (source[i] == "{") - (source[i] == "}")
        if depth == 0:
            return source[start:i + 1]
    raise ValueError(name)

# The original declaration block contains the unchanged footprints/dice roll.
declarations = arena[arena.index("ARENA_W ::"):arena.index('@(private = "file")\nadd_rect ::')]
source = '''package main
import "core:fmt"
import "core:math"
import gd "godot:godot"
RUNNER_SPEED :: f32(220)
RUNNER_FOOT_R :: f32(12)
SPEED_BOOST :: f32(50)
DASH_SPEED :: f32(840)
Effect :: struct {}
Health :: struct {hp: u8}
Runner :: struct {x, y: f32, boost_speed: u8, health: Health, fx: [4]Effect}
Dash :: struct {until: f64, vx, vy: f32}
Scrapyard :: struct {covers: []Cover, dash: Dash, intent: [2]f32}
now_s :: proc() -> f64 {return 1}
run_intent :: proc(self: ^Scrapyard) -> (f32, f32) {return self.intent[0], self.intent[1]}
status_move_mult :: proc(effects: []Effect) -> f32 {return 1}
'''
source += declarations + "\n" + procedure(arena, "arena_key") + "\n" + procedure(arena, "block_cover") + "\n" + procedure(movement, "step_my_runner")
source += '''
main :: proc() {
 seeds := [4]u32{0, 1, 1337, 0xffffffff}
 floors := [3]u8{1, 2, 7}
 for seed in seeds {for floor in floors {
  covers, sum := scatter_cover(arena_key(seed, floor))
  fmt.printf("ARENA %d %d %d\\n", seed, floor, sum)
  for c in covers {fmt.printf("C %d %d %d %d %d\\n", c.kind, c.x, c.y, c.w, c.h)}
  directions := [4][2]f32{{1, 0}, {-1, 1}, {0.4, -0.7}, {0, 1}}
  for direction, scenario in directions {
   yard := Scrapyard{covers = covers, intent = direction}
   runner := Runner{x = 840, y = 544, health = {10}}
   for _ in 0 ..< 240 {step_my_runner(&yard, &runner, 1.0 / 60)}
   fmt.printf("MOVE %d %d %d\\n", scenario, transmute(u32)runner.x, transmute(u32)runner.y)
  }
 }}
}
'''
output.mkdir(parents=True, exist_ok=True)
(output / "main.odin").write_text(source)
