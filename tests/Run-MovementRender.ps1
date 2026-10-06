param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$CaptureName = 'v018-movement-render'
)
$ErrorActionPreference = 'Stop'
$taskEngine = (Get-Item -LiteralPath $GodotPath).FullName
if ((Get-Item -LiteralPath $taskEngine).PSIsContainer) {
    $taskEngine = (Get-ChildItem -LiteralPath $taskEngine -Filter '*_console.exe' | Select-Object -First 1).FullName
}
$taskProject = (Get-Item -LiteralPath $ProjectPath).FullName
$taskRepository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($CaptureName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'CaptureName must be a simple directory name.' }
$taskCaptures = Join-Path $taskRepository ".godot/test-logs/$CaptureName"
New-Item -ItemType Directory -Path $taskCaptures -Force | Out-Null
$taskLog = Join-Path $taskCaptures 'render.log'
$taskArguments = @('--path', ('"{0}"' -f $taskProject), '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3',
    '--audio-driver', 'Dummy', '--position', '-10000,-10000', '--disable-vsync', '--log-file', ('"{0}"' -f $taskLog),
    '--script', ('"{0}"' -f (Join-Path $PSScriptRoot 'runtime/MovementRenderingTests.gd')), '--', ('"--captures={0}"' -f $taskCaptures))
$taskProcess = Start-Process -FilePath $taskEngine -ArgumentList $taskArguments -WindowStyle Hidden -PassThru -Wait
$taskContent = [string](Get-Content -LiteralPath $taskLog -Raw)
Write-Host $taskContent
if ($taskProcess.ExitCode -ne 0 -or $taskContent -match 'SCRIPT ERROR:|(?m)^ERROR:|(?m)^FAIL:' -or -not $taskContent.Contains('MOVEMENT RENDER TESTS: PASSED')) {
    throw "Movement rendering failed. Log: $taskLog"
}
