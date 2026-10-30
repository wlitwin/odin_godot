import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const root=process.argv[2];
const texts=['host','client','observer'].map(role=>{
  assert.match(readFileSync(`${root}/${role}.log`,'utf8'),/REPLAY_SCRAPYARD_COMBAT_PEER_OK/);
  return JSON.parse(readFileSync(`${root}/chat-${role}.json`,'utf8')).text;
});
for(const text of texts)assert.equal(text,texts[0]);
console.log('RSY_CHAT_CHECK_OK identical_history=true peers=3');
