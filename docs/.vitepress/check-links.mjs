// Validate the same page inventory, Markdown parser, and heading IDs as the site.
// Optional arguments select sections: npm run check -- kit box3d
import { existsSync, readFileSync, statSync } from 'node:fs'
import { dirname, join, relative, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createMarkdownRenderer, resolveConfig } from 'vitepress'

const docs = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const config = await resolveConfig(docs)
const pages = new Set(config.pages.map((page) => resolve(docs, page)))
const sections = process.argv.slice(2)
const selected = [...pages].filter((file) => !sections.length || sections.some((section) =>
  file.startsWith(resolve(docs, section) + sep) || file === resolve(docs, section),
))
if (!selected.length) throw new Error('No published pages match the requested sections')

const md = await createMarkdownRenderer(docs, config.markdown, config.site.base)
const parsed = new Map()
const problems = []
let checked = 0

const githubSlug = (text) => text.trim().toLowerCase()
  .replace(/[^\p{L}\p{N}\p{M} _-]/gu, '').replace(/ /g, '-')
const headingText = (text) => text.replace(/\s+\{#[^}]+\}\s*$/, '')
  .replace(/!?\[([^\]]*)\]\([^)]*\)/g, '$1').replace(/[`*]/g, '')
  .replace(/<[^>]+>/g, '').trim()

function parse(file) {
  if (parsed.has(file)) return parsed.get(file)
  const source = readFileSync(file, 'utf8')
  const tokens = md.parse(source, { path: file, relativePath: relative(docs, file) })
  const site = new Set()
  const github = new Set()
  const counts = new Map()
  const links = []
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i]
    if (token.type === 'heading_open') {
      site.add(token.attrGet('id'))
      const slug = githubSlug(headingText(tokens[i + 1].content))
      const count = counts.get(slug) ?? 0
      counts.set(slug, count + 1)
      github.add(slug + (count ? `-${count}` : ''))
    }
    function visit(token) {
      if (token.type === 'link_open' && token.attrGet('class') !== 'header-anchor') {
        links.push(token.attrGet('href'))
      }
      if (token.type === 'image') links.push(token.attrGet('src'))
      if (token.type === 'html_inline' || token.type === 'html_block') {
        for (const match of token.content.matchAll(/\b(?:id|name)=["']([^"']+)["']/g)) {
          site.add(match[1]); github.add(match[1])
        }
        for (const match of token.content.matchAll(/\b(?:href|src)=["']([^"']+)["']/g)) {
          links.push(match[1])
        }
      }
      token.children?.forEach(visit)
    }
    visit(token)
  }
  const value = { site, github, links }
  parsed.set(file, value)
  return value
}

function check(target, file, navigation = false) {
  if (!target) return
  const source = target.match(/^https:\/\/github\.com\/wlitwin\/odin_godot\/(?:blob|tree)\/main\/([^#?]+)(?:#(.*))?$/)
  if (source) {
    checked++
    const destination = resolve(docs, '..', decodeURIComponent(source[1]))
    const where = relative(docs, file)
    if (!existsSync(destination) || destination.startsWith(join(docs, 'replay/results') + sep)) {
      problems.push(`${where}: "${target}" points to missing or unpublished source`)
    } else if (source[2] && destination.endsWith('.md') && !parse(destination).github.has(decodeURIComponent(source[2]))) {
      problems.push(`${where}: "${target}" has no matching GitHub anchor`)
    }
    return
  }
  if (/^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(target)) return
  checked++
  const where = navigation ? 'navigation' : relative(docs, file)
  const fail = (message) => problems.push(`${where}: "${target}" ${message}`)
  const [pathQuery, encodedFragment] = target.split('#')
  const pathPart = decodeURIComponent(pathQuery.split('?')[0])
  const fragment = encodedFragment ? decodeURIComponent(encodedFragment) : ''
  let destination = file
  if (pathPart) {
    if (pathPart.startsWith('/') && !navigation) {
      fail('is root-relative; use a relative Markdown path'); return
    }
    destination = navigation ? resolve(docs, '.' + pathPart) : resolve(dirname(file), pathPart)
    if (navigation) {
      destination = destination.replace(/\.html$/, '')
      if (existsSync(destination + '.md')) destination += '.md'
      else destination = join(destination, 'index.md')
    } else if (existsSync(destination) && statSync(destination).isDirectory()) {
      destination = join(destination, 'index.md')
    }
    if (!destination.startsWith(docs + sep)) {
      fail('leaves docs/; link to the source file on GitHub'); return
    }
    if (!existsSync(destination)) { fail('does not exist'); return }
    if (destination.endsWith('.md') && !pages.has(destination)) {
      fail('points to an unpublished page'); return
    }
  }
  if (fragment && destination.endsWith('.md')) {
    const { site, github } = parse(destination)
    if (!site.has(fragment) || !github.has(fragment)) {
      fail(!site.has(fragment) && !github.has(fragment)
        ? 'has no matching heading or explicit anchor'
        : `resolves ${site.has(fragment) ? 'on the site' : 'on GitHub'} only; add a stable explicit anchor`)
    }
  }
}

for (const file of selected) {
  parse(file).links.forEach((target) => check(target, file))
  // Home-page action and feature links live in frontmatter, outside Markdown links.
  const frontmatter = readFileSync(file, 'utf8').match(/^---\n([\s\S]*?)\n---/)
  for (const match of frontmatter?.[1].matchAll(/^\s+link:\s*["']?([^\s"']+)/gm) ?? []) {
    check(match[1], file, true)
  }
}

function navigation(items) {
  for (const item of items ?? []) {
    if (item.link) check(item.link, resolve(docs, 'index.md'), true)
    if (item.items) navigation(item.items)
  }
}
navigation(config.site.themeConfig.nav)
Object.values(config.site.themeConfig.sidebar).forEach(navigation)

// The map is a curated index of published documentation. Keep every page listed
// exactly once, including guides that are linked from more than one sidebar.
const siteMap = resolve(docs, 'site-map.md')
const mapped = new Map()
// API package pages are indexed automatically; the human map links to that index.
for (const index of [siteMap, resolve(docs, 'api/generated/index.md')]) {
  for (const target of parse(index).links) {
    const path = target.split('#')[0]
    if (!path.endsWith('.md') || /^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(path)) continue
    const destination = resolve(dirname(index), path)
    mapped.set(destination, (mapped.get(destination) ?? 0) + 1)
  }
}
for (const page of pages) {
  if (page === siteMap) continue
  const count = mapped.get(page) ?? 0
  if (count !== 1) problems.push(`site-map.md: ${relative(docs, page)} is listed ${count} times; list every page once`)
}

if (problems.length) {
  console.error(problems.join('\n'))
  console.error(`\n${problems.length} broken link(s) in ${checked} checked`)
  process.exitCode = 1
} else {
  console.log(`${selected.length} pages; ${checked} links, assets, navigation entries, and anchors resolve`)
}
