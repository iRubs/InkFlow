$ErrorActionPreference = 'Stop'
function Invoke-Flutter {
    param([string[]]$Arguments)
    & flutter @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Flutter fallo: $Arguments (codigo $LASTEXITCODE)" }
}
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$app = Join-Path $project 'app'
$builds = Join-Path $project 'builds'
New-Item -ItemType Directory -Path $builds -Force | Out-Null
Push-Location $app
try {
    Invoke-Flutter -Arguments @('pub', 'get')
    Invoke-Flutter -Arguments @('analyze', '--no-pub')
    Invoke-Flutter -Arguments @('test', '--no-pub')
    Invoke-Flutter -Arguments @('build', 'windows', '--release')
    $release = Join-Path $app 'build\windows\x64\runner\Release'
    $portable = Join-Path $builds 'Windows'
    New-Item -ItemType Directory -Path $portable -Force | Out-Null
    Copy-Item -Path (Join-Path $release '*') -Destination $portable -Recurse -Force
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $visualStudio = & $vswhere -latest -products '*' -property installationPath
    $runtime = Get-ChildItem -LiteralPath (Join-Path $visualStudio 'VC\Redist\MSVC') -Filter vcruntime140.dll -Recurse |
        Where-Object { $_.FullName -match '\\x64\\Microsoft\.VC\d+\.CRT\\' } | Select-Object -First 1
    if (-not $runtime) { throw 'No se encontro el runtime redistribuible x64 de Visual C++.' }
    Copy-Item -Path (Join-Path $runtime.DirectoryName '*.dll') -Destination $portable -Force
    $compilerPaths = @((Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'))
    $compiler = $compilerPaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $compiler) { throw 'Instala Inno Setup 6 para generar el instalador.' }
    & $compiler (Join-Path $PSScriptRoot 'inkflow.iss')
    if ($LASTEXITCODE -ne 0) { throw 'Fallo Inno Setup.' }
    Get-FileHash (Join-Path $builds 'InkFlow-Setup.exe') -Algorithm SHA256
} finally { Pop-Location }


