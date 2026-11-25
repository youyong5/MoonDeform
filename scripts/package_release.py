#!/usr/bin/env python3
"""Export a committed release candidate with matching validation evidence.

No publication, tagging or remote writes. CI requires real-browser evidence.
"""
from pathlib import Path
import argparse
import hashlib
import io
import json
import subprocess
import time
import zipfile
from release_utils import DEMO_FILES, ci_context, file_sha256, validate_release_inputs

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--require-browser', action='store_true')
args = parser.parse_args()
if subprocess.check_output(['git', 'status', '--porcelain'], cwd=root, text=True).strip():
    raise SystemExit('Commit source changes before packaging; working tree must be clean')
if subprocess.check_output(['git', 'rev-parse', '--is-shallow-repository'], cwd=root, text=True).strip() == 'true':
    raise SystemExit('Complete Git history is required for the source bundle')
artifacts = root / 'artifacts'
try:
    core = json.loads((artifacts / 'local-gates.json').read_text(encoding='utf-8'))
    package = json.loads((artifacts / 'package-audit.json').read_text(encoding='utf-8'))
    browser_file = artifacts / 'browser-gates.json'
    browser = json.loads(browser_file.read_text(encoding='utf-8')) if browser_file.exists() else None
    bound = validate_release_inputs(root, core, package, browser, args.require_browser)
except (ValueError, KeyError, OSError) as error:
    raise SystemExit('Release evidence rejected: ' + str(error)) from error

metadata = bound['metadata']
commit = bound['commit']
archive = subprocess.check_output(['git', 'archive', '--format=zip', 'HEAD'], cwd=root)
bundle = artifacts / 'history.bundle'
subprocess.run(['git', 'bundle', 'create', str(bundle), 'HEAD'], cwd=root, check=True)
subprocess.run(['git', 'bundle', 'verify', str(bundle)], cwd=root, check=True, capture_output=True)
with zipfile.ZipFile(io.BytesIO(archive)) as source:
    entries = {name: source.read(name) for name in source.namelist() if not name.endswith('/')}
for name in DEMO_FILES:
    entries['dist/' + name] = (root / 'dist' / name).read_bytes()
entries['history.bundle'] = bundle.read_bytes()
registry_name = Path(package['archive']).name
entries['registry/' + registry_name] = (root / package['archive']).read_bytes()
entries['validation/core.json'] = json.dumps(core, indent=2).encode()
entries['validation/package.json'] = json.dumps(package, indent=2).encode()
if browser is not None:
    entries['validation/browser.json'] = json.dumps(browser, indent=2).encode()
entries['RELEASE.json'] = (json.dumps({
    'schema_version': 1, 'stage': 'release-candidate',
    'module': metadata['name'], 'version': metadata['version'],
    'repository': metadata['repository'], 'license': metadata['license'],
    'commit': commit, 'source_sha256': bound['source_sha256'],
    'source': 'git archive HEAD', 'history': 'HEAD and reachable ancestors only',
    'demo_sha256': bound['demo_sha256'],
    'registry_archive_sha256': package['sha256'],
    'validation': {'core': 'passed', 'registry_archive_consumer': 'passed',
                   'browser': 'passed' if browser is not None else 'not recorded for this commit'},
    'publication': {'performed_by_this_command': False},
    'ci': ci_context(), 'integrity_file': 'SHA256SUMS',
}, indent=2) + '\n').encode()
if any('\n' in name or '\r' in name for name in entries):
    raise SystemExit('Archive paths cannot contain line separators')
hashes = {name: hashlib.sha256(data).hexdigest() for name, data in entries.items()}
entries['SHA256SUMS'] = ''.join(hashes[name] + '  ' + name + '\n' for name in sorted(hashes)).encode()
output = artifacts / ('MoonDeform-' + metadata['version'] + '-' + commit[:12] + '-candidate.zip')
temporary = output.with_suffix('.zip.tmp')
timestamp = int(subprocess.check_output(['git', 'show', '-s', '--format=%ct', 'HEAD'], cwd=root, text=True))
with zipfile.ZipFile(temporary, 'w') as target:
    for name, data in sorted(entries.items()):
        info = zipfile.ZipInfo('MoonDeform/' + name, time.gmtime(max(timestamp, 315532800))[:6])
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        info.create_system = 3
        target.writestr(info, data)
with zipfile.ZipFile(temporary) as check:
    if check.testzip():
        raise SystemExit('Archive integrity check failed')
    for name, expected in hashes.items():
        if hashlib.sha256(check.read('MoonDeform/' + name)).hexdigest() != expected:
            raise SystemExit('Archive content hash mismatch: ' + name)
temporary.replace(output)
summary = {
    'file': output.relative_to(root).as_posix(), 'module': metadata['name'],
    'version': metadata['version'], 'commit': commit, 'source_sha256': bound['source_sha256'],
    'bytes': output.stat().st_size, 'sha256': file_sha256(output),
    'browser': 'passed' if browser is not None else 'not recorded for this commit',
}
(artifacts / 'release-candidate.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
output.with_suffix('.zip.sha256').write_text(summary['sha256'] + '  ' + output.name + '\n', encoding='utf-8')
print(json.dumps(summary, indent=2))
