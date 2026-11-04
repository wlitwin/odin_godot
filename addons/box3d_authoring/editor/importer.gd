@tool
class_name Box3DAuthoringArtifactImporter
extends EditorImportPlugin

var services: Box3DEditorServices
func _init(value: Box3DEditorServices=null) -> void:services=value
func _get_importer_name() -> String:return "box3d_authoring.artifact"
func _get_visible_name() -> String:return "Box3D checked owning definition"
func _get_recognized_extensions() -> PackedStringArray:return PackedStringArray(["b3authoring"])
func _get_save_extension() -> String:return "res"
func _get_resource_type() -> String:return "Resource"
func _get_preset_count() -> int:return 1
func _get_preset_name(_index: int) -> String:return "Shared schema/version/hash validation"
func _get_import_options(_path: String,_preset: int) -> Array[Dictionary]:return []
func _import(source_file: String,save_path: String,_options: Dictionary,_variants: Array[String],_generated: Array[String]) -> Error:
	var file:=FileAccess.open(source_file,FileAccess.READ)
	if file==null:return ERR_FILE_CANT_OPEN
	if file.get_length()>4194304:file.close();return ERR_OUT_OF_MEMORY
	var bytes: PackedByteArray=file.get_buffer(file.get_length());file.close()
	var encoded: String=Marshalls.raw_to_base64(bytes)
	var inspected: Dictionary=services.inspect_artifact(encoded) if services!=null else {"ok":false}
	if not inspected.get("ok",false):return ERR_FILE_CORRUPT
	var resource:=Box3DBakeArtifact.new();resource.artifact_base64=encoded;resource.imported_metadata=inspected.metadata.duplicate(true)
	return ResourceSaver.save(resource,save_path+".res")
