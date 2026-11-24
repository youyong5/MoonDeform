#!/usr/bin/env python3
"""Run local release gates and stop at the first failure; no publishing."""
from pathlib import Path
import json
import os
import subprocess
import sys
import hashlib
from release_utils import source_digest

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
    ['git', 'diff', '--check'],
]
passed = []
for command in commands:
    print('+', ' '.join(command), flush=True)
    subprocess.run(command, cwd=root, check=True)
    passed.append(command)
artifacts = root / 'artifacts'
artifacts.mkdir(exist_ok=True)
(artifacts / 'local-gates.json').write_text(
    json.dumps({'source_sha256': source_digest(root),
                'demo_sha256': {name: hashlib.sha256((root / 'dist' / name).read_bytes()).hexdigest()
                                for name in ['index.html', 'solver.js', 'MoonDeform-demo.html']},
                'passed': passed, 'browser_ui': 'not run by this script',
                'publishing': 'not performed'}, indent=2), encoding='utf-8')
print('All local release gates passed. Browser UI checks remain a separate gate.')
