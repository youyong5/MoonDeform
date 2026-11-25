"""Bind release evidence to the exact non-ignored source bytes."""
import hashlib
import subprocess
import re
import os

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


def current_commit(root):
    return subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()


def ci_context():
    repository = os.environ.get('GITHUB_REPOSITORY')
    run = os.environ.get('GITHUB_RUN_ID')
    if repository and run:
        return {'run_url': 'https://github.com/' + repository + '/actions/runs/' + run,
                'attempt': os.environ.get('GITHUB_RUN_ATTEMPT', '1')}
    return None


def validate_release_inputs(root, core, package, browser=None, require_browser=False):
    """Reject evidence from another source, commit, demo or registry archive."""
    commit = current_commit(root)
    source = source_digest(root)
    demo = demo_hashes(root)
    metadata = module_metadata(root)
    if core.get('schema_version') != 1 or core.get('status') != 'passed' or not core.get('passed'):
        raise ValueError('Run the current check_release.py before packaging')
    if core.get('commit') != commit or core.get('source_sha256') != source:
        raise ValueError('Core evidence belongs to another commit or source')
    if core.get('demo_sha256') != demo:
        raise ValueError('Demo changed since core validation')
    if package.get('schema_version') != 1 or package.get('kind') != 'registry-package':
        raise ValueError('Run check_package.py before packaging')
    if package.get('source_sha256') != source or package.get('module') != metadata['name'] or package.get('version') != metadata['version']:
        raise ValueError('Registry package evidence belongs to another source or version')
    if package.get('clean_consumer_targets') != ['native', 'js'] or package.get('clean_demo_bridge') != 'passed':
        raise ValueError('Clean registry-archive consumption was not verified')
    archive = (root / package['archive']).resolve()
    if not archive.is_relative_to((root / 'artifacts').resolve()) or not archive.is_file():
        raise ValueError('Registry archive is missing from artifacts/')
    if package.get('sha256') != file_sha256(archive):
        raise ValueError('Registry archive changed since its audit')
    if browser is None:
        if require_browser:
            raise ValueError('Matching real-browser evidence is required')
    elif browser.get('schema_version') != 1 or browser.get('status') != 'passed' or browser.get('commit') != commit or browser.get('source_sha256') != source or browser.get('demo_sha256') != demo or browser.get('scenarios') != ['desktop-static', 'mobile-standalone'] or not browser.get('browser'):
        raise ValueError('Browser evidence does not match this commit, source and demo')
    return {'commit': commit, 'source_sha256': source, 'demo_sha256': demo, 'metadata': metadata}


def source_digest(root):
    files = subprocess.check_output(
        ['git', 'ls-files', '-c', '-o', '--exclude-standard', '-z'], cwd=root)
    digest = hashlib.sha256()
    for name in sorted(set(files.split(b'\0')) - {b''}):
        path = root / name.decode('utf-8')
        digest.update(name + b'\0')
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()
