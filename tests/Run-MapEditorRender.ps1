param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$CaptureName = 'v033-map-runtime',
    [switch]$TilesetLayers
)
$ErrorActionPreference = 'Stop'
$taskEngine = (Get-Item -LiteralPath $GodotPath).FullName
$taskProject = (Get-Item -LiteralPath $ProjectPath).FullName
$taskRepository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($CaptureName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid capture name.' }
$taskCaptures = Join-Path $taskRepository ".godot/test-logs/$CaptureName"
New-Item -ItemType Directory -Path $taskCaptures -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor/Editor_MapEditingScenario.gd') -Destination (Join-Path $taskProject '.godot/Editor_MapEditingScenario.gd')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor/Editor_TilesetLayersScenario.gd') -Destination (Join-Path $taskProject '.godot/Editor_TilesetLayersScenario.gd')
$taskTest = if ($TilesetLayers) { 'Editor_TilesetLayersTests.gd' } else { 'Editor_MapEditingTests.gd' }
$taskMarker = if ($TilesetLayers) { 'TILESET LAYERS TESTS: PASSED' } else { 'MAP EDITING TESTS: PASSED' }
$taskLog = Join-Path $taskCaptures 'render.log'
$taskArguments = @('--path', ('"{0}"' -f $taskProject), '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3',
    '--audio-driver', 'Dummy', '--position', '-10000,-10000', '--disable-vsync', '--log-file', ('"{0}"' -f $taskLog),
    '--script', ('"{0}"' -f (Join-Path $PSScriptRoot "editor/$taskTest")), '--', ('"--captures={0}"' -f $taskCaptures))
$taskProcess = Start-Process -FilePath $taskEngine -ArgumentList $taskArguments -WindowStyle Hidden -PassThru
$taskDeadline = [DateTime]::UtcNow.AddSeconds(120)
while (-not $taskProcess.WaitForExit(5000)) {
    if ([DateTime]::UtcNow -ge $taskDeadline) { Stop-Process -Id $taskProcess.Id -Force; throw 'Map runtime render timed out.' }
}
$taskContent = [string](Get-Content -LiteralPath $taskLog -Raw)
Write-Host $taskContent
if ($taskProcess.ExitCode -ne 0 -or $taskContent -match 'SCRIPT ERROR:|(?m)^ERROR:|(?m)^FAIL:' -or -not $taskContent.Contains($taskMarker)) { throw "Map runtime rendering failed: $taskLog" }
Write-Host "PASS: saved map runtime pixels. Captures: $taskCaptures"
