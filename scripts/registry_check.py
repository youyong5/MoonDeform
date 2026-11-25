#!/usr/bin/env python3
"""Install the immutable 0.1.0 release from Mooncakes, without a workspace."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from datetime import datetime, timezone
from release_utils import ci_context, current_commit, source_digest

root = Path(__file__).resolve().parents[1]
moon = os.environ.get('MOON', 'moon')
artifacts = root / 'artifacts'
artifacts.mkdir(exist_ok=True)
evidence = artifacts / 'registry-consumer.json'
evidence.unlink(missing_ok=True)
release = json.loads((root / 'tests/registry/0.1.0.json').read_text(encoding='utf-8'))
module = release['module']
version = release['version']


def run(arguments, directory):
    print('+ moon ' + ' '.join(arguments), flush=True)
    result = subprocess.run([moon, *arguments], cwd=directory,
                            text=True, capture_output=True)
    if result.returncode:
        print(result.stdout + result.stderr, flush=True)
        result.check_returncode()
    return result.stdout


with tempfile.TemporaryDirectory(prefix='moondeform-registry-') as directory:
    consumer = Path(directory) / 'consumer'
    shutil.copytree(root / 'tests/consumer', consumer,
                    ignore=shutil.ignore_patterns('_build', '.mooncakes', 'moon.work', 'moon.work.sum'))
    # Start with no dependency, lockfile or local override. moon add must install it.
    (consumer / 'moon.mod').write_text(
        'name = "example/moondeform-consumer"\nversion = "0.1.0"\n', encoding='utf-8')
    print(run(['add', module + '@' + version], consumer), flush=True)
    tree = json.loads(run(['tree', '--json'], consumer))
    if tree.get('status') != 'success' or any(m.get('workspace_member') for m in tree['modules']):
        raise SystemExit('Expected an independent project with no workspace members')
    dependencies = [m for m in tree['modules'] if m['name'] == module]
    if len(dependencies) != 1 or dependencies[0]['version'] != version or dependencies[0]['source'] != {'kind': 'registry'}:
        raise SystemExit('Dependency did not resolve to the requested registry release')
    results = {}
    for target in ('native', 'js'):
        for action in ('check', 'build'):
            print(run([action, '--target', target, '--deny-warn'], consumer), flush=True)
        results[target] = run(['run', '.', '--target', target], consumer)
        print(results[target], flush=True)
    downloaded = consumer / '.mooncakes' / module
    hashes = {}
    for name, expected in release['lf_sha256'].items():
        path = downloaded / name
        if path.is_symlink() or not path.is_file():
            raise SystemExit('Missing regular registry source file: ' + name)
        # The release was published from Windows; compare source with LF line endings.
        hashes[name] = hashlib.sha256(path.read_bytes().replace(b'\r\n', b'\n')).hexdigest()
        if hashes[name] != expected:
            raise SystemExit('Published source differs from the verified release: ' + name)
    record = {'schema_version': 1, 'status': 'passed', 'module': module, 'version': version,
              'verified_at': datetime.now(timezone.utc).isoformat(),
              'published_source_commit': release['source_commit'],
              'verification_commit': current_commit(root), 'source_sha256': source_digest(root),
              'dependency': dependencies[0], 'workspace': False,
              'lf_sha256': hashes, 'consumer_outputs': results,
              'toolchain': run(['version', '--all'], consumer), 'ci': ci_context()}
    evidence.write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
print('Registry consumer passed: ' + module + '@' + version, flush=True)
