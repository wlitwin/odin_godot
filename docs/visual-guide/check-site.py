#!/usr/bin/env python3
"""Check the generated site's files, fragments, and project-site URL portability."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit
from collections import Counter
import json
import sys
import xml.etree.ElementTree as ET


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.links = []
        self.index_entries = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.add(attrs["id"])
        for key in ("href", "src"):
            if attrs.get(key):
                self.links.append(attrs[key])
        if tag == "a" and attrs.get("data-source-file"):
            self.index_entries.append((attrs["data-source-file"], attrs.get("href", "")))


def check(root):
    pages = {}
    for filename in root.rglob("*.html"):
        page = Page()
        page.feed(filename.read_text())
        pages[filename] = page
    failures = []
    for filename in root.rglob("*.svg"):
        try:
            svg = ET.parse(filename)
            text = "".join(svg.getroot().itertext())
            if "ﬂ°°" in text or "¶ß" in text:
                failures.append(f"{filename.relative_to(root)}: unresolved diagram escape token")
        except ET.ParseError as error:
            failures.append(f"{filename.relative_to(root)}: invalid SVG XML: {error}")
    links = 0
    if root / "index.html" not in pages:
        failures.append("Missing index.html")
    manifest_file = root / "reference-manifest.json"
    if manifest_file.is_file() and root / "reading.html" in pages:
        manifest = json.loads(manifest_file.read_text())
        entries = pages[root / "reading.html"].index_entries
        counts = Counter(source for source, _ in entries)
        for source in set(manifest["files"]) - set(counts):
            failures.append(f"Documentation index is missing {source}")
        for source, count in counts.items():
            if source not in manifest["pages"]:
                failures.append(f"Documentation index has an unknown source: {source}")
            if count != 1:
                failures.append(f"Documentation index lists {source} {count} times")
        for source, href in entries:
            if source in manifest["pages"] and href != manifest["pages"][source]:
                failures.append(f"Documentation index has the wrong target for {source}")
    for filename, page in pages.items():
        for href in page.links:
            url = urlsplit(href)
            if url.scheme or url.netloc:
                continue
            links += 1
            label = f"{filename.relative_to(root)}: {href}"
            if url.path.startswith("/"):
                failures.append(f"{label}: root-relative URL breaks project hosting")
                continue
            target = (filename.parent / unquote(url.path)).resolve() if url.path else filename
            if not target.is_relative_to(root):
                failures.append(f"{label}: points outside the site")
            elif not target.is_file():
                failures.append(f"{label}: missing file")
            elif url.fragment and target in pages and unquote(url.fragment) not in pages[target].ids:
                failures.append(f"{label}: missing section")
    for failure in failures:
        print(failure, file=sys.stderr)
    if failures:
        raise SystemExit(f"{len(failures)} site link checks failed")
    print(f"SITE_OK: {len(pages)} pages, {links} local links and sections; relative URLs support project hosting.")


if __name__ == "__main__":
    check(Path(__file__).resolve().parent.joinpath("dist"))
