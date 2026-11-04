// Descriptor-only public API oracle. No world, simulation, history or Godot.
package seed_oracle

import "core:encoding/json"
import "core:fmt"
import "core:mem"
import "core:os"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import common "godot:examples/box3d_common"
import adapter "godot:examples/replay_box3d/shared/adapter"
import ph "godot:replay/physics"
import sc "godot:replay/schema"

Report :: struct {
 schema:u32,
 scope:string,
 initial,seed:u32,
 ok:bool,
 catalog_create,identity_status,codec_init,config_encode,codec_destroy,catalog_destroy:i32,
 application_rules,bound_game_rules:bd.Digest,
 catalog_identity:b.Recovery_Identity,
 native_build,native_target:[32]u8,
 provider_canonical_bytes,provider_value_bytes:int,
 files_written:bool,
 engine_status,wrapper_status:i32,
 engine_live,wrapper_live,provider_live,odin_live:u64,
}

describe :: proc()->(report:Report) {
 report.schema=1;report.scope="nil_owner_static_native_descriptor_only"
 report.initial=32;report.seed=17
 config:=b.recovery_config_default();config.profile=common.PROFILE
 assets:=common.assets()
 catalog,status:=b.recovery_catalog_create(config,assets[:])
 report.catalog_create=i32(status)
 if status!=.Ok{return}
 defer {report.catalog_destroy=i32(b.recovery_catalog_destroy(&catalog))}
 report.catalog_identity,status=b.recovery_catalog_identity(&catalog)
 report.identity_status=i32(status);if status!=.Ok{return}
 contract,cs:=b.domain_contract_get();if cs!=.Ok{return}
 report.native_build=contract.build;report.native_target=contract.target
 provider:=adapter.config(&catalog,32)
 report.application_rules=adapter.rules(32,17)
 codec:adapter.Codec
 error:=ph.network_codec_init(&codec,&catalog,provider,report.application_rules)
 report.codec_init=i32(error);if error!=.None{return}
 defer {report.codec_destroy=i32(ph.network_codec_destroy(&codec))}
 values,allocation_error:=mem.alloc_bytes(codec.provider_config.wire_size)
 if allocation_error!=.None{return};defer delete(values)
 encoded:=sc.encode(&codec.provider_config,codec.config,values)
 report.config_encode=i32(encoded.error);if encoded.error!=.None{return}
 report.bound_game_rules=codec.value.game_rules
 report.provider_canonical_bytes=len(codec.provider_config.canonical)
 report.provider_value_bytes=len(values)
 report.files_written=
  os.write_entire_file("application_rules.bin",report.application_rules[:])==nil &&
  os.write_entire_file("provider_config.canonical.bin",codec.provider_config.canonical[:])==nil &&
  os.write_entire_file("provider_config.values.bin",values)==nil &&
  os.write_entire_file("bound_game_rules.bin",report.bound_game_rules[:])==nil
 report.ok=report.files_written
 return
}

main :: proc() {
 backing:=context.allocator
 tracking:mem.Tracking_Allocator
 mem.tracking_allocator_init(&tracking,backing,backing)
 context.allocator=mem.tracking_allocator(&tracking)
 report:=describe()
 engine,es:=b.engine_allocation_stats();wrapper,ws:=b.snapshot_allocation_stats()
 report.engine_status=i32(es);report.wrapper_status=i32(ws)
 report.engine_live=engine.live_bytes;report.wrapper_live=wrapper.live_bytes
 report.provider_live=ph.allocation_stats().live_bytes
 report.odin_live=u64(tracking.current_memory_allocated)
 report.ok=report.ok && report.codec_destroy==0 && report.catalog_destroy==0 &&
  es==.Ok && ws==.Ok && report.engine_live==0 && report.wrapper_live==0 &&
  report.provider_live==0 && report.odin_live==0
 context.allocator=backing
 mem.tracking_allocator_destroy(&tracking)
 bytes,error:=json.marshal(report);assert(error==nil)
 fmt.println(string(bytes));delete(bytes)
 if !report.ok{os.exit(1)}
}
