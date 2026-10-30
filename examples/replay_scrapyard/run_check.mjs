import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const fields = line => Object.fromEntries([...line.matchAll(/(\w+)=([^ ]+)/g)].map(m => [m[1], m[2]]));
const rows = ['host','client','observer'].map(role => {
  const log = readFileSync(`${process.argv[2]}/${role}.log`, 'utf8');
  assert.match(log, /REPLAY_SCRAPYARD_COMBAT_PEER_OK/);
  if (role !== 'observer') {
    assert.match(log, /RSY_SHOP_CARD .*floor=1 card=[02]/);
    assert.match(log, /RSY_SHOP_CARD .*floor=2 card=5/);
  }
  const result = fields(log.match(/^RSY_RUN_RESULT .+$/m)[0]);
  for (const [key,value] of Object.entries({run:'1',floor:'1',clears:'2',parts1:'2',parts2:'2',canceled:'1'})) assert.equal(result[key],value);
  return fields(log.match(/^RSY_COMBAT_HASH .+$/m)[0]);
});
for (const row of rows) for (const key of ['tick','hash']) assert.equal(row[key], rows[0][key]);
const scenery = [];
for (const floor of [1, 2, 3]) {
  const peers = ['host', 'client', 'observer'].map(role => JSON.parse(readFileSync(`${process.argv[2]}/scenery-${floor}-${role}.json`, 'utf8')).geometry);
  for (const peer of peers) assert.equal(peer, peers[0]);
  scenery.push(peers[0]);
}
assert.equal(new Set(scenery).size, 3, 'each floor must rebuild its own scenery');
console.log(`RSY_SCENERY_CHECK_OK floors=3 peers=3 geometry=${scenery.join(',')}`);
console.log(`RSY_RUN_CHECK_OK tick=${rows[0].tick} hash=${rows[0].hash}`);
