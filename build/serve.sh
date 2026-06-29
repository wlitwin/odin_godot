#!/usr/bin/env bash
# Serve a Godot Web export locally with the headers the engine REQUIRES.
#
# Godot web needs SharedArrayBuffer, which the browser only grants when the page is served
# with two headers — without them the exported game refuses to boot (a blank/erroring page):
#   Cross-Origin-Opener-Policy:   same-origin
#   Cross-Origin-Embedder-Policy: require-corp
# A plain `python -m http.server` / static host does NOT set these, which is the usual cause
# of "my web export won't start". This tiny Node server sets them correctly.
#
# Usage:  bash addons/odin_godot/build/serve.sh [DIR] [PORT]
#   DIR  = folder containing your exported index.html (default: current directory)
#   PORT = default 8099
# Then open http://localhost:<PORT>/ in a browser.
#
# (Deploying to a host instead? Configure the same two headers there. On itch.io, tick the
#  "SharedArrayBuffer support" box in the HTML5 settings — it sets them for you.)
set -euo pipefail
DIR="${1:-$PWD}"
PORT="${2:-8099}"

command -v node >/dev/null 2>&1 || { echo "serve.sh: needs Node.js (node) on PATH" >&2; exit 1; }

exec node -e '
const http = require("http");
const fs = require("fs");
const path = require("path");
const dir = process.argv[1];
const port = parseInt(process.argv[2], 10);
const MIME = {
  ".html":"text/html", ".js":"text/javascript", ".wasm":"application/wasm",
  ".json":"application/json", ".png":"image/png", ".pck":"application/octet-stream",
  ".side.wasm":"application/wasm", ".worklet.js":"text/javascript",
};
http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split("?")[0]);
  if (p === "/") p = "/index.html";
  const file = path.join(dir, p);
  res.setHeader("Cross-Origin-Opener-Policy", "same-origin");
  res.setHeader("Cross-Origin-Embedder-Policy", "require-corp");
  res.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
  fs.readFile(file, (err, data) => {
    if (err) { res.statusCode = 404; res.end("not found"); return; }
    const ext = Object.keys(MIME).find(e => file.endsWith(e));
    if (ext) res.setHeader("Content-Type", MIME[ext]);
    res.end(data);
  });
}).listen(port, "127.0.0.1", () => {
  console.log(`serving ${dir} at http://127.0.0.1:${port}/  (COOP/COEP headers on)`);
});
' "$DIR" "$PORT"
