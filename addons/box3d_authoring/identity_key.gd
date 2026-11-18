@tool
class_name Box3DIdentityKey
extends RefCounted

static func fresh(kind: String) -> String:
	return kind + "_" + Crypto.new().generate_random_bytes(12).hex_encode()

static func initial(kind: String) -> String:
	# Loaded properties replace this value. Runtime construction still requires
	# authored keys; extraction and validation never manufacture identity.
	return fresh(kind) if Engine.is_editor_hint() else ""
