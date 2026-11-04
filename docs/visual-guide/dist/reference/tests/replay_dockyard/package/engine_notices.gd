# Run with an existing output directory as the sole user argument.
extends SceneTree
func _initialize():
 var args=OS.get_cmdline_user_args()
 if args.size()!=1:
  quit(2)
  return
 var out=args[0]
 var license_file=FileAccess.open(out+"/godot-license.txt",FileAccess.WRITE)
 if license_file==null:
  quit(3)
  return
 license_file.store_string(Engine.get_license_text())
 license_file.close()
 var notices=FileAccess.open(out+"/godot-compiled-notices.json",FileAccess.WRITE)
 if notices==null:
  quit(4)
  return
 notices.store_string(JSON.stringify({"version":Engine.get_version_info(),"copyright_info":Engine.get_copyright_info(),"license_info":Engine.get_license_info()},"  ")+"\n")
 notices.close()
 print("GODOT_COMPILED_LICENSE_NOTICES_EXTRACTED")
 quit()
