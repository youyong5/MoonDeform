"""Bind release evidence to the exact non-ignored source bytes."""
import hashlib
import subprocess
import re

DEMO_FILES = ('index.html', 'solver.js', 'MoonDeform-demo.html')


def file_sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def demo_hashes(root):
    return {name: file_sha256(root / 'dist' / name) for name in DEMO_FILES}


def module_metadata(root):
    """Read the scalar fields used by this project's manifest; moon validates it."""
    text = (root / 'moon.mod').read_text(encoding='utf-8')
    result = {}
    for field in ('name', 'version', 'license', 'repository'):
        match = re.search(r'^' + field + r'\s*=\s*"([^"\n]+)"\s*$', text, re.M)
        if not match:
            raise ValueError('Missing scalar manifest field: ' + field)
        result[field] = match.group(1)
    if not re.fullmatch(r'[A-Za-z0-9_-]+/[A-Za-z0-9_-]+', result['name']):
        raise ValueError('Unexpected module name for archive naming')
    if not re.fullmatch(r'0\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?', result['version']):
        raise ValueError('Expected a pre-1.0 semantic version')
    return result


def source_digest(root):
    files = subprocess.check_output(
        ['git', 'ls-files', '-c', '-o', '--exclude-standard', '-z'], cwd=root)
    digest = hashlib.sha256()
    for name in sorted(set(files.split(b'\0')) - {b''}):
        path = root / name.decode('utf-8')
        digest.update(name + b'\0')
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()
