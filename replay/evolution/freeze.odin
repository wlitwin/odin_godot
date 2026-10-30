package replay_evolution

import "core:fmt"
import "core:reflect"
import "core:strings"
import sc "godot:replay/schema"
import d "godot:replay/definitions"

// Generates a self-contained type expression: every dependency is recursively
// frozen, never imported from the evolving game. Native padding/endianness are
// deliberately not contracts; canonical Replay encoding is the contract.
// Named unions and enumerated arrays need authored source and are rejected.
freeze :: proc(t:typeid,package_name,type_name:string)->(string,d.Report) {
    if !identifier(package_name) || !identifier(type_name) {return "",d.problem(.Invalid,"$","invalid generated identifier")}
    schema:sc.Schema;defer sc.destroy(&schema)
    if report:=sc.init(&schema,t);report.error!=.None {return "",d.problem(.Invalid,report.path,"type is not a canonical replay value")}
    builder:strings.Builder;defer strings.builder_destroy(&builder)
    fmt.sbprintf(&builder,"package %s\n\n// Frozen canonical schema %d. No live type dependencies.\n%s :: ",package_name,schema.fingerprint,type_name)
    report:=freeze_type(&builder,type_info_of(t),"$",0)
    if report.error!=.None {return "",report}
    strings.write_string(&builder,"\n")
    return strings.clone(strings.to_string(builder)),{}
}
@(private)
identifier :: proc(name:string)->bool {
    if len(name)==0 {return false}
    for c,i in name {if !(c=='_' || c>='a' && c<='z' || c>='A' && c<='Z' || i>0 && c>='0' && c<='9') {return false}}
    return true
}
@(private)
freeze_type :: proc(out:^strings.Builder,info:^reflect.Type_Info,path:string,depth:int)->d.Report {
    if depth>64 {return d.problem(.Invalid,path,"type nesting limit")}
    base:=reflect.type_info_base(info)
    #partial switch value in base.variant {
    case reflect.Type_Info_Integer:fmt.sbprintf(out,"%s%d",value.signed ? "i" : "u",base.size*8)
    case reflect.Type_Info_Rune:strings.write_string(out,"i32")
    case reflect.Type_Info_Float:fmt.sbprintf(out,"f%d",base.size*8)
    case reflect.Type_Info_Boolean:strings.write_string(out,"bool")
    case reflect.Type_Info_Array:
        fmt.sbprintf(out,"[%d]",value.count)
        return freeze_type(out,value.elem,path,depth+1)
    case reflect.Type_Info_Struct:
        strings.write_string(out,"struct {\n")
        for i in 0..<int(value.field_count) {
            if !identifier(value.names[i]) || strings.contains(value.tags[i],"`") {return d.problem(.Invalid,path,"unsupported field name/tag")}
            fmt.sbprintf(out,"%s: ",value.names[i])
            if report:=freeze_type(out,value.types[i],fmt.tprintf("%s.%s",path,value.names[i]),depth+1);report.error!=.None {return report}
            if value.tags[i]!="" {fmt.sbprintf(out," `%s`",value.tags[i])}
            strings.write_string(out,",\n")
        }
        strings.write_string(out,"}")
    case reflect.Type_Info_Enum:
        strings.write_string(out,"enum ")
        if report:=freeze_type(out,value.base,path,depth+1);report.error!=.None {return report}
        strings.write_string(out," {")
        for number,i in value.values {if !identifier(value.names[i]) {return d.problem(.Invalid,path,"unsupported enum name")};fmt.sbprintf(out,"%s=%d,",value.names[i],i64(number))}
        strings.write_string(out,"}")
    case reflect.Type_Info_Bit_Set:
        strings.write_string(out,"bit_set[")
        if value.elem!=nil {
            if report:=freeze_type(out,value.elem,path,depth+1);report.error!=.None {return report}
        } else {fmt.sbprintf(out,"%d..=%d",value.lower,value.upper)}
        fmt.sbprintf(out,";u%d]",base.size*8)
    case:return d.problem(.Invalid,path,"freezer supports scalars, structs, arrays, enums and bit sets; author this type explicitly")
    }
    return {}
}
