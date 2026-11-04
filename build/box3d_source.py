"""Exact-pin engine preparation shared by native and WebAssembly builders.

The source/tree/patch checks are the original Native driver checks, factored
without changing their admitted files or provenance rules.
"""
import fcntl
import hashlib
import json
import pathlib
import shutil
import subprocess
import tarfile
import tempfile


def prepare_source(repo, cache, manifest):
    source_lock=(cache/'.source.lock').open('a')
    fcntl.flock(source_lock,fcntl.LOCK_EX)
    def run(*args,**kw): return subprocess.run(args,check=True,**kw)
    def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
    dep=manifest['dependencies']['box3d'];archive=cache/'box3d.tar'
    if not archive.exists():
        mirror=cache/'box3d-git'
        if not mirror.exists(): run('git','init',str(mirror))
        run('git','-C',str(mirror),'fetch','--depth=1',dep['url'],dep['commit'])
        tree=subprocess.check_output(['git','-C',str(mirror),'rev-parse','FETCH_HEAD^{tree}'],text=True).strip()
        if tree!=dep['tree']: raise SystemExit('source tree mismatch')
        with archive.open('wb') as f: run('git','-C',str(mirror),'archive','--format=tar',dep['commit'],stdout=f)
    if digest(archive)!=dep['git_archive_sha256']: raise SystemExit('source archive SHA-256 mismatch')
    source=cache/('box3d-'+dep['commit'])
    if source.is_symlink(): raise SystemExit('cached source root is a symlink')
    with tarfile.open(archive) as tar:
        if not source.exists():
            temp=pathlib.Path(tempfile.mkdtemp(prefix='extract-',dir=cache))
            for entry in tar:
                # Selected source archive has only plain files/directories.
                if entry.name.startswith('/') or '..' in pathlib.PurePosixPath(entry.name).parts or not (entry.isfile() or entry.isdir()):
                    raise SystemExit('unexpected archive member')
                tar.extract(entry,temp)
            temp.rename(source)
        # Verify every byte and inventory, including absence of unexpected C files
        # and symlinks. This also verifies a derived tree against explicit outputs.
        def verify_tree(root,overrides):
            if root.is_symlink(): raise SystemExit('cached source root is a symlink')
            expected={entry.name.rstrip('/') for entry in tar.getmembers()}
            actual=set()
            for p in root.rglob('*'):
                if p.is_symlink() or not (p.is_file() or p.is_dir()): raise SystemExit('unexpected cached source type: '+str(p))
                actual.add(str(p.relative_to(root)))
            if actual != expected: raise SystemExit('cached source inventory mismatch')
            for entry in tar.getmembers():
                if entry.isfile():
                    expected_sha=overrides.get(entry.name,hashlib.sha256(tar.extractfile(entry).read()).hexdigest())
                    if expected_sha!=digest(root/entry.name): raise SystemExit('cached source changed: '+entry.name)
        verify_tree(source,{})
        patches=manifest.get('engine_patches',[])
        if patches:
            patch_key=hashlib.sha256(json.dumps(patches,sort_keys=True).encode()).hexdigest()[:16]
            derived=cache/('box3d-'+dep['commit']+'-ogb3-'+patch_key)
            outputs={}
            for patch in patches:
                if digest(repo/patch['path'])!=patch['sha256']: raise SystemExit('patch SHA-256 mismatch')
                for name,sha in patch['base_files'].items():
                    if digest(source/name)!=sha: raise SystemExit('patch base SHA-256 mismatch: '+name)
                outputs.update(patch['output_files'])
            if not derived.exists():
                temp=pathlib.Path(tempfile.mkdtemp(prefix='patch-',dir=cache))
                shutil.copytree(source,temp,dirs_exist_ok=True)
                for patch in patches:
                    run('git','-C',str(temp),'apply','--check',str(repo/patch['path']))
                    run('git','-C',str(temp),'apply',str(repo/patch['path']))
                verify_tree(temp,outputs)
                temp.rename(derived)
            verify_tree(derived,outputs)
            source=derived
    # A local compatibility patch must prove both the compiled output and the exact
    # original upstream preimage. Old manifests with no shim patches stay byte-exact.
    shim_files=manifest['dependencies']['rollback-in-a-box']['files']
    shim_patches=manifest.get('shim_patches',[])
    if shim_patches:
        with tempfile.TemporaryDirectory(prefix='shim-proof-',dir=cache) as td:
            proof=pathlib.Path(td)
            for name in shim_files:
                shutil.copyfile(repo/'box3d/native'/pathlib.Path(name).name,proof/pathlib.Path(name).name)
            for patch in reversed(shim_patches):
                if digest(repo/patch['path'])!=patch['sha256']: raise SystemExit('shim patch SHA-256 mismatch')
                if not set(patch['base_files']).issubset(shim_files) or set(patch['base_files'])!=set(patch['output_files']):
                    raise SystemExit('shim patch file declaration mismatch')
                for name,expected in patch['output_files'].items():
                    if digest(proof/pathlib.Path(name).name)!=expected: raise SystemExit('shim patch output mismatch: '+name)
                run('git','-C',str(proof),'apply','--reverse','--check',str(repo/patch['path']))
                run('git','-C',str(proof),'apply','--reverse',str(repo/patch['path']))
                for name,expected in patch['base_files'].items():
                    if digest(proof/pathlib.Path(name).name)!=expected: raise SystemExit('shim patch preimage mismatch: '+name)
            if {p.name for p in proof.iterdir()}!={pathlib.Path(n).name for n in shim_files}: raise SystemExit('unexpected shim proof file')
            for name,expected in shim_files.items():
                if digest(proof/pathlib.Path(name).name)!=expected: raise SystemExit('shim original provenance mismatch: '+name)
    else:
        for name,expected in shim_files.items():
            if digest(repo/'box3d/native'/pathlib.Path(name).name)!=expected: raise SystemExit('shim provenance mismatch: '+name)
    fcntl.flock(source_lock,fcntl.LOCK_UN)
    source_lock.close()
    return source
