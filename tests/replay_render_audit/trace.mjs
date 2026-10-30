// Read-only diagnostic: records attempted ARRAY/ELEMENT buffer target changes.
// It forwards calls unchanged and never consumes the WebGL error queue.
export function installBufferTrace(){
 const first=new WeakMap(),reported=new WeakSet();let next=0;
 globalThis.bufferTrace={binds:0,conflicts:0,records:[]};
 for(const type of [globalThis.WebGLRenderingContext,globalThis.WebGL2RenderingContext]){
  if(!type||!Object.hasOwn(type.prototype,"bindBuffer"))continue;const prototype=type.prototype,original=prototype.bindBuffer;
  prototype.bindBuffer=function(target,buffer){
   const result=globalThis.bufferTrace;result.binds++;
   if(buffer&&(target===34962||target===34963)){
    const previous=first.get(buffer);
    if(!previous)first.set(buffer,{target,id:++next,stack:new Error('first buffer target').stack});
    else if(previous.target!==target){
     result.conflicts++;
     if(!reported.has(buffer)&&result.records.length<20){reported.add(buffer);result.records.push({...previous,attempted:target,stackAfter:new Error('buffer target change').stack});}
    }
   }
   return original.call(this,target,buffer);
  };
 }
}
