import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const fields = line => Object.fromEntries([...line.matchAll(/(\w+)=([^ ]+)/g)].map(m => [m[1], m[2]]));
const storm = process.env.RSY_STORM === '1';
const rows = ['host', 'client', 'support', 'observer'].map(role => {
  const log = readFileSync(`${process.argv[2]}/${role}.log`, 'utf8');
  assert.match(log, /REPLAY_SCRAPYARD_COMBAT_PEER_OK/);
  const result = fields(log.match(/^RSY_ABILITY_RESULT .+$/m)[0]);
  const hash = fields(log.match(/^RSY_COMBAT_HASH .+$/m)[0]);
  for (const [key, value] of Object.entries({casts:storm ? '9' : '7', landed:'3', zones:'1', pulses:'11', damage1:storm ? '0' : '102', hp3:'10', surge:'1', doused:storm ? '1' : '0'})) assert.equal(result[key], value);
  assert.ok(Number(result.reactions) >= (storm ? 9 : 7) && Number(result.damage2) >= (storm ? 102 : 1));
  if (storm) {assert.match(log, /RSY_SHATTER_CREDIT .*seat=2 damage=102/); assert.match(log, /RSY_DOUSE_SEEN/);}
  if (role === 'observer') {assert.equal(result.late_zone, '1'); assert.match(log, /RSY_ABILITY_LATE_ZONE left=[1-9]/);}
  return {result, hash};
});
for (const row of rows) for (const key of ['tick', 'hash']) assert.equal(row.hash[key], rows[0].hash[key]);
console.log(`RSY_ABILITIES_CHECK_OK tick=${rows[0].hash.tick} hash=${rows[0].hash.hash}`);
