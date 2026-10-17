param([string]$ISCC = "$PSScriptRoot\..\build\tools\inno\ISCC.exe")
$ErrorActionPreference = 'Stop'
$version = '0.5.0'  # keep equal to AppVersion in setup.iss
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    $pythonExe = Join-Path $projectRoot '.build-venv\Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $pythonExe)) { throw 'Create .build-venv first; see packaging/README.md' }
    if (-not (Test-Path -LiteralPath $ISCC)) { throw 'Specify -ISCC with the installed Inno Setup compiler path' }
    $changes = git status --porcelain
    if ($LASTEXITCODE -ne 0 -or $changes) { throw 'Commit source changes first so the bundled source archive matches the build' }
    & $pythonExe packaging/collect_licenses.py
    if ($LASTEXITCODE -ne 0) { throw 'License collection failed' }
    & $pythonExe -m PyInstaller --noconfirm --distpath dist --workpath build/pyinstaller packaging/AHelperW.spec
    if ($LASTEXITCODE -ne 0) { throw 'PyInstaller failed' }
    New-Item -ItemType Directory -Force -Path dist/release | Out-Null
    git archive --format=zip --output=dist/release/AHelperW-Source-$version.zip HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Source archive failed' }
    & $ISCC packaging/setup.iss
    if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed' }
    $commit = git rev-parse HEAD
    $manifest = [ordered]@{ version=$version; commit=$commit; platform='windows-x64'; python=(& $pythonExe --version); innoSetup='6.7.3' }
    $manifest | ConvertTo-Json | Set-Content -Encoding utf8 dist/release/build-info.json
    $releaseFiles = @("AHelperW-Setup-$version-windows-x64.exe", "AHelperW-Source-$version.zip", 'build-info.json')
    $checksums = foreach ($name in $releaseFiles) {
        $hash = Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path 'dist/release' $name)
        "$($hash.Hash.ToLowerInvariant())  $name"
    }
    $checksums | Set-Content -Encoding ascii dist/release/SHA256SUMS.txt
} finally { Pop-Location }
