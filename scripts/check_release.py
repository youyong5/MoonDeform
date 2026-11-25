#!/usr/bin/env python3
"""Run local release gates and stop at the first failure; no publishing."""
from pathlib import Path
import json
import os
import subprocess
import sys
from release_utils import source_digest, demo_hashes, current_commit, ci_context

root = Path(__file__).resolve().parents[1]
moon = os.environ.get('MOON', 'moon')
commands = [
    [moon, 'version', '--all'],
    [sys.executable, 'scripts/check_generated.py'],
    [moon, 'check', '--target', 'all', '--deny-warn'],
    [moon, 'build', '--target', 'all', '--deny-warn'],
    [moon, 'test', '--target', 'all', '--deny-warn'],
    [sys.executable, 'scripts/upstream_reference.py'],
    [sys.executable, 'scripts/consumer_check.py'],
    [moon, 'run', 'examples/headless', '--target', 'native'],
    [moon, 'run', 'examples/custom_constraint', '--target', 'native'],
    [moon, 'run', 'examples/custom_constraint', '--target', 'js'],
    [moon, 'run', 'examples/runtime_material', '--target', 'native'],
    [moon, 'run', 'examples/runtime_material', '--target', 'js'],
    [sys.executable, 'scripts/build_demo.py'],
    ['node', 'scripts/bridge_check.cjs'],
    [sys.executable, '-m', 'unittest', 'discover', '-s', 'scripts', '-p', 'test_release.py'],
    [sys.executable, 'scripts/check_package.py'],
    ['git', 'diff', '--check'],
]
passed = []
artifacts = root / 'artifacts'
artifacts.mkdir(exist_ok=True)
(artifacts / 'local-gates.json').unlink(missing_ok=True)
for command in commands:
    print('+', ' '.join(command), flush=True)
    subprocess.run(command, cwd=root, check=True)
    passed.append(command)
(artifacts / 'local-gates.json').write_text(
    json.dumps({'schema_version': 1, 'status': 'passed', 'commit': current_commit(root),
                'source_sha256': source_digest(root), 'demo_sha256': demo_hashes(root),
                'toolchain': subprocess.check_output([moon, 'version', '--all'], cwd=root, text=True),
                'ci': ci_context(),
                'passed': passed, 'browser_ui': 'not run by this script',
                'publishing': 'not performed'}, indent=2), encoding='utf-8')
print('All local release gates passed. Browser UI checks remain a separate gate.')
