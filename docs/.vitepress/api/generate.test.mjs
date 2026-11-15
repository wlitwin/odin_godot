import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import path from 'node:path'
import { test } from 'node:test'
import { cache, catalog, extract, generate, sources } from './generate.mjs'

const files = extract([
  'tools/api-docs/testdata/declarations.odin',
  'tools/api-docs/testdata/private.odin',
], path.join(cache, 'test-declarations.json'))
const [pkg] = catalog(files)
const symbol = (name) => pkg.symbols.find((entry) => entry.name === name)

test('public reference excludes private declarations and private files', () => {
  assert.ok(symbol('State'))
  assert.equal(symbol('hidden'), undefined)
  assert.equal(symbol('Private_File_Type'), undefined)
  assert.equal(symbol('choose_u64'), undefined)
})

test('signatures preserve generics, defaults, results, and constraints without bodies', () => {
  const signature = symbol('advance').signature
  assert.match(signature, /state: \^State\(\$T\)/)
  assert.match(signature, /count: int = 3/)
  assert.match(signature, /-> \(value: T, ok: bool\) where size_of\(T\) > 0/)
  assert.ok(!signature.includes('SECRET_BODY_MARKER'))
  assert.equal(symbol('State32').kind, 'alias')
  assert.equal(symbol('Callback').kind, 'type')
})

test('member notes do not inherit the previous field trailing comment', () => {
  const members = symbol('State').members
  assert.equal(members.find((member) => member.name === 'value').docs, 'The current value.')
  assert.equal(members.find((member) => member.name === 'count').docs, 'Current item count.')
  assert.equal(members.find((member) => member.name === 'dirty').docs, 'Whether the value changed.')
  assert.match(symbol('State').signature, /count: int/)
  assert.equal(symbol('Kind').members.find((member) => member.name === 'Replay').docs, 'Rebuilt from history.')
})

test('conditional declarations retain both signatures and their build conditions', () => {
  const variants = pkg.symbols.filter((entry) => entry.name === 'platform_open')
  assert.equal(variants.length, 2)
  assert.match(variants[0].signature, /value: u32/)
  assert.match(variants[1].signature, /value: u64/)
  assert.match(variants[0].condition, /#\+build windows, darwin/)
  assert.match(variants[1].condition, /!\(ODIN_OS == \.Windows\)/)
})

test('public overload groups retain signatures of private implementations', () => {
  assert.deepEqual(symbol('choose').overloads, ['choose_u32', 'choose_u64'])
  assert.ok(pkg.all.get('choose_u64').every((entry) => entry.private))
})

test('malformed source stops generation rather than publishing a partial API', () => {
  assert.throws(() => extract(['tools/api-docs/testdata/malformed.txt'], path.join(cache, 'invalid.json'), { stdio: 'pipe' }))
})

test('source discovery excludes generated engine bindings, tests, and internal packages', () => {
  const files = sources()
  assert.ok(files.includes('godot/Ergonomics.odin'))
  assert.ok(files.includes('box3d/world.odin'))
  assert.ok(files.includes('replay/godot/session.odin'))
  assert.ok(!files.some((file) => file.endsWith('.gen.odin') || file.includes('/tests/') || file.includes('/internal/')))
})

test('search targets correspond to generated source anchors', () => {
  generate()
  const search = JSON.parse(readFileSync(path.join(cache, 'search.json'), 'utf8'))
  for (const name of ['world_step_fixed', 'Timeline', 'session_open', 'subscribe']) {
    const entries = search.filter((entry) => entry.name === name)
    assert.ok(entries.length > 0, name)
    for (const entry of entries) {
      const [route, anchor] = entry.url.split('#')
      const file = path.resolve('..', 'docs', route.slice(1).replace(/\.html$/, '.md'))
      assert.ok(readFileSync(file, 'utf8').includes(`<a id="${anchor}"></a>`), entry.url)
    }
  }
})
