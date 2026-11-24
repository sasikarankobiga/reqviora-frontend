# Run Flutter Web starter against the .NET 10 backend started in Visual Studio 2026.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $root
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter SDK is missing. Install Flutter stable; use VS Code Flutter extension or Flutter CLI.'
}
& flutter --version
if ($LASTEXITCODE -ne 0) { throw 'Flutter SDK check failed' }
if (-not (Test-Path '.\web\manifest.json')) {
  # Flutter platform files are generated on first run; existing custom sources are retained.
  & flutter create . --platforms=web --project-name reqviora_frontend
  if ($LASTEXITCODE -ne 0) { throw 'Flutter platform generation failed' }
}
& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
& flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed' }
& flutter test
if ($LASTEXITCODE -ne 0) { throw 'flutter test failed' }
Write-Host 'Starting Flutter Web on http://localhost:5310, API on http://127.0.0.1:5264'
& flutter run -d chrome --web-port=5310 --dart-define=REQVIORA_LOCAL_DEMO=true --dart-define=REQVIORA_API_BASE_URL=http://127.0.0.1:5264
if ($LASTEXITCODE -ne 0) { throw 'Flutter run failed' }
