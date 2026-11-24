$ErrorActionPreference = 'Stop'
Set-Location (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
& flutter create . --platforms=web --project-name reqviora_frontend
if ($LASTEXITCODE -ne 0) { throw 'Flutter scaffold failed' }
& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependencies failed' }
& flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'Analyzer failed' }
& flutter test
if ($LASTEXITCODE -ne 0) { throw 'Tests failed' }
