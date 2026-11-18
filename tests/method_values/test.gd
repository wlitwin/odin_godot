extends Node

func temporary_array(subject: Node) -> int:
	var value = subject.call("new_array")
	assert(value is Array and value.size() == 1)
	return int(subject.call("last_id"))
func temporary_input(subject: Node, method: String) -> int:
	var resource = Resource.new()
	var id := resource.get_instance_id()
	assert(subject.call(method, [resource]) == 1)
	return id
func return_text(subject: Node, count: int) -> void:
	for _i in count:
		var text: String = subject.call("new_text")
		assert(text.length() == 1024 and text[0] == "x")
func new_value_id(subject: Node, method: String) -> int:
	var value = subject.call(method)
	assert(value != null)
	return int(subject.call("last_id"))
func property_value_id(subject: Node) -> int:
	var value = subject.get("payload")
	assert(value is Array and value.size() == 1)
	return int(subject.call("last_id"))
func input_property_id(subject: Node, property: String = "incoming") -> int:
	var resource := Resource.new()
	subject.set(property, [resource])
	return resource.get_instance_id()
func input_method_id(subject: Node) -> int:
	var resource := Resource.new()
	subject.call("set_incoming", [resource])
	return resource.get_instance_id()
func echo_input_id(subject: Node) -> int:
	var resource := Resource.new()
	var id := resource.get_instance_id()
	var echoed: Array = subject.call("echo_array", [resource])
	resource = null
	assert(is_instance_id_valid(id) and echoed[0].get_instance_id() == id, "borrowed input survives return marshaling")
	return id
func _ready() -> void:
	var subject := Node.new()
	subject.set_script(load("res://scripts/values.odin"))
	assert(subject.get("title") == "héllo 🌏")
	var escaped = subject.call("borrowed_array")
	var borrowed_id: int = subject.call("last_id")
	escaped = null
	assert(is_instance_id_valid(borrowed_id), "borrowed return must not release its backing owner")
	subject.call("clear")
	assert(not is_instance_id_valid(borrowed_id))
	assert(not is_instance_id_valid(echo_input_id(subject)), "default argument copy leaked after returning it")
	assert(not is_instance_id_valid(temporary_input(subject, "variant_input")), "Variant argument copy leaked its Resource")
	for value in [null, 42, true, "text", Vector2(1, 2), {"key": 1}]:
		assert(int(subject.call("variant_input", value)) == typeof(value))
	for text in ["", "héllo 🌏", "a".repeat(8192)]:
		assert(subject.call("echo", text) == text, "Odin UTF-8 string must round-trip")
		assert(subject.call("clone_text", text) == text)
	assert(not is_instance_id_valid(new_value_id(subject, "new_resource")))
	assert(not is_instance_id_valid(new_value_id(subject, "new_callable")))
	assert(not is_instance_id_valid(new_value_id(subject, "new_dictionary")))
	assert(not is_instance_id_valid(property_value_id(subject)))
	var incoming_id := input_property_id(subject)
	assert(is_instance_id_valid(incoming_id), "setter must retain its explicit copy")
	subject.set("incoming", [])
	assert(not is_instance_id_valid(incoming_id), "setter/trampoline must release both copies")
	incoming_id = input_method_id(subject)
	assert(is_instance_id_valid(incoming_id), "method must retain its explicit copy")
	subject.call("set_incoming", [])
	assert(not is_instance_id_valid(incoming_id))
	assert(not subject.has_method("set_plain_incoming"), "fixture must exercise an unannotated setter")
	var plain_id := input_property_id(subject, "plain_incoming")
	assert(is_instance_id_valid(plain_id))
	subject.set("plain_incoming", [])
	assert(not is_instance_id_valid(plain_id), "unannotated setter/trampoline must release both copies")
	var array_leaked := is_instance_id_valid(temporary_array(subject))
	var input_leaked := is_instance_id_valid(temporary_input(subject, "borrowed_input"))
	return_text(subject, 32)
	var before := OS.get_static_memory_usage()
	return_text(subject, 2048)
	var string_growth := OS.get_static_memory_usage() - before
	for _i in 1024:
		var bytes: PackedByteArray = subject.call("new_bytes")
		assert(bytes.size() == 4096 and bytes[5] == 73)
		assert(subject.call("echo", "héllo 🌏") == "héllo 🌏")
	var growth := OS.get_static_memory_usage() - before
	print("METHOD_VALUES_RESULT array_leaked=", array_leaked, " input_leaked=", input_leaked, " string_growth_bytes=", string_growth, " total_growth_bytes=", growth)
	subject.free()
	if array_leaked or input_leaked or growth > 65536:
		print("METHOD_VALUES_FAIL ownership")
		if not OS.has_feature("web"): get_tree().quit(1)
		return
	print("METHOD_VALUES_OK")
	if not OS.has_feature("web"): get_tree().quit(0)
