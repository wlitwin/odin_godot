"""Authored inputs and typed catalog provenance for the weapon fixture."""
from pathlib import Path
import hashlib
import importlib.util
import json

CATALOG_FILES = ('shared/content/stock.rpldef', 'shared/content/stock.manifest.json')


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def snapshot(project):
    return {str(p.relative_to(project)): digest(p) for p in sorted(project.rglob('*'))
            if p.is_file() and '.godot' not in p.relative_to(project).parts
            and not p.name.endswith('.gen.odin')
            and (p.suffix in ('.odin', '.gd', '.py', '.tscn', '.tres', '.png', '.wav', '.mp3', '.godot', '.gdextension', '.rpldef')
                 or p.name == 'stock.manifest.json')}


def verify_catalog(project):
    spec = importlib.util.spec_from_file_location('fixture_stock', project / 'tools/stock.py')
    stock = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(stock)
    receipt = json.loads((project / CATALOG_FILES[1]).read_text())
    assert stock.sources(project) == receipt['sources']
    assert stock.describe((project / CATALOG_FILES[0]).read_bytes(), receipt['sources']) == receipt
    return receipt
