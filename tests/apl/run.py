"""Run offline APL scenarios: python tests/apl/run.py [spec ...]

Each tests/apl/spec_*.py module defines FIXTURE (synthetic export) and
SCENARIOS (harness.Scenario). A spec argument matches the module name part
(e.g. 71, 72, 269, core, 251). No game, capture, OCR or input is used.
"""
import importlib.util
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import harness  # noqa: E402


def main(selected):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    started = time.perf_counter()
    failures = total = 0
    for path in sorted(HERE.glob('spec_*.py')):
        name = path.stem[5:]
        if selected and not any(s == name or name.startswith(s + '_') for s in selected):
            continue
        spec = importlib.util.spec_from_file_location(path.stem, path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        print(f'[{name}]')
        for scenario in module.SCENARIOS:
            total += 1
            try:
                ok, detail = harness.run_scenario(module, scenario)
            except Exception as exc:  # a crash is a failure with its reason
                ok, detail = False, f'{type(exc).__name__}: {exc}'
            failures += not ok
            print(f"  {'OK ' if ok else 'FAIL'} {scenario.name} — {detail}")
    print(f'{total - failures}/{total} сценариев прошло за {time.perf_counter() - started:.2f} с')
    return 1 if failures or not total else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
