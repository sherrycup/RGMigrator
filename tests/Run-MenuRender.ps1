param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$CaptureName = 'v018-menu-render',
    [switch]$Benchmark
)
$ErrorActionPreference = 'Stop'
$engine = (Get-Item -LiteralPath $GodotPath).FullName
if ((Get-Item -LiteralPath $engine).PSIsContainer) {
    $engine = (Get-ChildItem -LiteralPath $engine -Filter '*_console.exe' | Select-Object -First 1).FullName
}
$project = (Get-Item -LiteralPath $ProjectPath).FullName
if ($Benchmark -and -not (Test-Path -LiteralPath (Join-Path $project 'data/maps/Map585.json'))) {
    throw 'The fixed benchmark workload requires the Map585 sample.'
}
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($CaptureName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'CaptureName must be a simple directory name.' }
$captures = Join-Path $repository ".godot/test-logs/$CaptureName"
New-Item -ItemType Directory -Path $captures -Force | Out-Null
$log = Join-Path $captures 'render.log'
$arguments = @('--path', ('"{0}"' -f $project), '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3',
    '--audio-driver', 'Dummy', '--position', '-10000,-10000', '--disable-vsync',
    '--log-file', ('"{0}"' -f $log), '--script', ('"{0}"' -f (Join-Path $PSScriptRoot 'runtime/MenuRenderingTests.gd')),
    '--', ('"--captures={0}"' -f $captures))
if ($Benchmark) { $arguments += '--benchmark' }
$process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait
$content = [string](Get-Content -LiteralPath $log -Raw)
Write-Host $content
if ($process.ExitCode -ne 0 -or $content -match 'SCRIPT ERROR:|(?m)^ERROR:|(?m)^FAIL:' -or -not $content.Contains('MENU RENDER TESTS: PASSED')) {
    throw "Menu rendering failed. Log: $log"
}
Write-Host "PASS: menu real rendering. Captures: $captures"
