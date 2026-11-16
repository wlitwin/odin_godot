package replay_net_legacy
import sc "godot:replay/schema"

// Explicit complete-world and pending-action conversion. Controls, seat count
// and control timing stay shared; event schemas may differ (no archived events).
checkpoint_convert :: proc(bytes:[]u8,source_model:Model($S,$C,$A,$E,$N),source_content:u64,
                           target_model:Model($T,C,$B,$F,N),target_content:u64,
                           world:proc(S)->(T,bool),action:proc(A)->(B,bool),allocator:=context.allocator)->([]u8,Error) {
	if world==nil || action==nil || target_content==0 || source_model.control_timing!=target_model.control_timing || source_model.control_timing>.Latest_Observation || source_model.state_valid==nil || source_model.control_valid==nil || target_model.state_valid==nil || target_model.control_valid==nil {return nil,.Invalid_Model}
	source:Checkpoint(S,C,A,N);defer checkpoint_destroy(&source)
	if err:=checkpoint_decode(&source,bytes,source_model,source_content,allocator);err!=.None {return nil,err}
	state,ok:=world(source.frame.state);if !ok {return nil,.Invalid_Frame}
	codec:Checkpoint_Codec;defer checkpoint_codec_destroy(&codec)
	if err:=checkpoint_codec_init(&codec,T,C,B,F,N,true,allocator);err!=.None {return nil,err}
	target:=Checkpoint(T,C,B,N){allocator=allocator,ready=true,header=source.header,settings=source.settings,
		frame={tick=source.frame.tick,state=state},held=source.held,held_views=source.held_views,peers=source.peers,
		inputs=source.inputs,outcomes=source.outcomes,banned=source.banned,policy_data=source.policy_data}
	target.actions=make([dynamic]Checkpoint_Action(B),len(source.actions),allocator);defer delete(target.actions)
	for entry,i in source.actions {
		value,mapped:=action(entry.value);if !mapped {return nil,.Invalid_Input}
		target.actions[i]={entry.peer,entry.sequence,entry.tick,value,entry.reason}
	}
	target.header.content=target_content
	target.header.contract=contract_hash(&codec.network,checkpoint_config(target.header,target.settings),N,target_model.control_timing,replication=target_model.replication.id)
	maximum:=max(codec.network.welcome.wire_size,max(codec.network.snapshot.wire_size,codec.network.facts.wire_size))+sc.HEADER_BYTES
	if int(target.settings.egress_bytes_per_pump)<maximum {return nil,.Checkpoint_Contract}
	return checkpoint_encode(&target,target_model,allocator,&codec)
}
