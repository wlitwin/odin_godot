package evolution_generated_fixture
import e "godot:replay/evolution"

convert :: proc(old:Source_Record)->(Target_Record,bool) {
    // TODO: choose and review every new default below.
    defaults_reviewed := false
    if !defaults_reviewed {return {},false}
    defaults:Target_Record
    added:=[]string{
        "$.items[0].boost", // TODO: defaults.items[0].boost
        "$.items[1].boost", // TODO: defaults.items[1].boost
        "$.limit", // TODO: defaults.limit
    }
    value,report:=e.copy_preserved(old,defaults,added)
    return value,report.error==.None
}
