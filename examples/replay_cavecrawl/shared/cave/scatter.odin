package cave

// Original Cavecrawl's integer-only decoration recipe. Presentation data only;
// deterministic for a supplied seed/depth and independent of frame RNG/state.
Decoration :: struct {x,y:u16,kind:u8}
Scatter :: struct {items:[10]Decoration,checksum:u32,count:u8}
scatter :: proc(seed:u32,depth:u8)->Scatter {
	result:Scatter;if seed==0 {return result};result.count=10;state:=seed~(u32(depth)*0x9E3779B9)
	next :: proc(state:^u32)->u32 {
		state^+=0x9E3779B9;z:=state^;z=(z~(z>>16))*0x21F0AAAD;z=(z~(z>>15))*0x735A2D97;return z~(z>>15)
	}
	for &item,i in result.items {
		x:=next(&state)%560+30;y:=next(&state)%230+60
		item={u16(x),u16(y),u8(i%2)};result.checksum=result.checksum*31+x*7+y
	}
	return result
}
