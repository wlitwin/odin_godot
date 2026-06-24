#!/usr/bin/env bash
# Serve a Godot web export over HTTP with the COOP/COEP headers the engine requires
# (SharedArrayBuffer needs Cross-Origin-Opener-Policy: same-origin +
# Cross-Origin-Embedder-Policy: require-corp). Without these the engine refuses to boot.
#
# Uses Node (reliably present in/out of the Nix shell; the macOS system python3 is a
# stub that fails inside `nix develop`).
#
# Usage: serve.sh [DIR] [PORT]   (defaults: tests/web/out, 8099)
#   then open http://localhost:<PORT>/index.html in a browser.
set -euo pipefail
DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/out}"
PORT="${2:-8099}"

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
  console.log(`serving ${dir} at http://127.0.0.1:${port}/index.html  (COOP/COEP on)`);
});
' "$DIR" "$PORT"
