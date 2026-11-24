#!/usr/bin/env python3
"""Export committed sources, Git history and the freshly built static demo.

Run check_release.py first. No uploading, tagging or remote writes are performed.
"""
from pathlib import Path
import hashlib
import io
import json
import subprocess
import zipfile
from release_utils import source_digest

root = Path(__file__).resolve().parents[1]
status = subprocess.check_output(['git', 'status', '--porcelain'], cwd=root, text=True)
if status.strip():
    raise SystemExit('Commit source changes before packaging; working tree must be clean')
commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
demo = root / 'dist/MoonDeform-demo.html'
if not demo.is_file() or not (root / 'artifacts/local-gates.json').is_file():
    raise SystemExit('Run scripts/check_release.py before packaging')
evidence = json.loads((root / 'artifacts/local-gates.json').read_text(encoding='utf-8'))
if evidence.get('source_sha256') != source_digest(root):
    raise SystemExit('Source changed since validation; rerun scripts/check_release.py')
for name in ['index.html', 'solver.js', 'MoonDeform-demo.html']:
    if evidence.get('demo_sha256', {}).get(name) != hashlib.sha256((root / 'dist' / name).read_bytes()).hexdigest():
        raise SystemExit('Demo changed since validation; rerun scripts/check_release.py')
archive = subprocess.check_output(['git', 'archive', '--format=zip', 'HEAD'], cwd=root)
output = root / 'artifacts/MoonDeform-0.1.0-github-ready.zip'
bundle = root / 'artifacts/history.bundle'
subprocess.run(['git', 'bundle', 'create', str(bundle), '--all'], cwd=root, check=True)
with zipfile.ZipFile(io.BytesIO(archive)) as source, zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as target:
    for name in source.namelist():
        if not name.endswith('/'):
            target.writestr('MoonDeform/' + name, source.read(name))
    for name in ['index.html', 'solver.js', 'MoonDeform-demo.html']:
        target.write(root / 'dist' / name, 'MoonDeform/dist/' + name)
    target.write(bundle, 'MoonDeform/history.bundle')
    target.writestr('MoonDeform/RELEASE.json', json.dumps({
        'version': '0.1.0', 'commit': commit,
        'source_sha256': evidence['source_sha256'],
        'source': 'git archive HEAD', 'browser_ui': 'pending remote CI',
        'github_pushed': False, 'mooncakes_published': False,
    }, indent=2))
with zipfile.ZipFile(output) as check:
    if check.testzip():
        raise SystemExit('Archive integrity check failed')
print(json.dumps({'file': str(output), 'commit': commit, 'bytes': output.stat().st_size,
                  'sha256': hashlib.sha256(output.read_bytes()).hexdigest()}, indent=2))
