package box3d_diagnostics

import "core:crypto/sha2"

Descriptor :: struct {tag: string, bytes: []u8}

// Bind a typed contract containing several schemas. Tags must be unique and in
// strictly increasing byte order. For example the game descriptor catalog can
// include occurrences, registered_fields, side, and state. No concatenation or
// native type IDs are implicit. Both domain and lengths participate in SHA256.
hash_descriptors :: proc(domain: string, fields: []Descriptor) -> (Digest, Error) {
	if !descriptor_tag(domain,128) || len(fields)==0 || len(fields)>32 {return {},.Invalid}
	total:=0
	for field,i in fields {
		if !descriptor_tag(field.tag,64) || (i>0 && fields[i-1].tag>=field.tag) {return {},.Invalid}
		if len(field.bytes)>1024*1024-total {return {},.Limit};total+=len(field.bytes)
	}
	h:sha2.Context_256;sha2.init_256(&h)
	sha2.update(&h,transmute([]u8)string("OGB3DESC1"))
	length:[8]u8;at:=0;write_u64(length[:],&at,u64(len(domain)));sha2.update(&h,length[:])
	sha2.update(&h,transmute([]u8)domain)
	at=0;write_u32(length[:],&at,u32(len(fields)));sha2.update(&h,length[:4])
	for field in fields {
		at=0;write_u32(length[:],&at,u32(len(field.tag)));sha2.update(&h,length[:4]);sha2.update(&h,transmute([]u8)field.tag)
		at=0;write_u64(length[:],&at,u64(len(field.bytes)));sha2.update(&h,length[:]);sha2.update(&h,field.bytes)
	}
	result:Digest;sha2.final(&h,result[:]);return result,.None
}
@(private)
descriptor_tag :: proc(tag:string,maximum:int)->bool {
	if len(tag)==0 || len(tag)>maximum {return false}
	for c in tag {if !((c>='a' && c<='z') || (c>='A' && c<='Z') || (c>='0' && c<='9') || c=='_' || c=='-' || c=='.') {return false}}
	return true
}
