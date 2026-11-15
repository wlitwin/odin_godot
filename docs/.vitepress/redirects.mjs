import { mkdir, writeFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'

// Keep the old site's entry points and maintained guide URLs useful. Redirect
// pages are generated output and are excluded from the documentation search index.
export async function legacyRedirects(config) {
  const routes = {
    'docs.html': 'scripting/index.html',
    'reading.html': 'site-map.html',
    'examples.html': 'examples/index.html',
    'guide.html': 'multiplayer/index.html',
    'read/README.html': 'index.html',
    'read/replay/README.html': 'replay/index.html',
    'read/replay/getting-started.html': 'replay/godot.html',
    'read/box3d/README.html': 'box3d/index.html',
  }
  for (const page of config.pages) {
    routes[`read/docs/${page.replace(/\.md$/, '.html')}`] = page.replace(/\.md$/, '.html')
  }
  const starters = {
    'start-here': 'learn/index', install: 'getting-started',
    'existing-project': 'distribution', 'first-script': 'scripting/first-scene',
    multiplayer: 'multiplayer/index', 'kit-game': 'kit/quickstart',
    'replay-game': 'replay/quickstart', shipping: 'exporting', examples: 'examples/index',
  }
  for (const [old, current] of Object.entries(starters)) {
    routes[`read/docs/visual-guide/content/${old}.html`] = `${current}.html`
  }
  const base = config.site.base
  for (const [old, current] of Object.entries(routes)) {
    const file = join(config.outDir, old)
    const destination = base + current
    await mkdir(dirname(file), { recursive: true })
    await writeFile(file, `<!doctype html><html lang="en"><meta charset="utf-8"><title>Documentation moved</title><link rel="icon" type="image/svg+xml" href="${base}favicon.svg"><meta http-equiv="refresh" content="0;url=${destination}"><link rel="canonical" href="${destination}"><p>This guide moved. <a href="${destination}">Continue to the documentation</a>.</p></html>\n`)
  }
}
