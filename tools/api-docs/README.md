# API reference generator

The website builds a declaration reference with the official `core:odin/parser`
AST. It reads public SDK packages without compiling, linking, or initializing
Godot or a physics backend. Source spans preserve signatures and definitions;
privacy attributes, file tags, branches, fields, and overload groups come from
the parsed syntax tree.

From the repository root:

```sh
nix develop .#docs
cd docs
npm ci
npm run api
npm run test:api
npm run check
npm run build
```

Normal VitePress commands regenerate stale API data automatically. Use
`npm run api -- --force` to rebuild all outputs. The renderer, package catalog,
and source discovery policy are in `docs/.vitepress/api/`. Generated Markdown
and cached JSON are ignored by Git.

Coverage includes authored public packages and the Godot helper layer. Generated
engine classes use Godot's own class reference. Tests and internal packages are
excluded. All source variants are retained with their conditions; parsing alone
does not establish target-specific type correctness or runtime support. Aliases
and generic type instantiations retain their source expressions without inferred
types.

The fixtures exercise visibility, generic/default arguments, overloads, comments,
conditions, invalid syntax, and stable source anchors. The pinned `odin doc`
binary writer fails on some of the framework imports, so this tool uses the
same toolchain's parser instead of depending on that writer.
