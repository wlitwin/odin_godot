import { createHash } from 'node:crypto'
import { execFileSync, spawnSync } from 'node:child_process'
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import MarkdownIt from 'markdown-it'
import { descriptions, guides, layers, roots } from './catalog.mjs'

export const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..')
export const docs = path.join(repo, 'docs')
export const cache = path.join(docs, '.vitepress/cache/api')
export const output = path.join(docs, 'api/generated')
const sourceBase = 'https://github.com/wlitwin/odin_godot/blob/main/'
const schema = 1
const types = new Set(['struct', 'enum', 'union', 'type'])
const compare = (a, b) => a < b ? -1 : a > b ? 1 : 0
const escape = (value) => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;')
const hash = (value) => createHash('sha256').update(value).digest('hex')
const anchor = (name) => `api-${name}`
const relative = (from, to) => path.relative(path.dirname(from), to).split(path.sep).join('/')
const fence = (code) => {
  const length = Math.max(3, ...[...code.matchAll(/`+/g)].map((m) => m[0].length + 1))
  const marker = '`'.repeat(length)
  return `${marker}odin\n${code}\n${marker}\n`
}

export function sources() {
  const files = []
  function walk(directory) {
    for (const entry of readdirSync(path.join(repo, directory), { withFileTypes: true })) {
      if (['tests', 'internal', 'native', 'docs'].includes(entry.name) || entry.name.startsWith('.')) continue
      const file = `${directory}/${entry.name}`
      if (entry.isDirectory()) walk(file)
      else if (file.endsWith('.odin') && !file.endsWith('.gen.odin') && !file.endsWith('_test.odin')) files.push(file)
    }
  }
  Object.keys(roots).forEach(walk)
  return files.sort(compare)
}

function odin(args) {
  const compiler = process.env.ODIN || 'odin'
  if (spawnSync(compiler, ['version'], { encoding: 'utf8' }).status === 0) {
    execFileSync(compiler, args, { cwd: repo, stdio: 'inherit' })
    return
  }
  if (spawnSync('nix', ['--version'], { encoding: 'utf8' }).status === 0) {
    execFileSync('nix', ['develop', `${repo}#docs`, '--command', 'odin', ...args], { cwd: repo, stdio: 'inherit' })
    return
  }
  throw new Error('API generation needs Odin on PATH (or ODIN), or Nix. Use: nix develop .#docs')
}

export function extractor() {
  mkdirSync(cache, { recursive: true })
  const binary = path.join(cache, process.platform === 'win32' ? 'extract.exe' : 'extract')
  const stamp = path.join(cache, 'extract.sha256')
  const digest = hash(readFileSync(path.join(repo, 'tools/api-docs/main.odin')) + readFileSync(path.join(repo, 'flake.lock')) + process.platform + process.arch)
  if (!existsSync(binary) || !existsSync(stamp) || readFileSync(stamp, 'utf8') !== digest) {
    odin(['build', path.join(repo, 'tools/api-docs'), `-out:${binary}`])
    writeFileSync(stamp, digest)
  }
  return binary
}

export function extract(files, destination, { stdio = 'inherit' } = {}) {
  const input = path.join(cache, 'files.json')
  mkdirSync(cache, { recursive: true })
  writeFileSync(input, JSON.stringify(files))
  execFileSync(extractor(), [repo, input, destination], { cwd: repo, stdio })
  return JSON.parse(readFileSync(destination, 'utf8'))
}

export function catalog(files) {
  const packages = new Map()
  for (const file of files) {
    if (file.package_name === 'main') continue
    const name = path.posix.dirname(file.source)
    if (!packages.has(name)) {
      packages.set(name, { name, layer: roots[name.split('/')[0]], symbols: [], all: new Map() })
    }
    const pkg = packages.get(name)
    for (const symbol of file.symbols ?? []) {
      symbol.imports = file.imports
      symbol.attributes ??= []
      symbol.overloads ??= []
      symbol.members ??= []
      if (!pkg.all.has(symbol.name)) pkg.all.set(symbol.name, [])
      pkg.all.get(symbol.name).push(symbol)
      if (!symbol.private) pkg.symbols.push(symbol)
    }
  }
  return [...packages.values()].filter((pkg) => pkg.symbols.length).sort((a, b) => compare(a.name, b.name))
}

function resolveReference(pkg, symbol, qualified, packages) {
  const [prefix, member] = qualified.split('.')
  if (!member) return pkg.all.get(prefix)?.find((entry) => !entry.private) ? { pkg, name: prefix } : null
  const imported = symbol.imports[prefix]
  if (!imported) return null
  let name
  if (imported.startsWith('godot:')) name = imported.slice(6)
  else if (!imported.includes(':')) name = path.posix.normalize(path.posix.join(pkg.name, imported))
  const target = packages.find((entry) => entry.name === name)
  return target?.all.get(member)?.find((entry) => !entry.private) ? { pkg: target, name: member } : null
}

function related(pkg, symbol, packages, filename) {
  // This is a navigation aid over known public declarations, not type inference.
  const code = symbol.signature.replace(/\/\*[\s\S]*?\*\/|\/\/[^\n]*|"(?:\\.|[^"\\])*"|`[^`]*`/g, '')
  const found = new Map()
  for (const match of code.matchAll(/\b[A-Za-z_][A-Za-z_0-9]*(?:\.[A-Za-z_][A-Za-z_0-9]*)?\b/g)) {
    const target = resolveReference(pkg, symbol, match[0], packages)
    if (!target || (target.pkg === pkg && target.name === symbol.name)) continue
    const route = path.join(output, target.pkg.name + '.md')
    const key = `${target.pkg.name}.${target.name}`
    found.set(key, `[\`${match[0]}\`](${relative(filename, route)}#${anchor(target.name)})`)
  }
  return [...found.values()]
}

const markdown = new MarkdownIt({ html: false })
function comment(source, file) {
  if (!source) return ''
  // Comments are Markdown data. v-pre keeps code-like braces out of Vue templates.
  const original = markdown.renderer.rules.link_open
  markdown.renderer.rules.link_open = (tokens, idx, options, env, self) => {
    const href = tokens[idx].attrGet('href')
    if (href && !/^(?:[a-z][a-z0-9+.-]*:|#|\/\/)/i.test(href)) {
      const resolved = path.posix.normalize(path.posix.join(path.posix.dirname(file), href))
      tokens[idx].attrSet('href', sourceBase + resolved)
    }
    return original ? original(tokens, idx, options, env, self) : self.renderToken(tokens, idx, options)
  }
  // Keep this one HTML block: Markdown must not reparse blank lines inside a
  // rendered <pre>. Character references preserve its displayed line breaks.
  const html = markdown.render(source.replace(/^>(?=\S)/gm, '\\>')).replaceAll('\n', '&#10;')
  markdown.renderer.rules.link_open = original
  return `<div v-pre class="api-comment">\n${html}</div>\n`
}

function publicGroups(pkg) {
  const groups = new Map()
  for (const symbol of pkg.symbols) {
    if (!groups.has(symbol.name)) groups.set(symbol.name, [])
    groups.get(symbol.name).push(symbol)
  }
  return [...groups].sort(([a], [b]) => compare(a, b))
}

function groupKind(symbols) {
  if (symbols.some((s) => types.has(s.kind))) return 'Types'
  if (symbols.some((s) => ['procedure', 'overload'].includes(s.kind))) return 'Functions'
  if (symbols.some((s) => s.kind === 'alias')) return 'Aliases'
  return 'Constants and variables'
}

function packagePage(pkg, packages) {
  const filename = path.join(output, pkg.name + '.md')
  const [guide, label] = guides[pkg.name.split('/')[0]]
  const groups = publicGroups(pkg)
  let content = `---\noutline: [2, 2]\neditLink: false\n---\n\n# Package godot:${pkg.name}\n\n`
  if (descriptions[pkg.name]) content += descriptions[pkg.name] + '\n\n'
  content += fence(`import ${pkg.name.split('/').at(-1).replaceAll('-', '_')} "godot:${pkg.name}"`) + '\n'
  content += `[${label}](${relative(filename, path.join(docs, guide))}) · [All API packages](${relative(filename, path.join(docs, 'api/index.md'))}) · [Source](https://github.com/wlitwin/odin_godot/tree/main/${pkg.name})\n\n`
  if (pkg.name === 'godot') content += 'This page covers the authored helper layer. Generated engine class bindings are described in [Godot’s class reference](https://docs.godotengine.org/en/stable/classes/index.html).\n\n'
  content += '## Declaration index\n\n| Name | Kind |\n| --- | --- |\n'
  for (const [name, symbols] of groups) content += `| [\`${name}\`](#${anchor(name)}) | ${[...new Set(symbols.map((s) => s.kind))].join(', ')} |\n`
  for (const category of ['Types', 'Functions', 'Aliases', 'Constants and variables']) {
    const selected = groups.filter(([, symbols]) => groupKind(symbols) === category)
    if (!selected.length) continue
    content += `\n## ${category}\n`
    for (const [name, symbols] of selected) {
      content += `\n<a id="${anchor(name)}"></a>\n\n### ${name}\n\n`
      for (const symbol of symbols) {
        if (symbols.length > 1) content += `**${symbol.source.split('/').at(-1)}**\n\n`
        content += `[View source](${sourceBase}${symbol.source}#L${symbol.line})\n\n`
        if (symbol.condition) content += `<p class="api-condition">Condition: <code>${escape(symbol.condition)}</code></p>\n\n`
        if (symbol.attributes.length) content += fence(symbol.attributes.map((a) => a.startsWith('@') ? a : '@' + a).join('\n')) + '\n'
        content += comment(symbol.docs, symbol.source) + '\n'
        const abridged = ['constant', 'variable'].includes(symbol.kind) && symbol.signature.length > 5000
        const signature = abridged ? symbol.signature.slice(0, 5000) + '\n// Initializer continues in source.' : symbol.signature
        content += fence(signature) + '\n'
        if (abridged) content += 'The large initializer is abridged above; use the source link for its full value.\n\n'
        if (symbol.kind === 'overload') {
          for (const target of symbol.overloads) {
            for (const overload of pkg.all.get(target) ?? []) {
              if (overload.kind !== 'procedure') continue
              const signature = overload.signature.replace(new RegExp('^' + target + '\\b'), name)
              content += fence(signature) + '\n'
            }
          }
        }
        const documented = symbol.members.filter((member) => member.docs)
        if (documented.length) {
          content += '<div class="api-members">\n\n**Member notes**\n\n'
          for (const member of documented) content += `**\`${member.name}\`**\n\n${comment(member.docs, symbol.source)}\n`
          content += '</div>\n\n'
        }
        const links = related(pkg, symbol, packages, filename)
        if (links.length) content += `Related declarations: ${links.join(', ')}.\n\n`
      }
    }
  }
  return content
}

export function generate({ force = false } = {}) {
  mkdirSync(cache, { recursive: true })
  const files = sources()
  const inputs = [...files, 'tools/api-docs/main.odin', 'flake.lock', 'docs/package-lock.json', 'docs/.vitepress/api/generate.mjs', 'docs/.vitepress/api/catalog.mjs']
  const fingerprint = hash(inputs.map((file) => file + ':' + hash(readFileSync(path.join(repo, file)))).join('\n') + schema)
  const stamp = path.join(cache, 'stamp.json')
  const metadataFile = path.join(cache, 'catalog.json')
  if (!force && existsSync(stamp) && existsSync(metadataFile) && existsSync(path.join(cache, 'search.json'))) {
    const previous = JSON.parse(readFileSync(stamp, 'utf8'))
    if (previous.fingerprint === fingerprint && previous.pages.every((page) => existsSync(path.join(output, page)))) {
      return JSON.parse(readFileSync(metadataFile, 'utf8'))
    }
  }
  const exported = extract(files, path.join(cache, 'declarations.json'))
  const packages = catalog(exported)
  const staging = path.join(cache, 'pages')
  rmSync(staging, { recursive: true, force: true })
  mkdirSync(staging)
  const metadata = []
  const search = []
  for (const pkg of packages) {
    const filename = path.join(staging, pkg.name + '.md')
    mkdirSync(path.dirname(filename), { recursive: true })
    writeFileSync(filename, packagePage(pkg, packages))
    const groups = publicGroups(pkg)
    metadata.push({ name: pkg.name, layer: pkg.layer, count: groups.length, description: descriptions[pkg.name] ?? '', path: `api/generated/${pkg.name}.md` })
    for (const [name, symbols] of groups) {
      const summary = (symbols.find((s) => s.docs)?.docs ?? '').split('\n')[0].slice(0, 180)
      search.push({ name, package: pkg.name, kind: groupKind(symbols), summary, url: `/api/generated/${pkg.name}.html#${anchor(name)}` })
    }
  }
  let index = '# API packages\n\n'
  for (const layer of layers) {
    index += `## ${layer}\n\n| Package | Declarations | Topics |\n| --- | --- | --- |\n`
    for (const pkg of metadata.filter((p) => p.layer === layer)) {
      const description = pkg.description || `Public declarations in \`${pkg.name}\`.`
      index += `| [\`godot:${pkg.name}\`](${pkg.name}.md) | ${pkg.count} | ${description} |\n`
    }
    index += '\n'
  }
  writeFileSync(path.join(staging, 'index.md'), index)
  // Publish only after extraction and rendering succeed. These paths contain
  // generated files exclusively; the authored API introduction is their sibling.
  rmSync(output, { recursive: true, force: true })
  function publish(directory, relativePath = '') {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      const name = path.join(relativePath, entry.name)
      if (entry.isDirectory()) publish(path.join(directory, entry.name), name)
      else {
        const destination = path.join(output, name)
        mkdirSync(path.dirname(destination), { recursive: true })
        writeFileSync(destination, readFileSync(path.join(staging, name)))
      }
    }
  }
  publish(staging)
  writeFileSync(metadataFile, JSON.stringify(metadata, null, 2))
  writeFileSync(path.join(cache, 'search.json'), JSON.stringify(search))
  writeFileSync(stamp, JSON.stringify({ schema, fingerprint, pages: [...metadata.map((p) => p.name + '.md'), 'index.md'] }))
  console.log(`API reference: ${metadata.length} packages, ${search.length} public declarations from ${files.length} source files`)
  return metadata
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) generate({ force: process.argv.includes('--force') })
