"""Borrow unchanged packages while compiling an explicitly retained schema version."""
from pathlib import Path
import shutil,sys
root,dest,reference=map(lambda s:Path(s).resolve(),sys.argv[1:]);dest.mkdir()
assert (reference/'schema.odin').is_file()
for path in root.iterdir():
 if path.name in ('.git','replay'):continue
 (dest/path.name).symlink_to(path,target_is_directory=path.is_dir())
(dest/'replay').mkdir()
for path in (root/'replay').iterdir():
 if path.name=='schema':continue
 (dest/'replay'/path.name).symlink_to(path,target_is_directory=path.is_dir())
shutil.copytree(reference,dest/'replay/schema')
