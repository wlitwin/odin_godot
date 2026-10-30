package definitions_test
import "core:testing"
import d "godot:replay/definitions"

@(test)
artifacts_roundtrip_and_reject_wrong_contract_without_publishing :: proc(t:^testing.T) {
 source,target:d.Store(Definition)
 assert(d.init(&source,2).error==.None);assert(d.init(&target,2).error==.None)
 defer d.destroy(&source);defer d.destroy(&target)
 ref,report:=d.publish(&source,Definition{3,4},12);assert(report.error==.None)
 bytes,exported:=d.artifact_export(&source,ref,99);assert(exported.error==.None);defer delete(bytes)
 imported,result:=d.artifact_import(&target,bytes,12,99);testing.expect(t,result.error==.None && imported==ref)
 value,found:=d.get(&target,imported);testing.expect(t,found && value==(Definition{3,4}))
 _,result=d.artifact_import(&target,bytes,13,99);testing.expect_value(t,result.error,d.Error.Schema)
 _,result=d.artifact_import(&target,bytes,12,98);testing.expect_value(t,result.error,d.Error.Invalid)
 wrong:d.Store(struct{speed:f32,count:u32});assert(d.init(&wrong,1).error==.None);defer d.destroy(&wrong)
 _,result=d.artifact_import(&wrong,bytes,12);testing.expect_value(t,result.error,d.Error.Schema)
 _,result=d.artifact_import(&target,bytes[:len(bytes)-1],12);testing.expect_value(t,result.error,d.Error.Schema)
 bytes[len(bytes)-1]~=1
 _,result=d.artifact_import(&target,bytes,12);testing.expect_value(t,result.error,d.Error.Schema)
 still,_:=d.get(&target,ref);testing.expect_value(t,still,value)
}
@(test)
registry_rejects_missing_duplicate_and_bad_definitions_atomically :: proc(t:^testing.T) {
 registry:d.Registry(Definition,u32);assert(d.registry_init(&registry,8));defer d.registry_destroy(&registry)
 required:=[2]u32{0,6}
 values:=[2]d.Archetype(Definition,u32){{0,{3,4},10},{6,{5,6},20}}
 validator:=proc(a:d.Archetype(Definition,u32))->d.Report {
  if a.definition.speed<0 || a.local==0 {return d.problem(.Invalid,"$entry","invalid definition or local view")};return {}
 }
 testing.expect_value(t,d.registry_publish(&registry,values[:],required[:],validator).error,d.Error.None)
 first,_:=d.registry_get(&registry,0)
 values[1].id=0;testing.expect_value(t,d.registry_publish(&registry,values[:],required[:],validator).error,d.Error.Invalid)
 values[1].id=7;testing.expect_value(t,d.registry_publish(&registry,values[:],required[:],validator).error,d.Error.Missing)
 values[1].id=6;values[1].definition.speed=-1
 testing.expect_value(t,d.registry_publish(&registry,values[:],required[:],validator).error,d.Error.Invalid)
 still,_:=d.registry_get(&registry,0);testing.expect(t,still==first && registry.count==2)
 values[1]={6,{7,8},30};assert(d.registry_publish(&registry,values[:],required[:],validator).error==.None)
 replaced,_:=d.registry_get(&registry,6);testing.expect_value(t,replaced.local,u32(30))
}
