#!/usr/bin/env python3
"""Regenerate canonical files and report exact reviewable content on drift."""
from pathlib import Path
import json
import os
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
moon = os.environ.get('MOON', 'moon')


def git_paths(*arguments):
    output = subprocess.check_output(['git', arguments[0], '-z', *arguments[1:]], cwd=root)
    return [name.decode('utf-8') for name in output.split(b'\0') if name]


sources = git_paths('ls-files', '-c', '-o', '--exclude-standard', '--', '*.mbt')
before = {name: (root / name).read_bytes() for name in sources}
subprocess.run([moon, 'fmt'], cwd=root, check=True)
formatted = [name for name in sources if (root / name).read_bytes() != before[name]]
subprocess.run([moon, 'info'], cwd=root, check=True)
changed = git_paths('diff', '--name-only', '--', '*.mbti')
missing = git_paths('ls-files', '--others', '--exclude-standard', '--', '*.mbti')
review = sorted(set(formatted + changed + missing))
if review:
    print('Canonical files need to be reviewed and committed:', flush=True)
    for name in review:
        print('GENERATED_FILE ' + json.dumps(
            {'path': name, 'content': (root / name).read_text(encoding='utf-8')},
            ensure_ascii=True), flush=True)
    sys.exit(1)
print('Generated source formatting and public interfaces match.')
