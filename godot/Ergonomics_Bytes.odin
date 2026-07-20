package godot

import gdext "godot:gdext"

// Byte-array ergonomics — the hand-written companion to Packed_Byte_Array.gen.odin
// (binding regeneration only rewrites `*.gen.odin`, never this file).
//
// A PackedByteArray is the engine's shape for "some bytes": every packet
// signal, every FileAccess read, every image/audio buffer hands you one. Odin
// wants a `[]u8`. The conversion is three calls and a null case, and it was
// living up in kit/netgd — which meant kit/save imported an entire NETWORKING
// package to read a file off disk. Engine-type ergonomics belong beside the
// engine type.

// Zero-copy view of a Packed_Byte_Array's contents — valid only while `pba` is
// alive (inside the receiving method call, or before you free the array you
// were handed). Feed it to knet.reader_make; clone anything you keep.
packed_byte_array_view :: proc "contextless" (pba: ^Packed_Byte_Array) -> []u8 {
	n := int(packed_byte_array_size(pba))
	if n == 0 {return nil}
	p := gdext.packed_byte_array_operator_index_const(cast(gdext.TypePtr)pba, 0)
	return ([^]u8)(p)[:n]
}
