package kit_net

// schema — generated, read-only metadata for one game's complete wire contract.
//
// Runtime descriptors deliberately keep executable thunks and struct offsets;
// Net_Schema keeps only stable protocol facts. scriptgen builds both this data
// and NET_SCHEMA_CANONICAL from the same recursive ABI walk, so diagnostics,
// tooling, admission introspection, and the JOIN fingerprint cannot drift into
// separate descriptions of the game.

Net_ABI_Endian :: enum u8 {
	Little,
}

// A half-open range in one of Net_Schema's flat backing tables. Spans keep the
// generated package allocation-free while preserving relationships such as an
// action's arguments and an input class's constraints.
Net_Schema_Span :: struct {
	first: int,
	count: int,
}

net_schema_span_valid :: proc(span: Net_Schema_Span, length: int) -> bool {
	return(
		span.first >= 0 &&
		span.count >= 0 &&
		span.first <= length &&
		span.count <= length - span.first \
	)
}

// One recursively visited type node. `path` is globally unique inside the
// schema. `detail` carries kind-specific canonical facts (array count/element,
// enum base/values, distinct base, or struct packing/field count) without
// turning the metadata API into a mirror of Odin's full type system.
Net_Type_Schema :: struct {
	path:   string,
	kind:   string,
	width:  int,
	align:  int,
	detail: string,
}

Net_Field_Lane :: enum u8 {
	Delta,
	Owner,
	Predict,
}

Net_Field_Schema :: struct {
	path:         string,
	entity:       string,
	name:         string,
	lane:         Net_Field_Lane,
	encoding:     string,
	struct_width: int,
	wire_width:   int,
	bound:        int,
	types:        Net_Schema_Span,
}

// The stable entity-kind row is optional: a descriptor may be useful in a
// hand-wired module without an `entity=Name:id` factory declaration. wire_id 0
// means no generated factory kind; generated ids themselves are always nonzero.
Net_Entity_Schema :: struct {
	name:      string,
	wire_id:   u16,
	stream_hz: int,
	avatar:    bool,
}

Net_Input_Constraint_Schema :: struct {
	field:      string,
	range:      string, // "" = none; otherwise canonical "min:max"
	mask:       string, // "" = none
	finite:     bool,
	unit:       bool,
	enum_check: bool,
}

Net_Input_Schema :: struct {
	path:        string,
	type_name:   string,
	class_id:    u16,
	encoding:    string,
	width:       int,
	bound:       int,
	types:       Net_Schema_Span,
	constraints: Net_Schema_Span,
}

Net_Argument_Schema :: struct {
	owner:    string, // action/fact path
	name:     string,
	kind:     string,
	target:   string, // referenced entity class; "" for value arguments
	width:    int, // 0 when variable
	bound:    int,
	variable: bool,
}

Net_Action_Outcome_Schema :: struct {
	owner:     string, // action path
	name:      string,
	type_name: string,
}

Net_Action_Schema :: struct {
	path:        string,
	entity:      string,
	name:        string,
	id:          u16,
	policy:      Action_Policy,
	model:       Action_Model,
	args:        Net_Schema_Span,
	outcomes:    Net_Schema_Span,
	consequence: Action_Consequence_Desc,
}

Net_Fact_Schedule :: enum u8 {
	Watch,
	Immediate,
	Anchored,
}

Net_Fact_Audience :: enum u8 {
	Everyone,
	Owner,
	Observers,
}

Net_Fact_Source :: enum u8 {
	Declared,
	Tick,
}

Net_Fact_Schema :: struct {
	path:     string,
	entity:   string,
	name:     string,
	id:       u16, // 0 is the entity tick's built-in fact channel
	anchor:   string, // named entity class; "" is an anchorless world fact
	schedule: Net_Fact_Schedule,
	audience: Net_Fact_Audience,
	source:   Net_Fact_Source,
	args:     Net_Schema_Span,
}

Net_Profile_Schema :: struct {
	path:      string,
	type_name: string,
	encoding:  string,
	width:     int,
	bound:     int,
	types:     Net_Schema_Span,
}

