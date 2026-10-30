// Explicit participant-file import, isolated to this example's origin. A file is
// committed to IndexedDB before navigation; resume reads it into a bounded buffer.
const REPLAY_DUEL_ARCHIVE_LIMIT = 16 * 1024 * 1024;
function replayDuelDatabase() {
 return new Promise((resolve,reject)=>{
  const request=indexedDB.open('replay-duel-participant-upload-v1',1);
  request.onupgradeneeded=()=>request.result.createObjectStore('files');
  request.onerror=()=>reject(request.error);
  request.onsuccess=()=>resolve(request.result);
 });
}
async function replayDuelUpload(file) {
 if (!file || file.size<1 || file.size>REPLAY_DUEL_ARCHIVE_LIMIT) throw new Error('Choose a participant archive up to 16 MiB.');
 const bytes=await file.arrayBuffer(),db=await replayDuelDatabase();
 try {
  await new Promise((resolve,reject)=>{
   const tx=db.transaction('files','readwrite');tx.objectStore('files').put(bytes,'participant');
   tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error||new Error('Import aborted'));
  });
 } finally {db.close();}
}
if (new URLSearchParams(location.search).get('stage')==='resume') {
 globalThis.replayDuelArchiveState=0;
 (async()=>{
  const db=await replayDuelDatabase();
  try {
   const bytes=await new Promise((resolve,reject)=>{
    const request=db.transaction('files','readonly').objectStore('files').get('participant');
    request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error);
   });
   if (!(bytes instanceof ArrayBuffer) || bytes.byteLength<1 || bytes.byteLength>REPLAY_DUEL_ARCHIVE_LIMIT) throw new Error('Missing participant archive');
   globalThis.replayDuelArchive=new Uint8Array(bytes);globalThis.replayDuelArchiveState=1;
  } finally {db.close();}
 })().catch(error=>{globalThis.replayDuelArchiveState=-1;console.error('REPLAY_DUEL_ARCHIVE_IMPORT_FAIL',String(error));});
}

// Credentials are personal to this browser tab and never copied into join URLs.
function replayDuelCredentialValid(value) {
 return value && [1,2].includes(value.member) && Number.isSafeInteger(value.incarnation) && value.incarnation>0 &&
  typeof value.key==='string' && /^[0-9a-f]{64}$/.test(value.key) && !/^0+$/.test(value.key);
}
function replayDuelCredentialLoad() {
 try {const value=JSON.parse(sessionStorage.getItem('replay-duel-admission'));return replayDuelCredentialValid(value)?value:null;}catch{return null;}
}
async function replayDuelCredentialImport(file) {
 if(!file || file.size<1 || file.size>2048)throw new Error('Choose a participant credential file up to 2 KiB.');
 const value=JSON.parse(await file.text());if(!replayDuelCredentialValid(value))throw new Error('Invalid participant credential.');
 sessionStorage.setItem('replay-duel-admission',JSON.stringify({member:value.member,incarnation:value.incarnation,key:value.key}));
}
if (new URLSearchParams(location.search).get('auth') === '1') globalThis.replayDuelCredential=replayDuelCredentialLoad();

// Godot UI callbacks run outside the DOM input event on Web. Keep clipboard
// writes in a native click handler, and always offer a selectable fallback.
function replayDuelShowInvite(url) {
 document.querySelector('#replay-duel-share')?.remove();
 const dialog=document.createElement('dialog');dialog.id='replay-duel-share';
 dialog.style.cssText='max-width:34rem;width:85%;background:#172937;color:#e3edf7;border:1px solid #4b6478;border-radius:.5rem;padding:1.5rem;font:16px system-ui';
 const title=document.createElement('h2');title.textContent='Invite the other player';dialog.append(title);
 const label=document.createElement('label');label.textContent='Match invitation';
 const input=document.createElement('input');input.id='replay-duel-share-link';input.readOnly=true;input.value=url;input.style.cssText='display:block;width:100%;box-sizing:border-box;margin:1rem 0;padding:.6rem';label.append(input);dialog.append(label);
 const note=document.createElement('p');note.setAttribute('role','status');
 const copy=document.createElement('button');copy.id='replay-duel-share-copy';copy.textContent='Copy invitation';
 copy.onclick=async()=>{try{await navigator.clipboard.writeText(url);note.textContent='Invitation copied.';}catch{input.focus();input.select();note.textContent='Select and copy the invitation above.';}};
 const close=document.createElement('button');close.textContent='Close';close.style.marginLeft='.6rem';close.onclick=()=>dialog.close();
 dialog.append(copy,close,note);document.body.append(dialog);dialog.showModal();input.focus();input.select();
}
