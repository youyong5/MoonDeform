#!/usr/bin/env python3
"""Audit the real moon package archive and consume its extracted contents.

This is an offline candidate check, not a registry publication or install.
"""
from pathlib import Path, PurePosixPath
import json
import os
import stat
import shutil
import subprocess
import sys
import tempfile
import zipfile
from release_utils import file_sha256, module_metadata, source_digest

root = Path(__file__).resolve().parents[1]
metadata = module_metadata(root)
moon = os.environ.get('MOON', 'moon')
artifacts = root / 'artifacts'
artifacts.mkdir(exist_ok=True)
evidence = artifacts / 'package-audit.json'
evidence.unlink(missing_ok=True)
subprocess.run([moon, 'package', '--frozen'], cwd=root, check=True)
archive = root / '_build/publish' / (metadata['name'].replace('/', '-') + '-' + metadata['version'] + '.zip')
tracked = set(subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0'))
required = {
    'moon.mod', 'moon.pkg', 'README.md', 'LICENSE', 'pkg.generated.mbti',
    'types.mbt', 'math.mbt', 'world.mbt', 'constraints.mbt', 'builders.mbt', 'controls.mbt',
    'docs/API.md', 'docs/PROVENANCE.md',
    'third_party/PositionBasedDynamics/LICENSE',
    'third_party/PositionBasedDynamics/PositionBasedDynamics/XPBD.cpp',
}
forbidden = {'_build', '.git', '.mooncakes', 'node_modules', 'dist', 'artifacts', '__pycache__'}
with zipfile.ZipFile(archive) as package:
    names = package.namelist()
    if len(names) != len(set(names)) or package.testzip():
        raise SystemExit('Duplicate or corrupt registry archive entries')
    if not required.issubset(names):
        raise SystemExit('Required registry files missing: ' + ', '.join(sorted(required - set(names))))
    for item in package.infolist():
        path = PurePosixPath(item.filename)
        if path.is_absolute() or '..' in path.parts or '\\' in item.filename or item.is_dir():
            raise SystemExit('Unexpected registry archive path: ' + item.filename)
        if stat.S_ISLNK(item.external_attr >> 16):
            raise SystemExit('Registry archive must contain regular files')
        if set(path.parts) & forbidden or path.name in {'moon.work', 'moon.work.sum', 'history.bundle', 'package-lock.json'} or path.suffix in {'.log', '.pyc'}:
            raise SystemExit('Generated/workspace file in registry archive: ' + item.filename)
        if item.filename not in tracked:
            raise SystemExit('Untracked file in registry archive: ' + item.filename)
        if package.read(item) != (root / item.filename).read_bytes():
            raise SystemExit('Registry content differs from source: ' + item.filename)
    with tempfile.TemporaryDirectory(prefix='moondeform-package-') as directory:
        unpacked = Path(directory)
        package.extractall(unpacked)
        subprocess.run([sys.executable, 'scripts/consumer_check.py', '--library-root', str(unpacked)], cwd=root, check=True)
        subprocess.run([sys.executable, str(unpacked / 'scripts/build_demo.py')], cwd=unpacked, check=True)
        subprocess.run(['node', str(unpacked / 'scripts/bridge_check.cjs')], cwd=unpacked, check=True)
candidate = artifacts / archive.name
shutil.copyfile(archive, candidate)
result = {
    'schema_version': 1, 'kind': 'registry-package',
    'module': metadata['name'], 'version': metadata['version'],
    'source_sha256': source_digest(root),
    'archive': candidate.relative_to(root).as_posix(),
    'sha256': file_sha256(candidate), 'files': sorted(names),
    'clean_consumer_targets': ['native', 'js'], 'clean_demo_bridge': 'passed',
    'registry_install': 'not performed', 'publication': 'not performed',
}
evidence.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'archive': str(archive), 'files': len(names), 'sha256': result['sha256'], 'clean_archive_consumer': 'passed'}))