Net_Message_Schema :: struct {
	path:         string,
	entity:       string,
	name:         string,
	payload_type: string,
	tag:          u8,
	tag_name:     string,
	encoding:     string,
	width:        int,
	bound:        int,
	types:        Net_Schema_Span,
}

Net_Schema :: struct {
	abi_version:     u16,
	endian:          Net_ABI_Endian,
	abi_fingerprint: u64,
	fingerprint:     u64,
	canonical:       string,
	entities:        []Net_Entity_Schema,
	types:           []Net_Type_Schema,
	fields:          []Net_Field_Schema,
	inputs:          []Net_Input_Schema,
	constraints:     []Net_Input_Constraint_Schema,
	actions:         []Net_Action_Schema,
	action_outcomes: []Net_Action_Outcome_Schema,
	facts:           []Net_Fact_Schema,
	arguments:       []Net_Argument_Schema,
	profiles:        []Net_Profile_Schema,
	messages:        []Net_Message_Schema,
}

net_schema_canonical_fingerprint :: proc(schema: ^Net_Schema) -> u64 {
	if schema == nil {return 0}
	h := u64(0xcbf29ce484222325)
	for byte in transmute([]u8)schema.canonical {
		h = (h ~ u64(byte)) * 0x100000001b3
	}
	return h
}

// Cheap structural self-check for generated metadata and hand-built tooling
// fixtures. It validates every cross-table span and resolved action policy; it
// also recomputes the ABI hash from `canonical` so a copied/hand-built value
// cannot claim unrelated structured metadata accidentally.
net_schema_valid :: proc(schema: ^Net_Schema) -> bool {
	if schema == nil ||
	   schema.abi_version == 0 ||
	   schema.canonical == "" ||
	   schema.abi_fingerprint != net_schema_canonical_fingerprint(schema) {return false}
	for typ in schema.types {
		if typ.path == "" || typ.kind == "" || typ.width <= 0 || typ.align <= 0 {return false}
	}
	for field in schema.fields {
		if field.path == "" ||
		   field.entity == "" ||
		   field.name == "" ||
		   field.struct_width <= 0 ||
		   field.wire_width <= 0 ||
		   field.bound < field.wire_width ||
		   !net_schema_span_valid(field.types, len(schema.types)) {
			return false
		}
	}
	for input in schema.inputs {
		if input.path == "" ||
		   input.type_name == "" ||
		   input.width <= 0 ||
		   input.bound < input.width ||
		   !net_schema_span_valid(input.types, len(schema.types)) ||
		   !net_schema_span_valid(input.constraints, len(schema.constraints)) {
			return false
		}
	}
	for action in schema.actions {
		if action.path == "" ||
		   action.entity == "" ||
		   action.name == "" ||
		   !action_policy_valid(action.policy) ||
		   !net_schema_span_valid(action.args, len(schema.arguments)) ||
		   !net_schema_span_valid(action.outcomes, len(schema.action_outcomes)) ||
		   (action.consequence.name == "" &&
		   (action.consequence.authority_only || action.consequence.takes_game)) ||
		   (action.consequence.name != "" && !action.consequence.authority_only) {
			return false
		}
	}
	for outcome in schema.action_outcomes {
		if outcome.owner == "" || outcome.name == "" || outcome.type_name == "" {return false}
	}
	for argument in schema.arguments {
		if argument.owner == "" ||
		   argument.name == "" ||
		   argument.kind == "" ||
		   argument.bound <= 0 ||
		   (argument.variable ? argument.width != 0 : argument.width <= 0) {
			return false
		}
	}
	for fact in schema.facts {
		if fact.path == "" ||
		   fact.entity == "" ||
		   fact.name == "" ||
		   fact.schedule > .Anchored ||
		   fact.audience > .Observers ||
		   !net_schema_span_valid(fact.args, len(schema.arguments)) {
			return false
		}
	}
	for profile in schema.profiles {
		if profile.path == "" ||
		   profile.type_name == "" ||
		   profile.width <= 0 ||
		   profile.bound < profile.width ||
		   !net_schema_span_valid(profile.types, len(schema.types)) {
			return false
		}
	}
	for message in schema.messages {
		if message.path == "" ||
		   message.entity == "" ||
		   message.name == "" ||
		   message.payload_type == "" ||
		   message.width <= 0 ||
		   message.bound < message.width ||
		   !net_schema_span_valid(message.types, len(schema.types)) {
			return false
		}
	}
	return true
}

