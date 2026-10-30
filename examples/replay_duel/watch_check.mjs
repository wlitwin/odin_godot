import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {join} from 'node:path';

const [directory, blackout] = process.argv.slice(2);
const player = readFileSync(join(directory, 'listen.log'), 'utf8');
const watched = readFileSync(join(directory, 'watch.log'), 'utf8');
const fields = text => Object.fromEntries([...text.matchAll(/([a-z_]+)=([0-9,]+)/g)].map(m => [m[1], m[2]]));
const reference = fields(player.match(/^RDP_RESULT .+$/m)?.[0] ?? '');
const result = fields(watched.match(/^RDP_WATCH_RESULT .+$/m)?.[0] ?? '');
assert.match(watched, /REPLAY_DUEL_WATCH_OK/);
for (const key of ['tick', 'hash', 'shots', 'hits', 'kills']) assert.equal(result[key], reference[key], key);
assert.ok(Number(result.installs) > 1 && Number(result.replayed) > 0);
const resets = [...watched.matchAll(/^RDP_WATCH_RESET .+$/gm)].map(m => fields(m[0]));
assert.ok(Number(resets[0]?.baseline) >= 150, 'watcher must join an already-running match');
if (Number(blackout) > 0) {
  assert.match(watched, /RDP_WATCH_BLACKOUT/); assert.match(watched, /RDP_WATCH_LINK_RESTORED/);
  assert.ok(resets.some(r => Number(r.sequence) > 1 && Number(r.baseline) - Number(r.previous) > 128), 'players must advance beyond retained history during spectator blackout');
  assert.ok(Number(result.tick) - Number(resets.at(-1).baseline) >= 128, 'spectator must continue after recovering');
  assert.ok(Number(result.visible_shots) > 0, 'new shot occurrences must follow the recovered baseline');
}
console.log(`RDP_WATCH_CHECK_OK tick=${result.tick} hash=${result.hash} installs=${result.installs} resets=${result.resets} skipped=${result.skipped}`);
