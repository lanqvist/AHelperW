"""Copy installed dependency notices and metadata into the release, never user data."""
from importlib import metadata
from pathlib import Path
import json
import shutil
import sys

root = Path(__file__).resolve().parents[1]
out = root/'build'/'licenses'
out.mkdir(parents=True, exist_ok=True)
manifest = []
for dist in sorted(metadata.distributions(), key=lambda d: d.metadata['Name'].lower()):
    name = dist.metadata['Name']
    target = out/name
    target.mkdir(exist_ok=True)
    for entry in dist.files or []:
        # Include dist-info metadata and all vendor license / notice files.
        lower = str(entry).lower()
        if '..' in entry.parts:
            continue
        if any(word in lower for word in ('license', 'licence', 'copying', 'notice', 'copyright')) or lower.endswith('.dist-info/metadata'):
            source = Path(dist.locate_file(entry))
            if source.is_file():
                dest = target/entry
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, dest)
    manifest.append({'name': name, 'version': dist.version})
python_license = Path(sys.base_prefix)/'LICENSE.txt'
if not python_license.is_file():
    raise SystemExit('Python LICENSE.txt missing; supply it before packaging')
shutil.copyfile(python_license, out/'Python-LICENSE.txt')
shutil.copyfile(root/'THIRD_PARTY_NOTICES.md', out/'THIRD_PARTY_NOTICES.md')
(out/'dependencies.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(f'Collected notices for {len(manifest)} installed build/runtime packages')
