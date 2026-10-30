package nodes_probe
import "core:math"
import gd "godot:godot"
import own "godot:replay/owned"
import rgd "godot:replay/godot"
when !LEGACY {
Body_World :: struct {two:own.State(own.Pose2),three:own.State(own.Pose3)}
body_check :: proc(self:^ReplayNodesProbe) {
    {
    node:=gd.new_rigid_body2d();gd.add_child(self.owner,node);defer gd.node_queue_free(node)
    skin:=gd.new_node2d();gd.add_child(node,skin);gd.node2d_set_position(skin,{10,20})
    simulation:rgd.Simulation_Body2
    assert(rgd.simulation_body2_attach(&simulation,node,.Rigid,skin))
    assert(rgd.simulation_body2_present(&simulation,{1,0},{position={10,20},angle=.25})==.None)
    assert(gd.rigid_body2d_is_freeze_enabled(node) && gd.node2d_get_global_position(node)==(gd.Vector2{10,20}))
    assert(gd.node2d_get_position(skin)==(gd.Vector2{10,20})) // authored offset stays intact
    assert(rgd.simulation_body2_present(&simulation,{1,0},{position={0=math.inf_f32(1)},angle=.25})==.Invalid_Value)
    assert(rgd.simulation_body2_present(&simulation,{2,0},{position={10,20},angle=.25},1)==.None)
    assert(rgd.simulation_body2_present(&simulation,{1,0},{position={10,20},angle=.25})==.Invalid_Epoch)
    rgd.simulation_body2_destroy(&simulation)

    body:rgd.Body2;assert(rgd.body2_attach(&body,node,.Rigid,skin));defer rgd.body2_destroy(&body)
    session:rgd.Session(Body_World,u8,u8,u8,1)
    session.ready=true;session.client.phase=.Running;session.client.seat=1;session.client.cfg.epoch=1
    state:=&session.client.authority_frame.state.two
    rules:=own.Rules(own.Pose2){valid=proc(_:rawptr,value:own.Pose2)->bool{return true}}
    assert(own.init(state,{1,0,1},1,0,2,own.Pose2{position={10,20}},rules)==.None)
    selector:=proc(_:rawptr,world:Body_World)->(own.State(own.Pose2),bool){return world.two,true}
    result:=rgd.session_body2_frame(&session,&body,0,selector)
    assert(result.available && result.error==.None && body.driver.role==.Observer && gd.rigid_body2d_is_freeze_enabled(node))
    empty,error:=rgd.session_body2_sample(&session,&body,1);assert(error==.None && empty.sequence==0)
    assert(own.offer(state,1,1,10)==.None);session.client.authority_frame.tick=1
    result=rgd.session_body2_frame(&session,&body,0,selector)
    assert(result.error==.None && body.driver.role==.Preparing && !gd.rigid_body2d_is_freeze_enabled(node))
    sample:own.Sample(own.Pose2);sample,error=rgd.session_body2_sample(&session,&body,2)
    assert(error==.None && sample.sequence==1 && sample.scope.revision==state.pending.revision)
    accepted:=own.accept(state,1,sample,1,rules);assert(accepted.error==.None && accepted.transferred)
    result=rgd.session_body2_frame(&session,&body,0,selector);assert(result.error==.None && body.driver.role==.Owner)
    assert(own.cut(state,1,own.Pose2{position={10,20}},2,rules)==.None);session.client.authority_frame.tick=2
    result=rgd.session_body2_frame(&session,&body,0,selector)
    assert(result.error==.None && gd.node2d_get_global_position(node)==(gd.Vector2{10,20}))
    session.fenced=true;empty,error=rgd.session_body2_sample(&session,&body,3)
    assert(error==.None && empty.sequence==0 && gd.rigid_body2d_is_freeze_enabled(node))
    session.fenced=false;session.client.cfg.epoch=2
    empty,error=rgd.session_body2_sample(&session,&body,4);assert(error==.None && empty.sequence==0)
    assert(own.bind_epoch(state,2,2)==.None)
    result=rgd.session_body2_frame(&session,&body,0,selector);assert(result.error==.None && body.driver.epoch==2)
    assert(own.accept(state,1,sample,2,rules).error==.Stale_Scope)
    session.clock.paused=true;empty,error=rgd.session_body2_sample(&session,&body,5)
    assert(error==.None && empty.sequence==0 && gd.rigid_body2d_is_freeze_enabled(node))
    }
    {
    node:=gd.new_rigid_body3d();gd.add_child(self.owner,node);defer gd.node_queue_free(node)
    skin:=gd.new_node3d();gd.add_child(node,skin);gd.node3d_set_position(skin,{10,20,30})
    simulation:rgd.Simulation_Body3
    assert(rgd.simulation_body3_attach(&simulation,node,.Rigid,skin))
    assert(rgd.simulation_body3_present(&simulation,{1,0},{position={10,20,30},rotation={0,0,0,1}})==.None)
    assert(gd.rigid_body3d_is_freeze_enabled(node) && gd.node3d_get_global_position(node)==(gd.Vector3{10,20,30}))
    assert(gd.node3d_get_position(skin)==(gd.Vector3{10,20,30})) // authored offset stays intact
    assert(rgd.simulation_body3_present(&simulation,{1,0},{position={0=math.inf_f32(1)},rotation={0,0,0,1}})==.Invalid_Value)
    assert(rgd.simulation_body3_present(&simulation,{2,0},{position={10,20,30},rotation={0,0,0,1}},1)==.None)
    assert(rgd.simulation_body3_present(&simulation,{1,0},{position={10,20,30},rotation={0,0,0,1}})==.Invalid_Epoch)
    rgd.simulation_body3_destroy(&simulation)

    body:rgd.Body3;assert(rgd.body3_attach(&body,node,.Rigid,skin));defer rgd.body3_destroy(&body)
    session:rgd.Session(Body_World,u8,u8,u8,1)
    session.ready=true;session.client.phase=.Running;session.client.seat=1;session.client.cfg.epoch=1
    state:=&session.client.authority_frame.state.three
    rules:=own.Rules(own.Pose3){valid=proc(_:rawptr,value:own.Pose3)->bool{return true}}
    assert(own.init(state,{1,0,1},1,0,2,own.Pose3{position={10,20,30},rotation={0,0,0,1}},rules)==.None)
    selector:=proc(_:rawptr,world:Body_World)->(own.State(own.Pose3),bool){return world.three,true}
    result:=rgd.session_body3_frame(&session,&body,0,selector)
    assert(result.available && result.error==.None && body.driver.role==.Observer && gd.rigid_body3d_is_freeze_enabled(node))
    empty,error:=rgd.session_body3_sample(&session,&body,1);assert(error==.None && empty.sequence==0)
    assert(own.offer(state,1,1,10)==.None);session.client.authority_frame.tick=1
    result=rgd.session_body3_frame(&session,&body,0,selector)
    assert(result.error==.None && body.driver.role==.Preparing && !gd.rigid_body3d_is_freeze_enabled(node))
    sample:own.Sample(own.Pose3);sample,error=rgd.session_body3_sample(&session,&body,2)
    assert(error==.None && sample.sequence==1 && sample.scope.revision==state.pending.revision)
    accepted:=own.accept(state,1,sample,1,rules);assert(accepted.error==.None && accepted.transferred)
    result=rgd.session_body3_frame(&session,&body,0,selector);assert(result.error==.None && body.driver.role==.Owner)
    assert(own.cut(state,1,own.Pose3{position={10,20,30},rotation={0,0,0,1}},2,rules)==.None);session.client.authority_frame.tick=2
    result=rgd.session_body3_frame(&session,&body,0,selector)
    assert(result.error==.None && gd.node3d_get_global_position(node)==(gd.Vector3{10,20,30}))
    session.fenced=true;empty,error=rgd.session_body3_sample(&session,&body,3)
    assert(error==.None && empty.sequence==0 && gd.rigid_body3d_is_freeze_enabled(node))
    session.fenced=false;session.client.cfg.epoch=2
    empty,error=rgd.session_body3_sample(&session,&body,4);assert(error==.None && empty.sequence==0)
    assert(own.bind_epoch(state,2,2)==.None)
    result=rgd.session_body3_frame(&session,&body,0,selector);assert(result.error==.None && body.driver.epoch==2)
    assert(own.accept(state,1,sample,2,rules).error==.Stale_Scope)
    session.clock.paused=true;empty,error=rgd.session_body3_sample(&session,&body,5)
    assert(error==.None && empty.sequence==0 && gd.rigid_body3d_is_freeze_enabled(node))
    }
    gd.print_str("REPLAY_BODY_BINDINGS_OK dimensions=2,3 authored_offset=true transfer=true cuts=true fence=true epoch=true pause=true")
}
}
