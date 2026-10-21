$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$app = Join-Path $project 'app'
$builds = Join-Path $project 'builds'
if (-not (Test-Path -LiteralPath (Join-Path $app 'android\key.properties'))) {
    throw 'Configura android/key.properties con tu clave de firma propia. Consulta docs/INSTALLATION.md.'
}
New-Item -ItemType Directory -Path $builds -Force | Out-Null
function Invoke-Flutter {
    param([string[]]$Arguments)
    & flutter @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Flutter fallo: $Arguments (codigo $LASTEXITCODE)" }
}
Push-Location $app
try {
    Invoke-Flutter -Arguments @('pub', 'get')
    Invoke-Flutter -Arguments @('analyze', '--no-pub')
    Invoke-Flutter -Arguments @('test', '--no-pub')
    Invoke-Flutter -Arguments @('build', 'apk', '--release', '--target-platform', 'android-arm64')
    Copy-Item -LiteralPath (Join-Path $app 'build\app\outputs\flutter-apk\app-release.apk') -Destination (Join-Path $builds 'InkFlow.apk') -Force
    Get-FileHash (Join-Path $builds 'InkFlow.apk') -Algorithm SHA256
} finally { Pop-Location }


