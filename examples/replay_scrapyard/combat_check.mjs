import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const fields = line => Object.fromEntries([...line.matchAll(/(\w+)=([^ ]+)/g)].map(m => [m[1], m[2]]));
const rows = ['host', 'client', 'observer'].map(role => {
  const log = readFileSync(`${process.argv[2]}/${role}.log`, 'utf8');
  assert.match(log, /REPLAY_SCRAPYARD_COMBAT_PEER_OK/);
  const result = fields(log.match(/^RSY_COMBAT_RESULT .+$/m)[0]);
  const hash = fields(log.match(/^RSY_COMBAT_HASH .+$/m)[0]);
  const content = fields(log.match(/^RSY_CONTENT_LOADED .+$/m)[0]);
  if (result.armory === 'mend') {
    assert.equal(result.damage, '0'); assert.equal(result.scrap, '0');
    assert.equal(Number(result.kills1) + Number(result.kills2), 0);
    assert.equal(result.shots1, '0'); assert.ok(Number(result.healed2) > 0);
    assert.ok(Number(result.historical2) > 0);
  } else {
    let damage = 29, scrap = 12, kills = 4;
    if (result.encounter === 'mixed') {damage = 27; scrap = 9; kills = 3; assert.ok(Number(result.spits) > 0 && Number(result.pops) > 0);}
    if (result.encounter === 'boss') {
      const adds = Number(result.adds); damage = 36 + 3 * adds; scrap = 15 + 3 * adds; kills = 1 + adds;
      assert.ok(Number(result.slams) > 0 && adds >= 2); assert.equal(result.cores, '6');
    }
    if (result.encounter === 'barrels') {damage = 28; scrap = 3; kills = 1; assert.equal(result.barrels, '2'); assert.ok(Number(result.dots) > 0 && Number(result.status) > 0);}
    assert.equal(Number(result.damage), damage); assert.equal(Number(result.scrap), scrap);
    assert.equal(Number(result.kills1) + Number(result.kills2), kills);
    if (result.armory === 'ordnance') {assert.ok(Number(result.blasts1) > 0); assert.ok(Number(result.historical2) > 0);}
  }
  assert.equal(Number(result.effects), Number(result.shots1) + Number(result.shots2));
  return {result, hash, content};
});
for (const row of rows) {
  assert.deepEqual(row.content, rows[0].content);
  for (const key of ['tick', 'hash']) assert.equal(row.hash[key], rows[0].hash[key]);
  for (const key of ['encounter', 'spits', 'pops', 'slams', 'adds', 'barrels', 'dots', 'status', 'cores', 'armory', 'shots1', 'shots2', 'kills1', 'kills2', 'blasts1', 'rails2', 'historical2', 'healed2', 'rejected2']) assert.equal(row.result[key], rows[0].result[key]);
}
console.log(`RSY_COMBAT_CHECK_OK tick=${rows[0].hash.tick} hash=${rows[0].hash.hash} shots=${rows[0].result.shots1}/${rows[0].result.shots2}`);
