#!/usr/bin/env python3
"""Run real Chromium checks and bind the result to this source and demo."""
from pathlib import Path
import json
import subprocess
from release_utils import ci_context, current_commit, demo_hashes, source_digest

root = Path(__file__).resolve().parents[1]
artifacts = root / 'artifacts'
artifacts.mkdir(exist_ok=True)
output = artifacts / 'browser-gates.json'
output.unlink(missing_ok=True)
result = subprocess.run(['node', 'scripts/browser_check.cjs'], cwd=root, text=True, capture_output=True)
print(result.stdout, end='')
if result.stderr:
    print(result.stderr, end='')
if result.returncode:
    raise SystemExit(result.returncode)
summary = json.loads(result.stdout.strip().splitlines()[-1])
if summary.get('result') != 'passed' or summary.get('scenarios') != ['desktop-static', 'mobile-standalone']:
    raise SystemExit('Browser runner did not report the expected scenarios')
output.write_text(json.dumps({
    'schema_version': 1, 'status': 'passed', 'commit': current_commit(root),
    'source_sha256': source_digest(root), 'demo_sha256': demo_hashes(root),
    'browser': summary['browser'], 'scenarios': summary['scenarios'], 'ci': ci_context(),
}, indent=2) + '\n', encoding='utf-8')
