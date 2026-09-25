# Build SendTo for Windows and compile the Inno Setup installer.
# Requires: Flutter, Visual Studio C++ workload, Inno Setup 6 (ISCC.exe).

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $root

Write-Host "Building SendTo (icons kept)..."
flutter pub get
flutter build windows --release --no-tree-shake-icons

$release = Join-Path $root "build\windows\x64\runner\Release\sendto.exe"
if (-not (Test-Path $release)) {
  throw "Release exe missing: $release"
}

$iscc = @(
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $iscc) {
  Write-Host "Inno Setup not found. Install from https://jrsoftware.org/isinfo.php"
  Write-Host "Portable folder is ready at:"
  Write-Host "  $root\build\windows\x64\runner\Release"
  exit 0
}

New-Item -ItemType Directory -Force -Path (Join-Path $root "installer\out") | Out-Null
& $iscc (Join-Path $PSScriptRoot "sendto.iss")
Write-Host "Installer: $root\installer\out\SendTo-Setup-0.1.0.exe"
