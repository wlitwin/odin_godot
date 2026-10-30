package director_oracle
import ai "godot:kit/ai"
import r "godot:replay"
import cave "godot:examples/replay_cavecrawl/shared/cave"
Scenario :: struct {name:string,counts,rests:[8]u16,waves,kill_every,kill_count,leave_at,return_at:int}
Report :: struct {mismatches,first_bad:int,old_spawns,new_spawns:[32]u64,old_count,new_count:int,old_done,new_done:bool}
CASES :: [?]Scenario{
  {name="floor1",counts={0=2,1=3},rests={0=40,1=40},waves=2,kill_every=7,kill_count=1},
  {name="floor2",counts={0=3,1=4},rests={0=100,1=60},waves=2,kill_every=7,kill_count=1},
  {name="zero_rest",counts={0=3,1=2,2=1},waves=3,kill_every=5,kill_count=8},
  {name="empty_waves",counts={0=0,1=2,2=0,3=1},rests={0=100,1=5,2=200,3=3},waves=4,kill_every=6,kill_count=4},
  {name="eight_waves",counts={0=1,1=2,2=3,3=1,4=2,5=3,6=1,7=2},rests={0=1,1=2,2=3,3=0,4=1,5=2,6=3,7=4},waves=8,kill_every=4,kill_count=1},
  {name="departed_party",counts={0=3,1=4},rests={0=10,1=10},waves=2,kill_every=5,kill_count=4,leave_at=3,return_at=100},
 }
compare :: proc(scenario:Scenario)->Report {
  defs:=cave.FLOORS;defs[0].waves=scenario.counts;defs[0].rests=scenario.rests;defs[0].wave_count=u8(scenario.waves)
  world:=cave.initial(floors=defs);world.players[0].connected=true;world.players[0].hp=cave.MAX_HP;world.players[0].position={80,120}
  waves:[8]ai.Wave;for &wave,i in waves {wave={scenario.counts[i],scenario.rests[i]}}
  original:ai.Director;spawned:=0;mismatches:=0;first_bad:=0
  events:[32]r.Occurrence(cave.Event);ctx:=r.Step(cave.Event){epoch=1,events=events[:]}
  old_spawns,new_spawns:[32]u64;old_count,new_count:=0,0
  for tick in 1..=1000 {
   world.clock=u64(tick);ctx.tick=u64(tick);ctx.count=0;ctx.error=.None
   if scenario.leave_at>0 {world.players[0].connected=tick<scenario.leave_at || tick>=scenario.return_at}
   if tick%scenario.kill_every==0 {
    old_deaths:=min(original.alive,scenario.kill_count)
    for _ in 0..<old_deaths {ai.director_note_death(&original,u64(tick),waves[:scenario.waves])}
    killed:=0
    for alive,index in world.dwellers.alive {if alive && killed<scenario.kill_count {
     for _ in 0..<2 {_,ok:=r.pool_insert(&world.rocks,cave.Rock{position=world.dwellers.values[index].position,left=1,shooter=1});assert(ok)}
     killed+=1
    }}
    cave.step_rocks(&world,&ctx);assert(ctx.error==.None)
   }
   before:=world.dwellers.count
   spawn,_:=ai.director_tick(&original,u64(tick),waves[:scenario.waves]);spawned+=spawn
   cave.step_director(&world,&ctx)
   new_spawn:=int(world.dwellers.count-before)
   if spawn>0 {old_spawns[old_count]=u64(tick);old_count+=1}
   if new_spawn>0 {new_spawns[new_count]=u64(tick);new_count+=1}
   old_rest:=original.rest_until>u64(tick) ? original.rest_until-u64(tick) : 0
   new_rest:=world.director.rest_until>u64(tick) ? world.director.rest_until-u64(tick) : 0
   if spawn!=new_spawn || original.wave!=int(world.director.wave) || original.pending!=world.director.remaining || original.alive!=int(world.dwellers.count) || original.done!=world.director.done || old_rest!=new_rest || spawned!=int(world.dens_used) {
    mismatches+=1;if first_bad==0 {first_bad=tick}
   }
  }
 return {mismatches,first_bad,old_spawns,new_spawns,old_count,new_count,original.done,world.director.done}
}
matrix_case :: proc(index:int)->Scenario {
 s:=Scenario{waves=1+index%8,kill_every=1+index%9,kill_count=1+(index/8)%4}
 for j in 0..<s.waves {s.counts[j]=u16((index/5+j*3)%5);s.rests[j]=u16((index*7+j*11)%23)}
 if index%3==0 {s.leave_at=3;s.return_at=100}
 return s
}
