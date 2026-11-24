#!/usr/bin/env python3
"""Build a second module against the public API, in a temporary workspace."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
moon = os.environ.get('MOON', 'moon')
with tempfile.TemporaryDirectory(prefix='moondeform-consumer-') as directory:
    work = Path(directory)
    shutil.copytree(root / 'tests/consumer', work / 'consumer', ignore=shutil.ignore_patterns('_build', 'moon.work', 'moon.work.sum', '.mooncakes'))
    subprocess.run([moon, 'work', 'init', str(root), str(work / 'consumer')], cwd=work, check=True)
    subprocess.run([moon, '-C', str(work / 'consumer'), 'run', '.', '--target', 'native'], cwd=work, check=True)
    subprocess.run([moon, '-C', str(work / 'consumer'), 'run', '.', '--target', 'js'], cwd=work, check=True)
