// Regenerate portable SVG artifacts and refresh the source snapshots.
// Run from anywhere: node docs/visual-guide/prepare.mjs
import { mkdir, readFile, writeFile, copyFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { buildReaders } from './build-readers.mjs';
import { contentFiles, navigationFiles } from './site-structure.mjs';
import { buildProduct } from './build-product.mjs';
const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,'../..');
const dist=path.join(here,'dist');
const escape=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
function diagram(name,title,desc,height,draw,dark=false){
  const c=dark?{ink:'#e7efdd',muted:'#b4c7b4',line:'#597260',bg:'#1c302a',box:'#294237',accent:'#d6ba8b'}:{ink:'#202925',muted:'#58645c',line:'#c8d1c1',bg:'#fafbf7',box:'#eef2e7',accent:'#b84424'};
  const text=(x,y,value,size=13,fill=c.ink,anchor='start',mono=false)=>`<text x="${x}" y="${y}" font-family="${mono?'ui-monospace, SFMono-Regular, Consolas, monospace':'-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif'}" font-size="${size}" fill="${fill}" text-anchor="${anchor}">${escape(value)}</text>`;
  const lines=(x,y,values,size=13,fill=c.ink,spacing=21)=>values.map((value,i)=>text(x,y+i*spacing,value,size,fill)).join('');
  const rect=(x,y,w,h,fill=c.box,stroke=c.line,dash='')=>`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="5" fill="${fill}" stroke="${stroke}"${dash?` stroke-dasharray="${dash}"`:''}/>`;
  const box=(x,y,w,h,label,sub=[],color=c.box)=>rect(x,y,w,h,color)+text(x+17,y+29,label,15)+lines(x+17,y+53,sub,11,c.muted,18);
  const line=(x1,y1,x2,y2,color=c.line,dash='')=>`<path d="M${x1} ${y1}L${x2} ${y2}" fill="none" stroke="${color}" stroke-width="1.5"${dash?` stroke-dasharray="${dash}"`:''}/>`;
  const arrow=(x1,y1,x2,y2,color=c.muted,dash='')=>`<path d="M${x1} ${y1}L${x2} ${y2}" fill="none" stroke="${color}" stroke-width="1.5" marker-end="url(#arrow)"${dash?` stroke-dasharray="${dash}"`:''}/>`;
  const body=draw({c,text,lines,rect,box,line,arrow});
  return writeFile(path.join(dist,'diagrams',name+'.svg'),`<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="${height}" viewBox="0 0 1000 ${height}" role="img" aria-labelledby="title desc"><title id="title">${escape(title)}</title><desc id="desc">${escape(desc)}</desc><defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto-start-reverse"><path d="M0 1L7 4L0 7" fill="none" stroke="${c.muted}" stroke-width="1.2"/></marker></defs><rect width="1000" height="${height}" fill="${c.bg}"/>${body}</svg>\n`);
}
await mkdir(path.join(dist,'diagrams'),{recursive:true});
await diagram('two-models','Two authoring models','Kit synchronizes fields on registered script entities. Replay restores complete frames and presents detached views. Both use sessions and transports to reach other machines.',430,({c,text,box,line,arrow})=>
  text(30,37,'KIT',12,'#365b41','start',true)+text(520,37,'REPLAY',12,c.accent,'start',true)+
  text(30,65,'Start with the game object.',22)+text(520,65,'Start with the simulation.',22)+
  line(495,25,495,395)+
  box(30,92,205,78,'Godot nodes',['Player · Chest · Ball'])+box(270,92,205,78,'Script structs',['State + free procedures'])+arrow(235,130,268,130)+
  box(30,212,445,83,'Registry + generated protocol',['owner fields / replicated fields / commands'])+arrow(372,170,372,210)+
  text(44,194,'Each field declares its writer.',11,c.muted)+
  box(520,92,445,78,'World at tick T',['Players · pools · inventories · timers · RNG'])+
  box(520,212,205,83,'step(world, input)',['Record the next frame'])+box(760,212,205,83,'Godot views',['Nodes · animation · audio'])+
  arrow(625,170,625,210)+arrow(725,252,758,252)+text(748,198,'copies + occurrences',10,c.muted,'middle')+
  arrow(255,295,255,335)+arrow(625,295,625,335)+
  box(30,338,445,58,'Session / transport → other machines',[],'#e5eadd')+
  box(520,338,445,58,'Runner / transport → other machines',[],'#f1e4d8')+
  text(30,418,'Field-level declarations',10,c.muted,'start',true)+text(520,418,'Complete-frame history',10,c.muted,'start',true));
