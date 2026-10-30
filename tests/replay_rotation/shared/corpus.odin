package rotation_corpus

import "core:math"
import "core:math/linalg"
import v "godot:replay/view"

near :: proc(a,b:f32)->bool {return abs(a-b)<0.0001}
orientation :: proc(a,b:[4]f32)->bool {return abs(abs(linalg.dot(a,b))-1)<0.0001}
yaw :: proc(angle:f32)->[4]f32 {return {0,math.sin(angle/2),0,math.cos(angle/2)}}
pitch :: proc(angle:f32)->[4]f32 {return {math.sin(angle/2),0,0,math.cos(angle/2)}}
product :: proc(a,b:[4]f32)->[4]f32 {
 // Independent test composition through linalg's quaternion implementation.
 return transmute([4]f32)((transmute(quaternion128)a)*(transmute(quaternion128)b))
}
verify :: proc()->u32 {
 s:v.Smoother2;before:=v.Pose2{angle=math.PI-0.1};after:=v.Pose2{position={4,0},angle=-math.PI+0.1}
 v.smooth_present(&s,before,0)
 if !v.smooth_correct_pose(&s,before,after) {return 1}
 shown:=v.smooth_present(&s,after,0)
 if !near(v.angle_delta(before.angle,shown.angle),0) || shown.position!=before.position {return 2}
 shown=v.smooth_present(&s,after,0.08)
 if !near(shown.position[0],2) || !near(v.angle_delta(after.angle,shown.angle),-0.1) {return 3}
 moving:=after;moving.position[0]+=1;moving.angle+=0.2
 shown=v.smooth_present(&s,moving,0)
 if !near(shown.position[0],3) || !near(v.angle_delta(after.angle,shown.angle),0.1) {return 4}
 next:=moving;next.angle+=0.1
 if !v.smooth_correct_pose(&s,moving,next) {return 5}
 repeated:=v.smooth_present(&s,next,0)
 if !near(v.angle_delta(shown.angle,repeated.angle),0) {return 6}
 if !v.smooth_correct_pose(&s,next,v.Pose2{angle=next.angle+2}) {return 7}
 cut:=v.smooth_present(&s,{angle=next.angle+2},0)
 if cut.position!=([2]f32{}) || cut.angle!=next.angle+2 {return 8}
 saved:=s;bad:=next;bad.angle=transmute(f32)u32(0x7fc00000)
 if v.smooth_correct_pose(&s,next,bad) || s!=saved {return 9}
 if v.smooth_present(&s,next,transmute(f64)u64(0x7ff8000000000000))!=saved.shown || s!=saved {return 10}
 if v.smooth_present(&s,next,0.1,transmute(f64)u64(0x7ff0000000000000))!=saved.shown || s!=saved {return 11}

 a:=v.Pose3{rotation={0,0,0,1}};b:=v.Pose3{position={1,0,0},rotation=yaw(1.2)}
 smooth:v.Smoother3;v.smooth3_present(&smooth,a,0)
 if !v.smooth3_correct_pose(&smooth,a,b) {return 12}
 q:=v.smooth3_present(&smooth,b,0)
 if q.position!=a.position || !orientation(q.rotation,a.rotation) {return 13}
 q=v.smooth3_present(&smooth,b,0.08)
 if !near(q.position[0],0.5) || !orientation(q.rotation,yaw(0.6)) {return 14}
 motion:=b;motion.rotation=yaw(1.5);motion.position[0]=1.5
 old:=v.smooth3_present(&smooth,motion,0)
 corrected:=motion;corrected.rotation=product(pitch(0.4),motion.rotation)
 if !v.smooth3_correct_pose(&smooth,motion,corrected) {return 15}
 q=v.smooth3_present(&smooth,corrected,0)
 if !orientation(q.rotation,old.rotation) || q.position!=old.position {return 16}
 opposite:=corrected;opposite.rotation=-opposite.rotation
 if !v.smooth3_correct_pose(&smooth,corrected,opposite) {return 17}
 q=v.smooth3_present(&smooth,opposite,0)
 if !orientation(q.rotation,old.rotation) {return 18}
 once,many:=smooth,smooth
 one:=v.smooth3_present(&once,corrected,0.08)
 multi:v.Pose3;for _ in 0..<8 {multi=v.smooth3_present(&many,corrected,0.01)}
 if !orientation(one.rotation,multi.rotation) || !near(one.position[0],multi.position[0]) {return 19}
 previous:=smooth;invalid:=corrected;invalid.rotation={}
 if v.smooth3_correct_pose(&smooth,corrected,invalid) || smooth!=previous {return 20}
 if !v.smooth3_correct_pose(&smooth,corrected,corrected,discontinuity=true) {return 21}
 q=v.smooth3_present(&smooth,corrected,0)
 if q!=corrected {return 22}
 // q and -q at the 180-degree tie must choose the same correction path.
 p1,p2:v.Smoother3;v.smooth3_present(&p1,a,0);v.smooth3_present(&p2,a,0)
 half_turn:=v.Pose3{rotation={1,0,0,0}};negative:=half_turn;negative.rotation=-negative.rotation
 if !v.smooth3_correct_pose(&p1,a,half_turn,angle_cut=4) || !v.smooth3_correct_pose(&p2,a,negative,angle_cut=4) {return 23}
 r1:=v.smooth3_present(&p1,half_turn,0.08);r2:=v.smooth3_present(&p2,negative,0.08)
 if !orientation(r1.rotation,r2.rotation) || !orientation(r1.rotation,pitch(-math.PI/2)) {return 24}
 // Rebase preserves the displayed angle across the wrap boundary too.
 rebased:v.Smoother2;v.smooth_present(&rebased,before,0);v.smooth_rebase(&rebased,after)
 rebased_pose:=v.smooth_present(&rebased,after,0)
 if !near(v.angle_delta(before.angle,rebased_pose.angle),0) {return 25}
 v.smooth_rebase(&rebased,after,angle_cut=0)
 if v.smooth_present(&rebased,after,0)!=after {return 26}
 large:=v.Pose3{position={1,0,0},rotation=yaw(2.2)}
 if !v.smooth3_correct_pose(&smooth,corrected,large,angle_cut=0) {return 27}
 if v.smooth3_present(&smooth,large,0)!=large {return 28}
 if !v.smooth3_correct_pose(&smooth,large,b,angle_cut=4) {return 29}
 if v.smooth3_present(&smooth,b,0,0)!=b {return 30}
 return 0
}
