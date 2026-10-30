package replay_diagnostic

import "core:fmt"
import "core:mem"
import "core:strings"
import r "godot:replay"
import sc "godot:replay/schema"

// Owned plain text. Limits bound displayed fields/events; reports never include
// live pointers or claim that a local audit establishes cross-peer agreement.
audit_text :: proc(result:r.Result,capture:^r.Audit_Capture($S,$I,$E),limit:int=16,allocator:=context.allocator)->string {
	builder:strings.Builder;strings.builder_init(&builder,allocator);defer strings.builder_destroy(&builder)
	fmt.sbprintf(&builder,"Audit: %v | tick %d | steps %d\n",result.error,result.tick,result.steps)
	if capture==nil || !capture.ready {return strings.clone(strings.to_string(builder),allocator)}
	if limit<1 || limit>256 {fmt.sbprintf(&builder,"Invalid display limit (1..256).\n");return strings.clone(strings.to_string(builder),allocator)}
	fmt.sbprintf(&builder,"Input recorded at tick %d; parent frame %d\n",capture.expected.tick,capture.parent.tick)
	state,event:sc.Schema;defer sc.destroy(&state);defer sc.destroy(&event)
	if initialized:=sc.init(&state,S,allocator=allocator);initialized.error!=.None {
		fmt.sbprintf(&builder,"State schema: %v at %s\n",initialized.error,initialized.path)
	} else {
		fields:=make([]sc.Difference,limit,allocator);defer delete(fields,allocator)
		report:=sc.diff(&state,capture.expected.state,capture.actual.state,fields)
		append_fields(&builder,&state,report,fields,"state",allocator)
	}
	fmt.sbprintf(&builder,"Events: expected %d, replayed %d\n",len(capture.expected_events),len(capture.actual_events))
	if initialized:=sc.init(&event,r.Occurrence(E),allocator=allocator);initialized.error!=.None {
		fmt.sbprintf(&builder,"Event schema: %v at %s\n",initialized.error,initialized.path)
	} else {
		fields:=make([]sc.Difference,limit,allocator);defer delete(fields,allocator)
		shown:=0
		for expected,i in capture.expected_events {
			if i>=len(capture.actual_events) {break}
			report:=sc.diff(&event,expected,capture.actual_events[i],fields[:limit-shown])
			if report.total==0 && report.report.error==.None {continue}
			label:=fmt.aprintf("event[%d]",i,allocator=allocator)
			append_fields(&builder,&event,report,fields,label,allocator);delete(label,allocator)
			shown+=report.count
			if shown==limit {if i+1<min(len(capture.expected_events),len(capture.actual_events)) {fmt.sbprintf(&builder,"Remaining event comparisons omitted.\n")};break}
		}
	}
	return strings.clone(strings.to_string(builder),allocator)
}
@(private)
append_fields :: proc(builder:^strings.Builder,codec:^sc.Schema,report:sc.Diff_Report,fields:[]sc.Difference,section:string,allocator:mem.Allocator) {
	if report.report.error!=.None {fmt.sbprintf(builder,"%s schema: %v (%v) at %s\n",section,report.report.error,report.side,report.report.path);return}
	fmt.sbprintf(builder,"%s: %d differing %s\n",section,report.total,report.total==1 ? "field" : "fields")
	for field in fields[:report.count] {
		left:=sc.diff_value(codec,field,.Left,allocator);right:=sc.diff_value(codec,field,.Right,allocator)
		fmt.sbprintf(builder,"  %s: %s -> %s\n",field.path,left,right)
		delete(left,allocator);delete(right,allocator)
	}
	if report.count<report.total {fmt.sbprintf(builder,"  showing %d of %d fields\n",report.count,report.total)}
}
