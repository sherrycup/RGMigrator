param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$CaptureName = 'v019-presentation',
    [switch]$Benchmark
)
$ErrorActionPreference = 'Stop'
$taskEngine = (Get-Item -LiteralPath $GodotPath).FullName
if ((Get-Item -LiteralPath $taskEngine).PSIsContainer) {
    $taskEngine = (Get-ChildItem -LiteralPath $taskEngine -Filter '*_console.exe' | Select-Object -First 1).FullName
}
$taskProject = (Get-Item -LiteralPath $ProjectPath).FullName
if ($CaptureName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'CaptureName must be a simple directory name.' }
$taskCaptures = Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))) ".godot/test-logs/$CaptureName"
New-Item -ItemType Directory -Path $taskCaptures -Force | Out-Null
$taskLog = Join-Path $taskCaptures 'render.log'
$taskArguments = @('--path', ('"{0}"' -f $taskProject), '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3',
    '--audio-driver', 'Dummy', '--position', '-10000,-10000', '--disable-vsync', '--log-file', ('"{0}"' -f $taskLog),
    '--script', ('"{0}"' -f (Join-Path $PSScriptRoot 'runtime/PresentationRenderingTests.gd')), '--', ('"--captures={0}"' -f $taskCaptures))
if ($Benchmark) { $taskArguments += '--benchmark' }
$taskProcess = Start-Process -FilePath $taskEngine -ArgumentList $taskArguments -WindowStyle Hidden -PassThru -Wait
$taskContent = [string](Get-Content -LiteralPath $taskLog -Raw)
$taskContent -split "`n" | Where-Object { $_ -match 'ERROR|FAIL:|PASSED|PERFORMANCE:' } | Write-Host
if ($taskProcess.ExitCode -ne 0 -or $taskContent -match 'SCRIPT ERROR:|(?m)^ERROR:|(?m)^FAIL:' -or -not $taskContent.Contains('PRESENTATION RENDER TESTS: PASSED')) {
    throw "Presentation rendering failed. Log: $taskLog"
}
