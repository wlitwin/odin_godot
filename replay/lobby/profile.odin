package replay_lobby
PROFILE_BYTES :: NAME_BYTES+4
profile_encode :: proc(value:Name)->([PROFILE_BYTES]u8,bool) {
	if !name_valid(value,false) {return {},false}
	bytes:[PROFILE_BYTES]u8;bytes[0],bytes[1],bytes[2],bytes[3]='R','N',1,value.length
	text:=value.bytes;copy(bytes[4:],text[:]);return bytes,true
}
profile_decode :: proc(bytes:[]u8)->(Name,bool) {
	if len(bytes)!=PROFILE_BYTES || bytes[0]!='R' || bytes[1]!='N' || bytes[2]!=1 {return {},false}
	value:=Name{length=bytes[3]};copy(value.bytes[:],bytes[4:]);return value,name_valid(value,false)
}
