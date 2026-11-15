# Maintain the documentation

Keep user guides alongside the APIs and examples they describe. The published
site contains deliberately organized pages, rather than a recursive copy of
repository Markdown and test reports.

## Local checks

From `docs/`:

```sh
npm ci
npm run check
npm run build
npm run preview
```

API generation also needs Odin. Use the pinned, documentation-only shell from
the repository root with `nix develop .#docs`, or set `ODIN` to a compatible
compiler. Without Odin on PATH, the build enters that Nix shell automatically.
Godot, Emscripten, and a native Box3D backend are unnecessary for documentation.

The link check validates local destinations and heading anchors. The production
build checks page compilation, sidebar destinations, and VitePress links. Preview
uses the same `/odin_godot/` base path as GitHub Pages.

## Add a page

1. Choose its layer and page type using [Writing documentation](writing-docs.md).
2. Give it prerequisites, a concrete reader outcome, and a natural next page.
3. Add it to that layer's `.vitepress/sidebar/` file in reading order.
   Add one entry to the [site map](../site-map.md) with the topics it covers.
4. Check API names against source. Run any new tutorial from its stated starting
   point and check expected output or behavior.
5. Run the link check and production build. Check narrow-screen navigation,
   search, code blocks, diagrams, and theme contrast in the preview.

Keep existing root guide paths when extending their content. This preserves
links from source READMEs and installed addons. Their sidebar can still place
them under Scripting or Libraries.

## Tutorials and articles

A tutorial ends with a working result and supplies every new file or links to a
specific complete runnable example. Explain what changed, how the reader can
observe it, and what a likely failure means. Run the commands yourself before
publishing.

An explanatory article develops one question with concrete gameplay examples,
diagrams where useful, and consequences for the reader's code. Keep API lookup
tables in reference pages. Add finished articles to [Learn](../learn/index.md);
avoid empty article stubs or promised titles in navigation.

## Publishing

The Documentation workflow checks pull requests and builds pushes to `main`.
GitHub Pages receives only `docs/.vitepress/dist`. Select **GitHub Actions** as
the Pages source in repository settings. A local build does not publish a site.

## Generated API reference

The [API reference](../api/index.md) is generated from public declarations in the
SDK packages. `tools/api-docs/` uses Odin's official parser to extract source
signatures, comments, fields, overloads, privacy attributes, and conditions.
The renderer lives in `.vitepress/api/`. The pinned compiler's `odin doc`
binary writer currently fails on some framework imports, so generation uses the
parser directly and does not type-check or link a target build.

The site configuration refreshes the API before resolving its pages. Source
hashes avoid unnecessary work during prose-only edits. To regenerate explicitly
and run the extractor checks:

```sh
npm run api -- --force
npm run test:api
npm run check
```

Generated Markdown stays under `docs/api/generated/`; extraction metadata, search
data, and the tool binary stay in `.vitepress/cache/api/`. Both are ignored by Git.
Edit source comments or the generator instead of these outputs. API package
pages are indexed automatically from the catalog linked in the site map.

Generation includes source variants inside `when` branches and files with build
tags. It excludes private declarations, test files, internal packages, and the
generated Godot engine classes. The engine helper layer remains included.
The coverage boundary is documented on the API landing page.

The build also generates redirects for the previous site's main entry points
and maintained `read/docs/` guide URLs. Keep those mappings in
`.vitepress/redirects.mjs` when moving a published guide.

Do not commit the output, copied source snapshots, dependency trees, test reports,
or progress journals as web content. Retain active regression fixtures and
technical contracts with the code that uses them.
