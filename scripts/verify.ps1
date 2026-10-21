param([switch]$NativeIntegration)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
New-Item -ItemType Directory -Path (Join-Path $project 'logs') -Force | Out-Null
function Check-NativeExit { if ($LASTEXITCODE -ne 0) { throw "La verificacion fallo con codigo $LASTEXITCODE." } }
Push-Location (Join-Path $project 'app')
try {
    flutter doctor -v 2>&1 | Tee-Object -FilePath ..\logs\doctor.log
    flutter pub get
    Check-NativeExit
    flutter analyze --no-pub 2>&1 | Tee-Object -FilePath ..\logs\analyze.log
    Check-NativeExit
    dart format --set-exit-if-changed . 2>&1 | Tee-Object -FilePath ..\logs\format.log
    Check-NativeExit
    flutter test --no-pub --reporter expanded 2>&1 | Tee-Object -FilePath ..\logs\tests.log
    Check-NativeExit
    dart run ..\scripts\crash_recovery_test.dart 2>&1 | Tee-Object -FilePath ..\logs\crash-recovery.log
    Check-NativeExit
    if ($NativeIntegration) {
        $artifacts = (Join-Path $project 'logs').Replace('\', '/')
        flutter test integration_test/offline_workflow_test.dart -d windows --no-pub "--dart-define=INKFLOW_TEST_ARTIFACTS=$artifacts" --reporter expanded 2>&1 | Tee-Object -FilePath ..\logs\integration-windows.log
        Check-NativeExit
        flutter test integration_test/canvas_workflow_test.dart -d windows "--dart-define=INKFLOW_TEST_ARTIFACTS=$artifacts" --reporter expanded 2>&1 | Tee-Object -FilePath ..\logs\integration-canvas.log
        Check-NativeExit
        flutter test integration_test/library_workflow_test.dart -d windows "--dart-define=INKFLOW_TEST_ARTIFACTS=$artifacts" --reporter expanded 2>&1 | Tee-Object -FilePath ..\logs\integration-library.log
        Check-NativeExit
    }
} finally { Pop-Location }
