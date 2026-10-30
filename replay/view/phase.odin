package replay_view

import "core:math"

// A render fraction tied to an actual retained simulation head. It cannot wrap
// backward when a runner consumes clock time without advancing (prediction stall).
Tick_Phase :: struct {epoch,revision,tick:u64,hz:u32,fraction:f32,ready:bool}

tick_phase :: proc(p:^Tick_Phase,epoch,revision,tick:u64,clock_fraction:f32,dt:f64,hz:u32,live:bool=true)->bool {
 if epoch==0 || hz==0 || hz>1000 || dt<0 || math.is_nan(dt) || math.is_inf(dt) ||
    math.is_nan(clock_fraction) || math.is_inf(clock_fraction) || clock_fraction<0 || clock_fraction>1 {return false}
 if p.ready && epoch<p.epoch {return false}
 if !p.ready || epoch!=p.epoch || revision!=p.revision {
  p^={epoch=epoch,revision=revision,tick=tick,hz=hz,fraction=live ? clock_fraction : 0,ready=true};return true
 }
 if tick<p.tick || hz!=p.hz {return false}
 if tick>p.tick {p.tick=tick;p.fraction=live ? clock_fraction : 0;return true}
 if live {
  // Clamp before multiplication: even a finite, enormous dt stays bounded.
  elapsed:=f32(min(dt,1/f64(hz))*f64(hz))
  p.fraction=min(f32(1),max(clock_fraction,p.fraction+elapsed))
 }
 return true
}

// A visual-only linear preview, bounded to one tick and an optional contact
// fraction. It neither integrates a body nor asserts a gameplay collision.
linear_preview2 :: proc(position,step:[2]f32,fraction:f32,stop:f32=1)->([2]f32,bool) {
 for value in position {if math.is_nan(value) || math.is_inf(value) {return position,false}}
 for value in step {if math.is_nan(value) || math.is_inf(value) {return position,false}}
 if math.is_nan(fraction) || math.is_inf(fraction) || math.is_nan(stop) || math.is_inf(stop) {return position,false}
 result:=position+step*min(clamp(fraction,0,1),clamp(stop,0,1))
 for value in result {if math.is_nan(value) || math.is_inf(value) {return position,false}}
 return result,true
}