await diagram('engine-boundary','From Odin source to a Godot scene','Scriptgen generates bindings. The Odin compiler builds a scripts library. The core GDExtension loads it and bridges the scene tree. Pure Replay models also run without Godot.',320,({c,text,box,arrow})=>
  text(30,34,'BUILD TIME',10,c.accent,'start',true)+
  box(30,60,185,86,'scripts/*.odin',['Structs + procedures'])+arrow(215,103,248,103)+
  box(250,60,200,86,'scriptgen',['Registration + bindings'])+arrow(450,103,483,103)+
  box(485,60,200,86,'Odin compiler',['Authored + generated code'])+arrow(685,103,718,103)+
  box(720,60,250,86,'Scripts library',['libodinscripts · platform binary'])+
  arrow(845,146,845,207)+text(858,184,'loaded by',11,c.muted)+
  box(720,210,250,81,'Core GDExtension',['odin_godot · language + loader'])+arrow(720,250,687,250)+
  box(485,210,200,81,'Godot scene tree',['Nodes · editor · signals'])+
  text(30,203,'ENGINE-FREE PATH',10,c.accent,'start',true)+box(30,221,385,70,'Pure Replay model → Odin executable',['Same gameplay; no scenes or sockets required.']));
await diagram('kit-pickup','A Kit command from prediction to authority','The client predicts only the target chest. The authority validates and mutates the chest, then credits the bag in its command hook. Accepted fields replicate; rejection reverts the client target.',490,({c,text,box,line,arrow})=>
  text(175,34,'CLIENT',11,'#2461d9','middle',true)+text(550,34,'AUTHORITY',11,c.accent,'middle',true)+text(840,34,'SHARED STATE',11,c.muted,'middle',true)+
  line(175,52,175,410)+line(550,52,550,410)+line(840,52,840,410)+
  box(48,72,254,61,'Predict chest_take',['Change the chest target only.'],'#e9f0fb')+
  arrow(175,157,550,157)+text(350,146,'Take(slot, count, position)',11,c.muted,'middle',true)+
  box(433,185,234,66,'Check + mutate chest',['Range · availability · predicate'])+arrow(550,166,550,183)+
  arrow(550,251,550,272)+box(433,275,234,66,'Authority command hook',['On success: credit the bag.'])+
  arrow(667,307,840,307)+text(752,293,'accepted fields',10,c.muted,'middle')+
  arrow(550,375,175,375)+text(350,364,'Verdict + authoritative target state',11,c.muted,'middle')+
  text(48,441,'ACCEPT',10,'#365b41','start',true)+text(128,441,'Prediction stands; replicated fields converge.',12)+
  text(48,469,'REJECT',10,c.accent,'start',true)+text(128,469,'Revert the chest prediction; no bag credit is issued.',12));
await diagram('frame-boundary','Inside and outside a Replay frame','The World holds all mutable gameplay dependencies: player values, chest existence, allocation metadata, timers, RNG, and scheduled work. Immutable content is versioned. Godot, transport, and storage are external.',420,({c,text,box,rect,arrow})=>
  rect(30,38,590,300,'#223a30','#718965','6 5')+text(50,69,'FRAME / WORLD AT TICK T',11,'#d6ba8b','start',true)+
  box(50,92,265,84,'Players + inventories',['Position · health · bags'])+box(335,92,265,84,'Entity lifetime',['Chest present? · pool generations'])+
  box(50,199,265,84,'RNG + cooldowns',['Values that affect later ticks'])+box(335,199,265,84,'Scheduled work',['Timers · pending simulation work'])+
  text(50,316,'Restored together; stepped together.',12,c.muted)+
  box(690,38,280,74,'Immutable definitions',['Content-versioned session inputs'])+arrow(690,85,622,85)+
  box(690,169,280,86,'Godot presentation',['Nodes · resources · sound · UI'])+arrow(620,211,688,211)+text(652,190,'views',10,c.muted,'middle')+
  box(690,304,280,74,'Session / I/O owners',['Connections · storage · authority'])+
  text(30,387,'INPUT + PREVIOUS FRAME',10,'#d6ba8b','start',true)+arrow(235,382,340,382)+text(365,387,'step',14)+arrow(411,382,512,382)+text(535,387,'NEXT FRAME + OCCURRENCES',10,'#d6ba8b','start',true),true);
