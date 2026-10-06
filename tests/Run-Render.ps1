param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$CaptureName = 'map585'
)

$ErrorActionPreference = 'Stop'
$engine = (Get-Item -LiteralPath $GodotPath).FullName
if ((Get-Item -LiteralPath $engine).PSIsContainer) {
    $engine = (Get-ChildItem -LiteralPath $engine -Filter '*_console.exe' | Select-Object -First 1).FullName
}
$project = (Get-Item -LiteralPath $ProjectPath).FullName
if (-not (Test-Path -LiteralPath (Join-Path $project 'data/maps/Map585.json'))) { throw 'Map585 fixture not found.' }
if ($CaptureName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'CaptureName must be a simple filename.' }
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$logs = Join-Path $repository '.godot/test-logs'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$logPath = Join-Path $logs "$CaptureName.log"
$capturePath = Join-Path $logs "$CaptureName.png"
$testScript = Join-Path $PSScriptRoot 'runtime/MapRenderingTests.gd'
$arguments = @(
    '--path', ('"{0}"' -f $project),
    '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3',
    '--audio-driver', 'Dummy', '--position', '-10000,-10000',
    '--log-file', ('"{0}"' -f $logPath),
    '--script', ('"{0}"' -f $testScript),
    '--', ('"--capture={0}"' -f $capturePath)
)
$process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait
$logContent = [string](Get-Content -LiteralPath $logPath -Raw)
Write-Host $logContent
if ($process.ExitCode -ne 0 -or $logContent -match 'SCRIPT ERROR:|(?m)^ERROR:|(?m)^FAIL:' -or -not $logContent.Contains('MAP RENDER TESTS: PASSED')) {
    throw "Map rendering failed. Log: $logPath"
}
Write-Host "PASS: real rendering. Capture: $capturePath"
