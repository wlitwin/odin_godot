package dockyard_duo

import "core:math"
import b "godot:box3d"
import bp "godot:box3d/presentation"

// Local automated-player state, separate from the canonical game. It supplies
// ordinary controls from copied presentation, and never changes physics/score.
Carry_Stage :: enum u8 {Align,Haul,Park}
Carry_Controller :: struct{round:u32,cargo:i32,stage:Carry_Stage,nav:u8}

scripted_control :: proc(self:^DockyardDuo,_:u64,seat:u16)->Control{
 if !self.have_presentation||seat<1||seat>2{return {}}
 controller:=Carry_Controller{self.carry_round,self.carry_cargo,Carry_Stage(self.carry_stage),self.carry_nav}
 result:=suggest_control(current_game(self),self.presentation_value,seat,&controller)
 self.carry_round=controller.round;self.carry_cargo=controller.cargo;self.carry_stage=u8(controller.stage);self.carry_nav=controller.nav
 return result
}
drive_to :: proc(robot,target:b.Vec3)->Control{
 dx,dz:=target.x-robot.x,target.z-robot.z;distance:=math.sqrt(dx*dx+dz*dz)
 if distance<.01{return {}}
 return {x=i16(clamp(dx/distance*100,-100,100)),z=i16(clamp(dz/distance*100,-100,100))}
}
suggest_control :: proc(game:Game,frame:bp.Frame,seat:u16,controller:^Carry_Controller)->Control{
 if seat<1||seat>2||game.phase!=.Working||controller==nil{return {}}
 frame:=frame;pads:=CARGO_PADS
 cargo_index:=-1;for i in 0..<3{if !game.delivered[i]&&!game.lost[i]{cargo_index=i;break}};if cargo_index<0{return {}}
 lane_z:=cargo_index==2?f32(0):f32(1)
 robot,cargo:b.Vec3;have_robot,have_cargo:bool
 for row in frame.rows[:frame.count]{
  if row.body==bp.Body_Key(game.bodies[seat]){robot=b.Vec3{row.pose.position[0],row.pose.position[1],row.pose.position[2]};have_robot=true}
  if row.body==bp.Body_Key(game.bodies[cargo_index+3]){cargo=b.Vec3{row.pose.position[0],row.pose.position[1],row.pose.position[2]};have_cargo=true}
 }
 if !have_robot||!have_cargo{return {}}
 if controller.round!=game.round||controller.cargo!=i32(cargo_index){
  controller^={round=game.round,cargo=i32(cargo_index),nav=robot.x>2.4?u8(1):u8(0)}
  if cargo.x>3.4{controller.stage=.Park}else if abs(cargo.z-lane_z)<.45{controller.stage=.Haul}
 }
 // Return along the empty front aisle and off the ramp before turning toward
 // another load. Persistent stages avoid switching direction at one threshold.
 if controller.nav==1{
  if abs(robot.z-3.1)<.2{controller.nav=2}else{return drive_to(robot,{robot.x,0,3.1})}
 }
 if controller.nav==2{
  if robot.x< -4.3{controller.nav=0}else{return drive_to(robot,{-4.8,0,3.1})}
 }
 pad:=pads[cargo_index]
 if controller.stage==.Align{
  if abs(cargo.z-lane_z)<.4{controller.stage=.Haul}
  else{
   staging_x:=cargo_index==2?f32(-4.8):f32(-3.8)
   pad=cargo.x>staging_x?b.Vec3{staging_x-.6,0,cargo.z}:b.Vec3{cargo.x,0,lane_z}
  }
 }
 if controller.stage==.Haul{
  if cargo.x>(cargo_index==2?f32(3.9):f32(3.3)){controller.stage=.Park}else{pad={5,0,lane_z}}
 }
 if controller.stage==.Park{pad=pads[cargo_index]}
 dx,dz:=pad.x-cargo.x,pad.z-cargo.z;distance:=math.sqrt(dx*dx+dz*dz)
 if distance<.2{return {}}
 ux,uz:=dx/distance,dz/distance
 side:=seat==1?f32(-.65):f32(.65)
 rx,rz:=robot.x-cargo.x,robot.z-cargo.z
 lead:=rx*ux+rz*uz
 lateral:=clamp((side-(-rx*uz+rz*ux))*80,f32(-80),f32(80))
 half_x:=cargo_index==2?f32(1.4):f32(.6);half_z:=cargo_index==2?f32(.5):f32(.6)
 lead_target:=max(f32(1.6),half_x*abs(ux)+half_z*abs(uz)+.95)
 feed:=controller.stage==.Park?clamp(distance*80,f32(20),f32(100)):f32(100)
 forward:=clamp(feed+(lead_target-lead)*200,f32(-100),f32(100))
 return {x=i16(clamp(ux*forward-uz*lateral,-100,100)),z=i16(clamp(uz*forward+ux*lateral,-100,100)),aim_x=i16(clamp(cargo.x*100,-1400,1400)),aim_y=i16(clamp(cargo.y*100,-1000,1000)),aim_z=i16(clamp(cargo.z*100,-1400,1400)),grab=true}
}
