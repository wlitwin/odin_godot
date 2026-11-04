extends SceneTree

func need(ok:bool, message:String)->bool:
 if not ok:
  push_error("MANAGED_CALLBACK_FAIL: "+message)
  quit(1)
 return ok

func _init()->void:
 process_frame.connect(run,CONNECT_ONE_SHOT)

func run()->void:
 var source=load("res://scripts/source.odin")
 var a=Node.new()
 a.set_script(source);root.add_child(a)
 var b=Node.new()
 b.set_script(load("res://modules/consumer/consumer.odin"));root.add_child(b)
 if not need(bool(b.call("consumer_baseline")),"initial accounting"):return
 if not need(int(a.call("source_make",false,false))==0,"factory"):return
 if not need(bool(b.call("consumer_accept",a.call("source_take"))),"transfer"):return
 if not need(bool(b.call("consumer_wrong_thread")) and bool(b.call("consumer_forged")),"denied handle use preserves owner"):return
 var callback:Callable=b.call("consumer_value")
 if not need(callback.is_valid() and int(callback.call(17))==1018,"actual Godot callback arguments/result"):return
 if not need(int(callback.call(-7))==8008,"reentrant close BUSY"):return
 a.free()
 await process_frame
 if not need(int(callback.call(8))==1011,"source-free retained userdata"):return
 if "--reload" in OS.get_cmdline_user_args():
  var output=[]
  var rc=OS.execute("bash",[ProjectSettings.globalize_path("res://rebuild_source.sh")],output,true)
  if not need(rc==0,"rebuild "+"\n".join(output)):return
  if not need(source.reload(true)==OK,"reload"):return
  var replacement=Node.new();replacement.set_script(source);root.add_child(replacement)
  if not need(int(replacement.call("source_brand"))==2,"replacement generation"):return
  if not need(int(callback.call(9))==1013,"old generation callback after reload"):return
  replacement.free()
 var emitter=Node.new()
 emitter.add_user_signal("pulse",[{"name":"value","type":TYPE_INT}]);root.add_child(emitter)
 if not need(emitter.connect("pulse",callback)==OK,"actual Godot signal connect"):return
 emitter.emit_signal("pulse",51)
 emitter.disconnect("pulse",callback);emitter.free()
 if not need(bool(b.call("consumer_clone_worker")),"worker copy"):return
 print("MANAGED_CALLBACK_CLOSE_BEGIN")
 if not need(int(b.call("consumer_close"))==0,"whole producer destruction"):return
 print("MANAGED_CALLBACK_CLOSE_RETURNED")
 if not need(not callback.is_valid(),"closed engine copy inert"):return
 callback=Callable()
 if not need(bool(b.call("consumer_free_worker")),"off-main final free"):return
 if not need(int(b.call("consumer_collect"))==0 and int(b.call("consumer_live"))==0,"final metadata collected"):return
 # Declining data lease cleanup must keep handle and avoid a second payload dtor.
 var d=Node.new();d.set_script(source);root.add_child(d)
 if not need(int(d.call("source_make",true,false))==0,"declined factory"):return
 if not need(bool(b.call("consumer_accept",d.call("source_take"))),"declined transfer"):return
 d.free()
 if not need(int(b.call("consumer_close"))==4,"declined lease preserves cleanup"):return
 if not need(int(b.call("consumer_close"))==0,"cleanup retry"):return
 if not need(int(b.call("consumer_collect"))==0 and int(b.call("consumer_live"))==0,"declined teardown"):return
 # A source-bound weak owner cannot execute after source destruction.
 var weak=Node.new();weak.set_script(source);root.add_child(weak)
 if not need(int(weak.call("source_make",false,true))==0,"weak factory"):return
 if not need(bool(b.call("consumer_accept",weak.call("source_take"))),"weak transfer"):return
 var weak_callback:Callable=b.call("consumer_value")
 weak.free()
 if not need(not weak_callback.is_valid(),"weak source invalidation"):return
 if not need(int(b.call("consumer_close"))==0,"weak cleanup still safe"):return
 weak_callback=Callable()
 if not need(int(b.call("consumer_collect"))==0 and int(b.call("consumer_live"))==0,"all controls empty"):return
 var bounded=Node.new();bounded.set_script(source);root.add_child(bounded)
 if not need(int(bounded.call("source_bounds"))==0,"bounded capacity/failed create/stale generation"):return
 bounded.free()
 if not need(int(b.call("consumer_collect"))==0 and int(b.call("consumer_live"))==0,"bounded owners empty"):return
 if not need(bool(b.call("consumer_clean")),"host live returned to fixed baseline, native/reservations zero"):return
 print("MANAGED_CALLBACKS_OK storage_bytes=",b.call("consumer_storage")," cookie=",b.call("consumer_cookie"))
 b.free()
 quit(0)
