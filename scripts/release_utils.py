"""Bind release evidence to the exact non-ignored source bytes."""
import hashlib
import subprocess


def source_digest(root):
    files = subprocess.check_output(
        ['git', 'ls-files', '-c', '-o', '--exclude-standard', '-z'], cwd=root)
    digest = hashlib.sha256()
    for name in sorted(set(files.split(b'\0')) - {b''}):
        path = root / name.decode('utf-8')
        digest.update(name + b'\0')
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()
