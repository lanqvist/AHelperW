from pathlib import Path
from PyInstaller.utils.hooks import collect_data_files, collect_dynamic_libs

root = Path(SPECPATH).parent
data = collect_data_files('rapidocr_onnxruntime')
data += [(str(root/'reader'/name), '.') for name in ('pipeline.json', 'ocr_policy.json')]
data += [(str(root/'docs'/'arms-apl'/name), 'apl-data')
         for name in ('build-requirements.json', 'warrior-traits.json', 'source.json', 'COPYING')]
data += [(str(root/'build'/'licenses'), 'licenses')]
a = Analysis([str(root/'reader'/'reader.py')], pathex=[str(root/'reader')],
             binaries=collect_dynamic_libs('onnxruntime'), datas=data,
             hiddenimports=[], hookspath=[], runtime_hooks=[], excludes=[])
pyz = PYZ(a.pure)
exe = EXE(pyz, a.scripts, [], exclude_binaries=True, name='AHelperW',
          console=False, debug=False, strip=False, upx=False)
coll = COLLECT(exe, a.binaries, a.datas, strip=False, upx=False, name='AHelperW')
