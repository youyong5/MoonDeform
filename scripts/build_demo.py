#!/usr/bin/env python3
"""Build a dependency-free static demo; set MOON to select a toolchain."""
from pathlib import Path
import os
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
subprocess.run([os.environ.get('MOON', 'moon'), 'build', 'examples/browser', '--target', 'js', '--release', '--deny-warn'], cwd=root, check=True)
output = root / 'dist'
output.mkdir(exist_ok=True)
shutil.copy2(root / 'examples/browser/index.html', output / 'index.html')
shutil.copy2(root / '_build/js/release/build/examples/browser/browser.js', output / 'solver.js')
print('Static demo: dist/index.html (serve dist/ with python3 -m http.server 8765)')

# A single-file distribution for opening directly from disk.
html = (output / 'index.html').read_text(encoding='utf-8')
solver = (output / 'solver.js').read_text(encoding='utf-8').replace('</script', r'<\/script')
(output / 'MoonDeform-demo.html').write_text(html.replace('<script src="solver.js"></script>', '<script>' + solver + '</script>'), encoding='utf-8')
print('Standalone demo: dist/MoonDeform-demo.html')
