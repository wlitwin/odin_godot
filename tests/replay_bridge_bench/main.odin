package main
import "core:fmt"
import "core:time"
import r "godot:replay"
import sc "godot:replay/schema"
import hello "../../examples/replay_hello/shared/hello"
import scrap "../../examples/replay_scrapyard/shared/game"

Display :: struct {positions:[2][2]f32,count:u32,tick:u64}
sink:u64
small_step :: proc(w:^hello.World,input:u8,ctx:^r.Step(hello.Event)) {control:hello.Input;control.players[0].move[0]=i8(input);hello.step(w,control,ctx)}
small_display :: proc(w:hello.World)->Display {return {count=w.actors.count,tick=u64(w.shots)}}
large_step :: proc(w:^scrap.World,input:u8,ctx:^r.Step(scrap.Event)) {
    controls:[scrap.SEATS]scrap.Control
    controls[0]={move={input==0 ? f32(-1) : f32(1),0},aim={1,0},fire=true}
    scrap.step(w,controls,0,0,ctx)
}
large_display :: proc(w:scrap.World)->Display {return {positions={w.players[0].position,w.players[1].position},count=w.mobs.count,tick=w.clock}}

// Let the optimizer inline ordinary public reads/project calls, just as in a
// presentation caller. No forced aggregate copy or no-inline baseline handicap.
bench :: proc(name:string,initial:$State,step:proc(^State,u8,^r.Step($Event)),projector:proc(State)->Display) {
    timeline:r.Timeline(State,u8,Event)
    assert(r.init(&timeline,r.Frame(State){state=initial},step,cfg={64,64})==.None);defer r.destroy(&timeline)
    for i in 0..<64 {assert(r.advance(&timeline,u8(i%2)).error==.None)}
    codec:sc.Schema;assert(sc.init(&codec,State).error==.None);defer sc.destroy(&codec)
    bytes:=make([]u8,codec.wire_size);defer delete(bytes)
    frame,_:=r.current(&timeline);assert(sc.encode(&codec,frame.state,bytes).error==.None)
    public:sc.Schema;options:=sc.DEFAULT_OPTIONS;options.projection=.Public
    assert(sc.init(&public,State,options).error==.None);defer sc.destroy(&public)
    public_bytes:=make([]u8,public.wire_size);defer delete(public_bytes)
    assert(sc.encode(&public,frame.state,public_bytes).error==.None)
    copies:=make([]r.Frame(State),64);defer delete(copies)
    hash:=sc.digest(bytes)
    fmt.printf("SHAPE name=%s state=%d display=%d canonical=%d public=%d history=%d scratch=%d hash=%d\n",name,size_of(State),size_of(Display),codec.wire_size,public.wire_size,len(timeline.records)*size_of(timeline.records[0]),len(timeline.staged)*size_of(timeline.staged[0]),hash)
    for trial in 0..<6 {
        for order in 0..<9 {
            mode:=(order+trial)%9;iterations:=mode<2 ? 5000 : mode<4 || mode>=6 ? 500 : 64
            began:=time.tick_now()
            for i in 0..<iterations {
                switch mode {
                case 0:
                    frame,ok:=r.read(&timeline,timeline.head-u64(i%16));assert(ok)
                    value:=projector(frame.state);sink+=u64(value.count)+value.tick
                case 1:
                    value,error:=r.project(&timeline,timeline.head-u64(i%16),projector);assert(error==.None)
                    sink+=u64(value.count)+value.tick
                case 2:
                    report:=sc.encode(&codec,frame.state,bytes);assert(report.error==.None);sink+=u64(bytes[i%len(bytes)])
                case 3:sink+=sc.digest(bytes)
                case 4:
                    result:=r.advance(&timeline,u8(i%2));assert(result.error==.None);sink+=result.tick
                case 7:
                    report:=sc.encode(&public,frame.state,public_bytes);assert(report.error==.None);sink+=u64(public_bytes[i%len(public_bytes)])
                case 8:sink+=sc.digest(public_bytes)
                case 6:
                    value,ok:=r.read(&timeline,timeline.head-u64(i%16));assert(ok);copies[i%len(copies)]=value
                case 5:
                    first:=timeline.head-15;input,ok:=r.read_input(&timeline,first);assert(ok)
                    result:=r.revise_input(&timeline,first,input);assert(result.error==.None && result.steps==16);sink+=result.tick
                }
            }
            elapsed:=time.tick_since(began)
            if trial>0 {fmt.printf("COST name=%s trial=%d mode=%d iterations=%d ns=%d\n",name,trial,mode,iterations,i64(elapsed))}
        }
    }
    for copy in copies {assert(sc.encode(&codec,copy.state,bytes).error==.None);sink+=sc.digest(bytes)}
    final,_:=r.current(&timeline);assert(sc.encode(&codec,final.state,bytes).error==.None)
    assert(r.audit(&timeline,timeline.head).error==.None)
    fmt.printf("FINAL name=%s tick=%d hash=%d\n",name,timeline.head,sc.digest(bytes))
}
main :: proc() {
    bench("hello",hello.initial(),small_step,small_display)
    world:=scrap.initial(encounter_count=0)
    world.rules=scrap.RUN_RULES;world.rules.base_count,world.rules.growth,world.rules.wave_count,world.rules.barrels=0,0,1,0
    world.catalog.mobs[0].bite=0;world.catalog.guns[0].mechanism.mag=255;world.catalog.guns[0].mechanism.jam_per_mille=0
    events:[64]r.Occurrence(scrap.Event);ctx:=r.Step(scrap.Event){epoch=1,tick=0,events=events[:]}
    scrap.step(&world,[scrap.SEATS]scrap.Control{},3,0,&ctx)
    for seat in u16(1)..=2 {
        assert(scrap.action(&world,seat,scrap.Action{kind=.Profile,profile={name=scrap.name("bridge"),abilities={1,2}}},&ctx))
        assert(scrap.action(&world,seat,scrap.Action{kind=.Ready,ready=true},&ctx))
    }
    assert(scrap.action(&world,1,scrap.Action{kind=.Start},&ctx))
    for i in 0..<40 {ctx.count=0;assert(scrap.action(&world,1,scrap.Action{kind=.Dev_Spawn,item=0,slot=1,aim={f32(100+i%5*24),f32(i/5*28-98)}},&ctx))}
    bench("scrapyard",world,large_step,large_display)
    fmt.printf("REPLAY_BRIDGE_BENCH_OK sink=%d\n",sink)
}
