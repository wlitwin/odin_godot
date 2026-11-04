@tool
class_name Box3DBakeArtifact
extends Resource

@export var format_version: int=1
@export_multiline var artifact_base64: String=""
@export var imported_metadata: Dictionary={}
# Metadata is informational. Actual use must validate artifact_base64 through
# the shared tool/import API; never trust editable metadata or native pointers.
func inspect_with(services: Box3DEditorServices) -> Dictionary:
	if format_version!=1 or artifact_base64.length()>4194304:return {"ok":false,"diagnostic":{"error":"ArtifactVersionOrCapacity","field":"artifact"}}
	return services.inspect_artifact(artifact_base64)