await diagram('authority-path','Replay authoritative runner','The client samples controls and issues actions, predicts through its runner, stores complete history and draws copied views. The authority steps the same game model and returns authoritative state and occurrence history. Verified corrections replace a checkpoint and replay the client suffix.',450,({c,text,box,rect,arrow,line})=>
  rect(30,40,460,367,'#fafbf7',c.line,'5 5')+rect(620,40,350,367,'#fafbf7',c.line,'5 5')+
  text(50,68,'PREDICTING CLIENT',11,'#2461d9','start',true)+text(640,68,'AUTHORITY',11,c.accent,'start',true)+
  box(50,92,220,76,'Sample / issue intent',['Controls: tick · actions: sequence'])+
  arrow(270,128,643,128)+text(448,111,'admitted input',11,c.muted,'middle')+
  arrow(155,168,155,221)+text(170,198,'local response',11,c.muted)+
  box(50,224,200,80,'Prediction runner',['Step the same game model'])+arrow(250,263,283,263)+
  box(285,224,185,80,'Frame history',['State + input + events'])+
  arrow(378,304,378,333)+box(285,336,185,54,'Godot views',[])+
  box(645,92,300,76,'Authority runner',['Validate · order · step game model'])+
  arrow(795,168,795,221)+box(645,224,300,80,'Settled state + occurrences',['Recorded decisions and complete facts'])+
  arrow(645,263,472,263)+text(554,242,'verify + correct',11,c.muted,'middle')+
  text(645,344,'Snapshots / occurrence history',12,c.muted)+text(645,368,'Separate state and presentation frontiers.',11,c.muted)+
  text(30,437,'Server-authoritative policy. Cooperative body streams and deterministic peers use different contracts.',11,c.muted));
await diagram('correction','Restore and replay a speculative suffix','The old timeline has player A winning at tick one. Restore frame zero, replace the input, replay ticks one through eight with player B winning. Compare occurrence identities and replace or cancel effects outside the simulation.',360,({c,text,rect,arrow,line})=>{
  let out=text(30,35,'A REVISED INPUT AT TICK 1',11,c.accent,'start',true)+text(30,72,'Predicted',13)+text(30,186,'Rebuilt',13)+text(30,302,'Effects',13);
  const start=175,w=64,gap=23;
  for(let tick=0;tick<=8;tick++){
    const x=start+tick*(w+gap);
    out+=rect(x,45,w,56,tick?'#e9f0fb':'#e5eadd',c.line,tick?'4 3':'')+text(x+w/2,67,`T${tick}`,11,c.muted,'middle',true)+text(x+w/2,88,tick?'A: 5':'A: 0',11,'#2461d9','middle',true);
    out+=rect(x,159,w,56,tick?'#f3e4d8':'#e5eadd',c.line)+text(x+w/2,181,`T${tick}`,11,c.muted,'middle',true)+text(x+w/2,202,tick?'B: 5':'B: 0',11,tick?c.accent:c.muted,'middle',true);
    if(tick<8)out+=arrow(x+w+2,187,x+w+gap-3,187);
  }
  out+=arrow(207,103,207,155)+text(229,134,'Restore T0. Replace input 1. Stage the complete suffix before publishing.',12,c.muted);
  out+=line(175,249,935,249)+text(175,280,'Cancel A’s take',13,c.accent)+text(455,280,'Begin B’s take',13,c.accent)+text(715,280,'Keep unchanged effects',13,'#365b41');
  out+=text(175,307,'Identity changes at tick 1.',11,c.muted)+text(455,307,'New winner, new occurrence.',11,c.muted)+text(715,307,'Same ID + payload → no duplicate.',11,c.muted);
  out+=text(175,344,'Local input revision illustrates the mechanism. Network correction ingests verified authority state.',11,c.muted);
  return out;
});

const files=[...new Set([
  ...contentFiles, ...navigationFiles,
  'docs/getting-started.md','docs/onboarding/02-thinking-in-structs.md',
  'docs/onboarding/04-verbs-not-rpcs.md','docs/kit/quickstart.md',
  'docs/kit/quickstart-sim.md','docs/kit/timelines.md','docs/replay/architecture.md',
  'docs/replay/owner-streams.md','docs/replay/framework-audit.md',
  'replay/README.md','replay/getting-started.md','replay/view/README.md',
  'examples/hello_net/scripts/player.odin','examples/hello_sim/scripts/player.odin',
  'examples/replay_loot/README.md','examples/replay_loot/main.odin',
  'examples/replay_loot/game/game.odin','examples/replay_hello/README.md',
  'examples/replay_hello/shared/hello/network.odin','examples/replay_recipes/README.md',
  'examples/replay_scrapyard/README.md','examples/replay_scrapyard/contributor-guide.md',
  'examples/replay_scrapyard/code-guide.md'
])];
const revision=execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim();
// Changes to the guide itself are not changes to its reference source baseline.
const dirty=Boolean(execFileSync('git',['status','--porcelain','--',...files],{cwd:root,encoding:'utf8'}).trim());
const manifest=await buildReaders({root,dist,seeds:files,revision,dirty,date:new Date().toISOString().slice(0,10)});
const index=path.join(dist,'guide.html');
const html=(await readFile(index,'utf8')).replace(/reference\.html\?file=([^"\s<>]+)/g,(link,file)=>manifest.pages[decodeURIComponent(file)] || link);
await writeFile(index,html);
await buildProduct(dist);
console.log(`Generated 6 field-guide SVG diagrams and reading pages at ${revision.slice(0,12)}.`);
