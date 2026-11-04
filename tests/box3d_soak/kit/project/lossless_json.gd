extends RefCounted

# TEST DIAGNOSTIC composition only. Values are original JSON tokens, never
# numeric Variants. In particular, uint64 Native cookies/tokens/timestamps do
# not pass through Godot's JSON floating point decoder.
const UINT64_EDGES := ["0","9007199254740991","9007199254740992","9007199254740993","9223372036854775807","9223372036854775808","18446744073709551615"]

static func _ws(text: String, at: int) -> int:
	while at<text.length() and text[at] in [" ","\t","\r","\n"]: at+=1
	return at

static func _string_end(text: String, at: int) -> int:
	if at>=text.length() or text[at]!='"': return -1
	at+=1
	while at<text.length():
		if text[at]=='"': return at+1
		if text[at]=='\\': at+=2
		else: at+=1
	return -1

static func _value_end(text: String, at: int) -> int:
	if at>=text.length(): return -1
	if text[at]=='"': return _string_end(text,at)
	if text[at] in ["{","["]:
		var closers: Array[String] = []
		while at<text.length():
			var ch := text[at]
			if ch=='"':
				at=_string_end(text,at)
				if at<0: return -1
				continue
			if ch=="{": closers.append("}")
			elif ch=="[": closers.append("]")
			elif ch in ["}","]"]:
				if closers.is_empty() or closers.pop_back()!=ch: return -1
				if closers.is_empty(): return at+1
			at+=1
		return -1
	var start := at
	while at<text.length() and not text[at] in [",","}","]"," ","\t","\r","\n"]: at+=1
	return at if at>start else -1

static func fields(text: String) -> Dictionary:
	var out: Dictionary = {}
	var at := _ws(text,0)
	if at>=text.length() or text[at]!="{": return {"ok":false}
	at=_ws(text,at+1)
	if at<text.length() and text[at]=="}": return {"ok":_ws(text,at+1)==text.length(),"fields":out}
	while at<text.length():
		var end := _string_end(text,at)
		if end<0: return {"ok":false}
		# Decode ONLY a JSON string key. No numeric token is ever decoded.
		var key = JSON.parse_string(text.substr(at,end-at))
		if not key is String or out.has(key): return {"ok":false}
		at=_ws(text,end)
		if at>=text.length() or text[at]!=":": return {"ok":false}
		at=_ws(text,at+1)
		end=_value_end(text,at)
		if end<0: return {"ok":false}
		out[key]=text.substr(at,end-at)
		at=_ws(text,end)
		if at>=text.length(): return {"ok":false}
		if text[at]=="}": return {"ok":_ws(text,at+1)==text.length(),"fields":out}
		if text[at]!=",": return {"ok":false}
		at=_ws(text,at+1)
	return {"ok":false}

static func compose(raw_fields: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in raw_fields: parts.append(JSON.stringify(str(key))+":"+str(raw_fields[key]))
	return "{"+",".join(parts)+"}"

static func compact(text: String) -> String:
	# JSONL framing only: remove insignificant whitespace outside strings.
	# Numeric tokens and the already-compact original Odin Native JSON are
	# unchanged. Escaped/string whitespace remains byte-for-byte intact.
	var parts := PackedStringArray()
	var at := 0
	while at<text.length():
		if text[at]=='"':
			var end := _string_end(text,at)
			if end<0: return ""
			parts.append(text.substr(at,end-at));at=end
		else:
			if not text[at] in [" ","\t","\r","\n"]: parts.append(text[at])
			at+=1
	return "".join(parts)

static func merge(text: String, replacements: Dictionary, remove: Array = []) -> String:
	var split := fields(text)
	if not split.get("ok",false): return ""
	var result: Dictionary = split.fields
	for key in remove: result.erase(key)
	for key in replacements: result[key]=replacements[key]
	return compose(result)

static func token(text: String, key: String, fallback: String = "null") -> String:
	var split := fields(text)
	return split.fields.get(key,fallback) if split.get("ok",false) else fallback

static func array(raw_values: Array) -> String:
	return "["+",".join(PackedStringArray(raw_values))+"]"

static func controls() -> bool:
	for value in UINT64_EDGES:
		var nested: String = '{"cookie":'+str(value)+'}'
		var original: String = '{"token":'+str(value)+',"nested":'+nested+',"text":"quote\\\"\\\\","array":[1,{"v":2}]}'
		var edited := merge(original,{"seq":"19"})
		if edited.is_empty() or token(edited,"token")!=value or token(edited,"nested")!=nested or token(edited,"seq")!="19": return false
	return not fields('{"token":1,"token":2}').get("ok",true) and not fields('{"token":1').get("ok",true)
