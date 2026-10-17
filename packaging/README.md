# Windows release build

Current package: **0.5.0** (addon **0.2.16**; reader models Arms/Slayer, Fury/Slayer,
Windwalker/Shado-Pan, Frost and Unholy DK, Retribution). First package was 0.3.0. The version is
set in `packaging/setup.iss` (`AppVersion`) and `packaging/build.ps1` (`$version`).
Windows x64, Python 3.12, Inno Setup 6.7.3. Run from the project root:

```powershell
py -3.12 -m venv .build-venv
.build-venv/Scripts/python.exe -m pip install -r packaging/requirements-build.txt
# Commit all source changes before building.
powershell -File packaging/build.ps1 -ISCC 'C:\Path\To\Inno Setup 6\ISCC.exe'
```

Obtain Inno Setup from https://jrsoftware.org/isdl.php and verify its publisher
signature before installation. The script does not install build tools or publish
anything. It produces an installer, matching Git source archive, build metadata
and SHA-256 checksums under `dist/release`.

The application is a PyInstaller directory bundle. Python, Tcl/Tk, ONNX Runtime,
OpenCV, OCR models and notices are bundled. Only explicitly listed JSON resources
are copied; no local HUD profiles, bindings, logs or development environment.
Dependencies are pinned in `requirements-build.txt`.

Installed reader data lives in `%LOCALAPPDATA%\AHelperW`. Development continues
to use `reader/`. Imported profiles persist in the installed application. On every
packaged start, reading and automatic input are off. The installer never starts
the reader or the game.

The addon component requires `_retail_\Wow.exe`. Existing addon contents are
backed up before replacement; junctions are refused. Uninstall intentionally
preserves the addon, backups, WoW settings and user data. Reader-only installation
is available through component selection.

The installer requires elevation to write the addon under Program Files. The
reader itself runs normally without requesting elevation. The initial package
is unsigned; Windows may display an unknown-publisher warning.

Build completion is not an end-to-end installation or gameplay test. Publish
the initial artifact as a prerelease until installation and first-run behavior
are verified on a clean Windows environment.
