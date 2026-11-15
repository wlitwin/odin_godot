import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vitepress'
import { withMermaid } from 'vitepress-plugin-mermaid'
import { legacyRedirects } from './redirects.mjs'
import { generate } from './api/generate.mjs'
import { layers } from './api/catalog.mjs'

import box3d from './sidebar/box3d'
import contributing from './sidebar/contributing'
import examples from './sidebar/examples'
import kit from './sidebar/kit'
import libraries from './sidebar/libraries'
import learn from './sidebar/learn'
import multiplayer from './sidebar/multiplayer'
import replay from './sidebar/replay'
import scripting from './sidebar/scripting'

// Shiki has no bundled Odin grammar. This one also highlights the `//gd:` script
// markers, which an editor grammar would colour as ordinary comments.
const odin = JSON.parse(
  readFileSync(fileURLToPath(new URL('./odin.tmLanguage.json', import.meta.url)), 'utf8'),
)

const repo = 'https://github.com/wlitwin/odin_godot'
const apiPackages = generate()
const apiSidebar = [
  { text: 'API reference', link: '/api/' },
  { text: 'All packages', link: '/api/generated/' },
  ...layers.map((layer) => ({
    text: layer,
    collapsed: layer !== 'Odin and Godot',
    items: apiPackages.filter((pkg) => pkg.layer === layer).map((pkg) => ({
      text: pkg.name, link: '/api/generated/' + pkg.name,
    })),
  })),
]

export default withMermaid(
  defineConfig({
    title: 'odin_godot',
    description: 'Write Godot games in Odin: compiled scripts, two multiplayer frameworks, and Box3D physics.',
    lang: 'en-US',
    // Published as a GitHub Pages project site: https://wlitwin.github.io/odin_godot/
    base: '/odin_godot/',
    // GitHub Pages serves .html routes without requiring server rewrites.
    cleanUrls: false,
    srcExclude: ['**/node_modules/**', 'design/**', 'visual-guide/**', 'replay/results/**'],
    buildEnd: legacyRedirects,
    head: [['link', { rel: 'icon', type: 'image/svg+xml', href: '/odin_godot/favicon.svg' }]],

    markdown: {
      languages: [odin],
      theme: { light: 'github-light', dark: 'github-dark' },
    },

    themeConfig: {
      logo: '/favicon.svg',
      outline: [2, 3],

      nav: [
        { text: 'Scripting', link: '/scripting/', activeMatch: '^/(scripting/|getting-started|authoring-guide|workflow|debugging|modules|exporting|distribution)' },
        { text: 'Multiplayer', link: '/multiplayer/concepts/', activeMatch: '^/multiplayer/' },
        { text: 'Kit', link: '/kit/', activeMatch: '^/kit/' },
        { text: 'Replay', link: '/replay/', activeMatch: '^/replay/' },
        { text: 'Box3D', link: '/box3d/', activeMatch: '^/box3d/' },
        { text: 'Libraries', link: '/libraries/', activeMatch: '^/libraries/' },
        { text: 'Learn', link: '/learn/', activeMatch: '^/(learn/|onboarding/|examples/)' },
        { text: 'Site map', link: '/site-map', activeMatch: '^/site-map' },
        {
          text: 'More',
          items: [
            { text: 'API reference', link: '/api/' },
            { text: 'Choosing Kit or Replay', link: '/multiplayer/' },
            { text: 'Example projects', link: '/examples/' },
            { text: 'Contributing', link: '/contributing/' },
            { text: 'Releases', link: `${repo}/releases` },
          ],
        },
      ],

      sidebar: {
        '/api/': apiSidebar,
        '/scripting/': scripting,
        '/kit/': kit,
        '/replay/': replay,
        '/box3d/': box3d,
        '/libraries/': libraries,
        '/examples/': examples,
        '/multiplayer/': multiplayer,
        '/contributing/': contributing,
        '/learn/': learn,
        '/onboarding/': learn,
        '/events': libraries,
        '/recipes': libraries,
        '/publishing': contributing,
        '/': scripting,
      },

      socialLinks: [{ icon: 'github', link: repo }],
      editLink: {
        pattern: `${repo}/edit/main/docs/:path`,
        text: 'Edit this page on GitHub',
      },
      search: { provider: 'local' },
      footer: {
        message: 'Released under the Apache-2.0 License.',
      },
    },
  }),
)
