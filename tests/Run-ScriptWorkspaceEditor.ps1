param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$CaptureName = 'v048-script-plugin',
    [switch]$Headless
)
$ErrorActionPreference = 'Stop'
$taskEngine = (Get-Item -LiteralPath $GodotPath).FullName
$taskProject = (Get-Item -LiteralPath $ProjectPath).FullName
$taskRepository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($CaptureName -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid capture name.' }
$taskLog = Join-Path $taskRepository ".godot/test-logs/$CaptureName.log"
# The caller supplies a disposable project; the probe never runs game events.
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor/Editor_ScriptPluginProbe.gd') -Destination (Join-Path $taskProject '.godot/editor_probe.gd') -Force
$taskArguments = @('--editor', '--path', ('"{0}"' -f $taskProject), '--audio-driver', 'Dummy',
    '--position', '-10000,-10000', '--log-file', ('"{0}"' -f $taskLog))
if ($Headless) { $taskArguments += '--headless' }
else { $taskArguments += @('--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3', '--disable-vsync') }
$taskArguments += @('--', '--rgm-editor-probe')
if (-not $Headless) { $taskArguments += '--embed-probe' }
$taskProcess = Start-Process -FilePath $taskEngine -ArgumentList $taskArguments -WindowStyle Hidden -PassThru
$taskDeadline = [DateTime]::UtcNow.AddSeconds(600)
while (-not $taskProcess.WaitForExit(1000)) {
    if ([DateTime]::UtcNow -ge $taskDeadline) { Stop-Process -Id $taskProcess.Id -Force; throw 'Script workspace editor probe timed out.' }
}
$taskContent = [string](Get-Content -LiteralPath $taskLog -Raw)
Write-Host ($taskContent -split '\r?\n' | Where-Object { $_ -match 'PLUGIN|SCRIPT ERROR|FAIL:' })
if ($taskProcess.ExitCode -ne 0 -or $taskContent -match 'SCRIPT ERROR:|(?m)^FAIL:' -or -not $taskContent.Contains('SCRIPT PLUGIN PROBE: PASSED')) { throw "Script workspace editor probe failed: $taskLog" }
Write-Host "PASS: script workspace in actual EditorPlugin. Log: $taskLog"