// Small lookup helpers cover the common tooling/debugging questions without
// allocating maps or making the generated schema mutable.
net_schema_entity :: proc(schema: ^Net_Schema, name: string) -> (^Net_Entity_Schema, bool) {
	if schema == nil {return nil, false}
	for &entity in schema.entities {
		if entity.name == name {return &entity, true}
	}
	return nil, false
}

net_schema_action :: proc(
	schema: ^Net_Schema,
	entity, name: string,
) -> (
	^Net_Action_Schema,
	bool,
) {
	if schema == nil {return nil, false}
	for &action in schema.actions {
		if action.entity == entity && action.name == name {return &action, true}
	}
	return nil, false
}

net_schema_field :: proc(schema: ^Net_Schema, entity, name: string) -> (^Net_Field_Schema, bool) {
	if schema == nil {return nil, false}
	for &field in schema.fields {
		if field.entity == entity && field.name == name {return &field, true}
	}
	return nil, false
}

net_schema_input :: proc(schema: ^Net_Schema, class_id: u16) -> (^Net_Input_Schema, bool) {
	if schema == nil {return nil, false}
	for &input in schema.inputs {
		if input.class_id == class_id {return &input, true}
	}
	return nil, false
}

net_schema_fact :: proc(schema: ^Net_Schema, entity, name: string) -> (^Net_Fact_Schema, bool) {
	if schema == nil {return nil, false}
	for &fact in schema.facts {
		if fact.entity == entity && fact.name == name {return &fact, true}
	}
	return nil, false
}

net_schema_message :: proc(schema: ^Net_Schema, tag: u8) -> (^Net_Message_Schema, bool) {
	if schema == nil {return nil, false}
	for &message in schema.messages {
		if message.tag == tag {return &message, true}
	}
	return nil, false
}

net_schema_types :: proc(schema: ^Net_Schema, span: Net_Schema_Span) -> []Net_Type_Schema {
	if schema == nil || !net_schema_span_valid(span, len(schema.types)) {return nil}
	return schema.types[span.first:span.first + span.count]
}

net_schema_input_constraints :: proc(
	schema: ^Net_Schema,
	input: ^Net_Input_Schema,
) -> []Net_Input_Constraint_Schema {
	if schema == nil ||
	   input == nil ||
	   !net_schema_span_valid(input.constraints, len(schema.constraints)) {return nil}
	return(
		schema.constraints[input.constraints.first:input.constraints.first +
		input.constraints.count] \
	)
}

net_schema_action_args :: proc(
	schema: ^Net_Schema,
	action: ^Net_Action_Schema,
) -> []Net_Argument_Schema {
	if schema == nil ||
	   action == nil ||
	   !net_schema_span_valid(action.args, len(schema.arguments)) {return nil}
	return schema.arguments[action.args.first:action.args.first + action.args.count]
}

net_schema_action_outcomes :: proc(
	schema: ^Net_Schema,
	action: ^Net_Action_Schema,
) -> []Net_Action_Outcome_Schema {
	if schema == nil ||
	   action == nil ||
	   !net_schema_span_valid(action.outcomes, len(schema.action_outcomes)) {return nil}
	return schema.action_outcomes[action.outcomes.first:action.outcomes.first + action.outcomes.count]
}

net_schema_fact_args :: proc(
	schema: ^Net_Schema,
	fact: ^Net_Fact_Schema,
) -> []Net_Argument_Schema {
	if schema == nil ||
	   fact == nil ||
	   !net_schema_span_valid(fact.args, len(schema.arguments)) {return nil}
	return schema.arguments[fact.args.first:fact.args.first + fact.args.count]
}
