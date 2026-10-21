# OpenClaude Portable - Windows setup (works on Windows PowerShell 5.1). Run via launch.bat.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not $env:OPENCLAUDE_CONFIG_DIR) {
  throw 'Run launch.bat instead; it sets up the portable environment first.'
}
if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64' -and $env:PROCESSOR_ARCHITEW6432 -ne 'AMD64') {
  throw 'This setup supports 64-bit Intel/AMD Windows only.'
}

$Root = Split-Path -Parent $PSScriptRoot

# ---- read versions.txt ----
$V = @{}
Get-Content (Join-Path $Root 'versions.txt') | ForEach-Object {
  if ($_ -match '^\s*([A-Za-z0-9_]+)\s*=\s*(.*?)\s*$') { $V[$Matches[1]] = $Matches[2] }
}
foreach ($k in 'NODE_VERSION', 'RG_VERSION', 'GIT_VERSION', 'GIT_TAG') {
  if (-not $V[$k]) { throw "versions.txt is missing $k" }
}

$PkgName = $V.OPENCLAUDE_PACKAGE
if (-not $PkgName) { $PkgName = '@twigpine/openclaude' }
$Rt      = Join-Path $Root 'runtime\win'
$NodeDir = Join-Path $Rt 'node'
$RgDir   = Join-Path $Rt 'rg'
$GitDir  = Join-Path $Rt 'git'
$App     = Join-Path $Root 'app\win'
$Tmp     = Join-Path $Root 'temp'
New-Item -ItemType Directory -Force -Path $Rt, $App, $Tmp | Out-Null
$env:PATH = "$NodeDir;$RgDir;$env:PATH"

# ---- helpers ----
function Get-File($url, $out) {
  for ($i = 1; $i -le 3; $i++) {
    try { Invoke-WebRequest $url -OutFile $out -UseBasicParsing; return }
    catch { if ($i -eq 3) { throw }; Start-Sleep -Seconds 2 }
  }
}

function Test-Hash($file, $expected, $label) {
  if (-not $expected) { Write-Host "WARNING: no checksum pinned for $label (unverified)"; return }
  $actual = (Get-FileHash $file -Algorithm SHA256).Hash
  if ($actual -ne $expected) {
    Remove-Item $file -Force
    throw "Checksum mismatch for $label (download deleted)"
  }
}

function Test-NeedInstall($dir, $exeRel, $ver) {
  $marker = "$dir.ver"
  if (-not (Test-Path (Join-Path $dir $exeRel))) { return $true }
  if (-not (Test-Path $marker)) { return $true }
  return ((Get-Content $marker -Raw).Trim() -ne $ver)
}

function Install-Zip($zip, $dest, $inner) {
  $x = Join-Path $Tmp 'x'
  if (Test-Path $x) { Remove-Item $x -Recurse -Force }
  Expand-Archive -Path $zip -DestinationPath $x -Force
  if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
  Move-Item (Join-Path $x $inner) $dest
  Remove-Item $x -Recurse -Force
  Remove-Item $zip -Force
}

# ---- Node.js ----
$nv = $V.NODE_VERSION
if (Test-NeedInstall $NodeDir 'node.exe' $nv) {
  $name = "node-v$nv-win-x64.zip"
  $zip  = Join-Path $Tmp $name
  Write-Host "Downloading Node.js $nv ..."
  Get-File "https://nodejs.org/dist/v$nv/$name" $zip
  $sums = (Invoke-WebRequest "https://nodejs.org/dist/v$nv/SHASUMS256.txt" -UseBasicParsing).Content
  if ($sums -is [byte[]]) { $sums = [Text.Encoding]::UTF8.GetString($sums) }
  $line = $sums -split "`n" | Where-Object { $_ -match ('\s' + [regex]::Escape($name) + '\s*$') } | Select-Object -First 1
  if (-not $line) { throw "No checksum listed for $name" }
  Test-Hash $zip (($line.Trim() -split '\s+')[0]) 'Node.js'
  Install-Zip $zip $NodeDir "node-v$nv-win-x64"
  Set-Content "$NodeDir.ver" $nv -Encoding ASCII
}

# ---- ripgrep ----
$rv = $V.RG_VERSION
if (Test-NeedInstall $RgDir 'rg.exe' $rv) {
  $inner = "ripgrep-$rv-x86_64-pc-windows-msvc"
  $zip   = Join-Path $Tmp "$inner.zip"
  Write-Host "Downloading ripgrep $rv ..."
  Get-File "https://github.com/BurntSushi/ripgrep/releases/download/$rv/$inner.zip" $zip
  Test-Hash $zip $V.RG_SHA256_WIN_X64 'ripgrep'
  Install-Zip $zip $RgDir $inner
  Set-Content "$RgDir.ver" $rv -Encoding ASCII
}

# ---- PortableGit (OpenClaude needs bash.exe on Windows) ----
$gv = $V.GIT_VERSION
if (Test-NeedInstall $GitDir 'bin\bash.exe' $gv) {
  $exe = Join-Path $Tmp 'PortableGit.7z.exe'
  Write-Host "Downloading PortableGit $gv (about 60 MB) ..."
  Get-File "https://github.com/git-for-windows/git/releases/download/$($V.GIT_TAG)/PortableGit-$gv-64-bit.7z.exe" $exe
  Test-Hash $exe $V.GIT_SHA256_WIN_X64 'PortableGit'
  if (Test-Path $GitDir) { Remove-Item $GitDir -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $GitDir | Out-Null
  Write-Host 'Extracting PortableGit (this can take a minute on a USB drive) ...'
  Start-Process -FilePath $exe -ArgumentList '-y', "-o`"$GitDir`"" -Wait -NoNewWindow
  Remove-Item $exe -Force
  if (-not (Test-Path (Join-Path $GitDir 'bin\bash.exe'))) { throw 'PortableGit extraction failed' }
  Set-Content "$GitDir.ver" $gv -Encoding ASCII
}

# ---- OpenClaude ----
Write-Host 'Installing OpenClaude (latest) ...'
& (Join-Path $NodeDir 'npm.cmd') install --prefix $App --no-bin-links --no-audit --no-fund "$PkgName@latest"
if ($LASTEXITCODE -ne 0) { throw 'npm install failed' }

$pkgRel = 'node_modules\' + ($PkgName -replace '/', '\')
$pkg  = Join-Path $App $pkgRel
$json = Get-Content (Join-Path $pkg 'package.json') -Raw | ConvertFrom-Json
if ($json.bin -is [string]) { $bin = $json.bin }
elseif ($json.bin.openclaude) { $bin = $json.bin.openclaude }
else { $bin = ($json.bin.PSObject.Properties | Select-Object -First 1).Value }
$bin = ($bin -replace '^\./', '') -replace '/', '\'
# Relative path on purpose: the drive letter changes between PCs.
Set-Content (Join-Path $App 'entry.txt') ($pkgRel + '\' + $bin) -Encoding ASCII
Write-Host "OpenClaude $($json.version) is ready."
