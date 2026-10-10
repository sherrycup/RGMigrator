param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$CaptureName = 'v029-editor-render',
    [ValidateSet('1600x1000', '1280x800')][string]$Resolution = '1280x800',
    [switch]$DatabaseOnly,
    [switch]$ReadabilityOnly,
    [switch]$MapEditingOnly,
    [switch]$EventAuthoringOnly,
    [switch]$TilesetLayersOnly,
    [switch]$DatabaseAuthoringOnly,
    [switch]$FeedbackOnly,
    [switch]$FinalUiOnly
)
$ErrorActionPreference = 'Stop'
$taskEngine = (Get-Item -LiteralPath $GodotPath).FullName
$taskProject = (Get-Item -LiteralPath $ProjectPath).FullName
$taskRepository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($CaptureName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid capture name.' }
$taskCaptures = Join-Path $taskRepository ".godot/test-logs/$CaptureName"
New-Item -ItemType Directory -Path $taskCaptures -Force | Out-Null
$taskProbe = Join-Path $taskProject '.godot/editor_probe.gd'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor/EditorPluginProbe.gd') -Destination $taskProbe
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor/EditorMapEditingScenario.gd') -Destination (Join-Path $taskProject '.godot/EditorMapEditingScenario.gd')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor/EditorEventAuthoringScenario.gd') -Destination (Join-Path $taskProject '.godot/EditorEventAuthoringScenario.gd')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor/EditorTilesetLayersScenario.gd') -Destination (Join-Path $taskProject '.godot/EditorTilesetLayersScenario.gd')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor/EditorDatabaseAuthoringScenario.gd') -Destination (Join-Path $taskProject '.godot/EditorDatabaseAuthoringScenario.gd')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor/EditorFeedbackScenario.gd') -Destination (Join-Path $taskProject '.godot/EditorFeedbackScenario.gd')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor/EditorFinalUiScenario.gd') -Destination (Join-Path $taskProject '.godot/EditorFinalUiScenario.gd')
$taskLog = Join-Path $taskCaptures 'render.log'
$taskArguments = @('--editor', '--path', ('"{0}"' -f $taskProject), '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3',
    '--audio-driver', 'Dummy', '--position', '-10000,-10000', '--disable-vsync', '--log-file', ('"{0}"' -f $taskLog),
    '--', '--rgm-editor-probe', ('"--captures={0}"' -f $taskCaptures))
if ($Resolution) { $taskArguments += "--resolution=$Resolution" }
if ($DatabaseOnly) { $taskArguments += '--database-only' }
if ($ReadabilityOnly) { $taskArguments += '--readability-only' }
if ($MapEditingOnly) { $taskArguments += '--map-editing-only' }
if ($EventAuthoringOnly) { $taskArguments += '--event-authoring-only' }
if ($TilesetLayersOnly) { $taskArguments += '--tileset-layers-only' }
if ($DatabaseAuthoringOnly) { $taskArguments += '--database-authoring-only' }
if ($FeedbackOnly) { $taskArguments += '--feedback-only' }
if ($FinalUiOnly) { $taskArguments += '--final-ui-only' }
if ($FeedbackOnly) { $taskArguments = $taskArguments | Where-Object { $_ -notin @('--audio-driver','Dummy') } }
$taskProcess = Start-Process -FilePath $taskEngine -ArgumentList $taskArguments -WindowStyle Hidden -PassThru
# The final UI scenario opens several pages and captures both zoom levels; allow
# cold editor startup and off-screen rendering to finish on large source projects.
$taskDeadline = [DateTime]::UtcNow.AddSeconds($(if ($FinalUiOnly) { 600 } else { 180 }))
while (-not $taskProcess.WaitForExit(5000)) {
    if ([DateTime]::UtcNow -ge $taskDeadline) { Stop-Process -Id $taskProcess.Id -Force; throw 'Editor render timed out.' }
}
$taskContent = [string](Get-Content -LiteralPath $taskLog -Raw)
Write-Host $taskContent
if ($taskProcess.ExitCode -ne 0 -or $taskContent -match 'SCRIPT ERROR:|(?m)^ERROR:|(?m)^FAIL:' -or -not $taskContent.Contains('EDITOR PLUGIN PROBE: PASSED')) { throw "Editor rendering failed: $taskLog" }
Write-Host "PASS: actual editor plugin. Captures: $taskCaptures"
