package replay_lobby

import "core:unicode/utf8"
import "core:strings"

NAME_BYTES :: 48
Name :: struct {bytes:[NAME_BYTES]u8,length:u8}
Phase :: enum u8 {Waiting,Playing}
Verb :: enum u8 {None,Profile,Ready,Start,Restart}
Command :: struct {verb:Verb,name:Name,ready:bool}
Result :: enum u8 {Rejected,Changed,Started,Restarted}
Lobby :: struct($N:int) {names:[N]Name,present,ready:u64,leader:u16,automatic:bool,phase:Phase,run:u32}

name :: proc(input:string)->(Name,bool) {
	text:=strings.trim_space(input)
	value:Name;at:=0
	for at<len(text) {
		rune,size:=utf8.decode_rune_in_string(text[at:])
		if size==0 || (rune==utf8.RUNE_ERROR && size==1) || rune<32 || (rune>=127 && rune<=159) || rune==0x2028 || rune==0x2029 {return {},false}
		if at+size>NAME_BYTES {break}
		copy(value.bytes[at:at+size],transmute([]u8)text[at:at+size]);at+=size
	}
	value.length=u8(at);return value,at>0
}
name_valid :: proc(value:Name,empty:bool=true)->bool {
	if value.length>NAME_BYTES || (!empty && value.length==0) {return false}
	for b,i in value.bytes {if i>=int(value.length) && b!=0 {return false}}
	if value.length==0 {return true}
	bytes:=value.bytes;parsed,ok:=name(string(bytes[:value.length]));return ok && parsed==value
}
text :: proc(value:^Name)->string {return string(value.bytes[:value.length])}
seat_name :: proc(seat:u16)->Name {
	assert(seat>=1 && seat<=8)
	return {bytes={0='S',1='e',2='a',3='t',4=' ',5=u8('0')+u8(seat)},length=6}
}
initial :: proc($N:int,automatic:bool=false,playing:bool=false)->Lobby(N) {
	#assert(N>=1 && N<=8)
	l:=Lobby(N){leader=automatic ? 0 : 1,automatic=automatic,phase=playing ? .Playing : .Waiting,run=playing ? 1 : 0}
	for &value,i in l.names {value=seat_name(u16(i+1))}
	return l
}
valid :: proc(l:Lobby($N))->bool {
	if N<1 || N>8 {return false}
	mask:=(u64(1)<<uint(N))-1
	if l.present & ~mask!=0 || l.ready & ~l.present!=0 || int(l.leader)>N || l.phase>.Playing || l.automatic!=(l.leader==0) {return false}
	for value in l.names {if !name_valid(value) {return false}}
	return true
}
reset_member :: proc(l:^Lobby($N),seat:u16) {
	assert(seat>=1 && int(seat)<=N)
	l.names[seat-1]=seat_name(seat);l.ready &~= u64(1)<<uint(seat-1)
}
roster :: proc(l:^Lobby($N),joins,leaves:u64) {
	mask:=(u64(1)<<uint(N))-1;old:=l.present
	l.present=(l.present & ~leaves | joins)&mask
	l.ready &= l.present & ~(joins & ~old)
	if !l.automatic && l.present!=0 && l.present & (u64(1)<<uint(l.leader-1))==0 {
		for i in 0..<N {if l.present & (u64(1)<<uint(i))!=0 {l.leader=u16(i+1);break}}
	}
}
all_ready :: proc(l:^Lobby($N))->bool {return l.present!=0 && l.ready==l.present}
command_valid :: proc(c:Command)->bool {
	switch c.verb {
	case .Profile:return name_valid(c.name,false) && !c.ready
	case .Ready:return name_valid(c.name)
	case .Start,.Restart:return c.name==(Name{}) && !c.ready
	case .None:return false
	}
	return false
}
apply :: proc(l:^Lobby($N),seat:u16,command:Command,can_restart:bool=false)->Result {
	if seat<1 || int(seat)>N || !command_valid(command) {return .Rejected}
	bit:=u64(1)<<uint(seat-1)
	if l.present & bit==0 {return .Rejected}
	switch command.verb {
	case .Profile:
		if l.names[seat-1]!=command.name {l.names[seat-1]=command.name;l.ready &~= bit};return .Changed
	case .Ready:
		if l.phase!=.Waiting {return .Rejected}
		if command.name.length!=0 {l.names[seat-1]=command.name}
		if !name_valid(l.names[seat-1],false) {return .Rejected}
		if command.ready {l.ready |= bit} else {l.ready &~= bit};return .Changed
	case .Start:
		if l.phase!=.Waiting || seat!=l.leader || !all_ready(l) || l.run==max(u32) {return .Rejected}
		l.phase=.Playing;l.run+=1;return .Started
	case .Restart:
		if l.phase!=.Playing || seat!=l.leader || !can_restart || l.run==max(u32) {return .Rejected}
		l.run+=1;return .Restarted
	case .None:return .Rejected
	}
	return .Rejected
}
auto_start :: proc(l:^Lobby($N))->bool {
	if !l.automatic || l.phase!=.Waiting || !all_ready(l) || l.run==max(u32) {return false}
	l.phase=.Playing;l.run+=1;return true
}
