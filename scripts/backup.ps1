# Copia en frio para recuperacion manual. Para respaldos portables .inkflow usa la app.
param([string]$Destination = (Join-Path $PSScriptRoot '..\backups'))
$ErrorActionPreference = 'Stop'
if (Get-Process -Name inkflow -ErrorAction SilentlyContinue) { throw 'Cierra InkFlow antes de crear una copia en frio.' }
$docs = [Environment]::GetFolderPath('MyDocuments')
$data = Join-Path $docs 'InkFlowData'
if (-not (Test-Path -LiteralPath $data)) { throw 'No se encontro InkFlowData.' }
$destinationPath = [IO.Path]::GetFullPath($Destination)
if ($destinationPath.StartsWith([IO.Path]::GetFullPath($data), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'El respaldo debe guardarse fuera de InkFlowData.'
}
New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
$staging = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $staging | Out-Null
try {
    Copy-Item -LiteralPath $data -Destination $staging -Recurse
    $legacy = Join-Path $docs 'inkflow.sqlite'
    foreach ($suffix in @('', '-wal', '-shm', '-journal')) {
        if (Test-Path -LiteralPath "$legacy$suffix") { Copy-Item -LiteralPath "$legacy$suffix" -Destination $staging }
    }
    $output = Join-Path $destinationPath ('InkFlow-Cold-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.zip')
    Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $output
    Write-Output "Copia en frio creada: $output"
    Write-Output 'Recuperacion manual con la app cerrada: consulta docs/USER_GUIDE.md. No importar como .inkflow.'
} finally {
    $resolvedStaging = [IO.Path]::GetFullPath($staging)
    $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedStaging.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolvedStaging) -match '^[0-9a-f]{32}$') {
        Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
    }
}
