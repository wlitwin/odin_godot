package replay_godot

import a "godot:replay/assets"
import net "godot:replay/net"
import sc "godot:replay/schema"

// The caller supplies all dependencies of the captured root, not merely visible
// assets. The bundle is encoded completely before the staged file write begins.
checkpoint_bundle_write :: proc(cp: ^net.Checkpoint($S, $C, $A, $N), model: net.Model(S, C, A, $E, N),
                                cache: ^a.Cache, refs: []a.Ref, path: string, codec: ^net.Checkpoint_Codec = nil) -> Storage_Result {
	bytes,result:=checkpoint_bundle_encode(cp,model,cache,refs,codec);defer delete(bytes)
	if result.error!=.None {return result}
	return {error=storage_write(path,bytes,a.BUNDLE_LIMIT)}
}

// Owned bytes, independent of the storage backend. This same complete bundle
// can be submitted to an asynchronous browser operation or a native file writer.
checkpoint_bundle_encode :: proc(cp: ^net.Checkpoint($S,$C,$A,$N),model:net.Model(S,C,A,$E,N),
                                 cache:^a.Cache,refs:[]a.Ref,codec:^net.Checkpoint_Codec=nil)->([]u8,Storage_Result) {
	root, err := net.checkpoint_encode(cp, model, codec = codec); defer delete(root)
	if err != .None {return nil,{.Codec, err}}
	bytes, bundled := a.bundle_encode(root, refs, cache, {epoch = cp.header.epoch, tick = cp.header.tick, content = cp.header.content})
	if bundled != .None {return nil,{.Codec, bundled == .Capacity ? .Capacity : .Invalid_Checkpoint}}
	return bytes,{}
}

// Returns owned file bytes; view borrows them. Validate application dependency
// completeness and identity before bundle_install / session_resume. Raw legacy
// checkpoints produce a view with no assets and must pass those same checks.
checkpoint_bundle_read :: proc(cp: ^net.Checkpoint($S, $C, $A, $N), model: net.Model(S, C, A, $E, N),
                               path: string, content: u64) -> ([]u8, a.Bundle_View, Storage_Result) {
	if cp.ready {return nil, {}, {.Codec, .Wrong_Phase}}
	bytes, storage := storage_read(path, a.BUNDLE_LIMIT)
	if storage != .None {return nil, {}, {error = storage}}
	view,result:=checkpoint_bundle_decode(cp,model,bytes,content)
	if result.error!=.None {delete(bytes);return nil,{},result}
	return bytes,view,{}
}

// The view borrows bytes. Validate application identity and dependency
// completeness before installing assets or opening the resumed runner.
checkpoint_bundle_decode :: proc(cp:^net.Checkpoint($S,$C,$A,$N),model:net.Model(S,C,A,$E,N),
                                 bytes:[]u8,content:u64)->(a.Bundle_View,Storage_Result) {
	if cp.ready {return {},{.Codec,.Wrong_Phase}}
	view: a.Bundle_View
	// Bundle headers describe an appended body; inspect only a raw checkpoint
	// here. The bundle decoder independently validates its own header and body.
	meta, _, inspected := sc.inspect(bytes)
	if inspected.error == .None && meta.kind == net.CHECKPOINT_KIND {
		view.meta, view.root = meta, bytes
	} else {
		var_view, err := a.bundle_decode(bytes, content)
		if err != .None {return {}, {.Codec, .Invalid_Checkpoint}}
		view = var_view
	}
	if err := net.checkpoint_decode(cp, view.root, model, content); err != .None {return {}, {.Codec, err}}
	if cp.header.epoch != view.meta.epoch || cp.header.tick != view.meta.tick || cp.header.content != view.meta.content {
		net.checkpoint_destroy(cp); return {}, {.Codec, .Invalid_Checkpoint}
	}
	return view, {}
}
