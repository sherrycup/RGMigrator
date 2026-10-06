param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [switch]$SkipMigration,
    [switch]$RefreshRuntime,
    [switch]$SkipImport
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$engine = (Get-Item -LiteralPath $GodotPath).FullName
if ((Get-Item -LiteralPath $engine).PSIsContainer) {
    $engine = (Get-ChildItem -LiteralPath $engine -Filter '*_console.exe' | Select-Object -First 1).FullName
}
if (-not $engine -or -not (Test-Path -LiteralPath $engine -PathType Leaf)) {
    throw 'Godot executable not found.'
}
$logs = Join-Path $projectRoot '.godot/test-logs'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
$checks = [Collections.Generic.List[object]]::new()

function Invoke-GodotCheck([string]$Name, [string]$Project, [string[]]$Extra, [string]$Marker = '') {
    $log = Join-Path $logs "$Name.log"
    Write-Host "RUN: $Name"
    $toolOutput = & $engine --headless --path $Project --log-file $log @Extra 2>&1
    $status = $LASTEXITCODE
    $content = [string]::Join("`n", $toolOutput)
    $toolOutput | Where-Object { "$_" -match 'ERROR|FAIL:|PASSED|passed|EXPORTED:|COUNTS:|Refreshed' } | Out-Host
    $passed = $status -eq 0 -and $content -notmatch 'SCRIPT ERROR:|(?m)^ERROR:|(?m)^FAIL:' -and (-not $Marker -or $content.Contains($Marker))
    $checks.Add([pscustomobject]@{ name = $Name; passed = $passed; exit_code = $status; log = $log })
    if (-not $passed) {
        Write-Warning "Godot check failed: $Name (exit=$status). Log: $log"
        if ($Name -eq 'importer-tests') { throw 'Migration failed; cannot test generated projects.' }
    } else {
        Write-Host "PASS: $Name"
    }
}

Invoke-GodotCheck 'documentation-contract' $projectRoot @('--script', 'res://tests/DocumentationTests.gd') 'DOCUMENTATION TESTS: PASSED'
if (-not $SkipMigration) {
    Invoke-GodotCheck 'importer-tests' $projectRoot @('--script', 'res://tests/TestRunner.gd', '--', '--full') 'RGMigrator tests passed.'
} else {
    Invoke-GodotCheck 'importer-unit-tests' $projectRoot @('--script', 'res://tests/TestRunner.gd') 'RGMigrator tests passed.'
}
if ($RefreshRuntime) {
    Invoke-GodotCheck 'refresh-runtime' $projectRoot @('--script', 'res://tests/RefreshTestRuntime.gd') 'Refreshed test runtime:'
}
Invoke-GodotCheck 'migrator-startup' $projectRoot @('--quit-after', '3')
$results = Get-Content -LiteralPath (Join-Path $projectRoot '.godot/test-results.json') -Raw | ConvertFrom-Json
$index = 0
foreach ($outputProject in $results.exports) {
    $index++
    if (-not $SkipImport) {
        Invoke-GodotCheck "sample-$index-import" $outputProject @('--import')
    }
    Invoke-GodotCheck "sample-$index-title" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/TitleTests.gd')) 'TITLE TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-runtime" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/RuntimeTests.gd'), '--quit-after', '1200') 'RUNTIME TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-menu" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/MenuTests.gd')) 'MENU TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-inventory" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/InventoryTests.gd')) 'INVENTORY TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-skills-animation" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/SkillAnimationTests.gd')) 'SKILL ANIMATION TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-shop-state" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/ShopStateTests.gd')) 'SHOP STATE TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-actor-mutations" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/ActorMutationTests.gd')) 'ACTOR MUTATION TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-screen" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/ScreenTests.gd')) 'SCREEN TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-graphics-cache" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/GraphicsCacheTests.gd')) 'GRAPHICS CACHE TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-movement" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/MovementTests.gd')) 'MOVEMENT TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-presentation" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/PresentationTests.gd')) 'PRESENTATION TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-compile" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/RuntimeCompileTests.gd')) 'RUNTIME COMPILE: PASSED'
    Invoke-GodotCheck "sample-$index-save" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/SaveTests.gd')) 'SAVE TESTS: PASSED'
    $restartDirectory = (Join-Path $outputProject ('.godot/save_restart_' + [Guid]::NewGuid().ToString('N'))).Replace('\', '/')
    foreach ($phase in @('write', 'read')) {
        Invoke-GodotCheck "sample-$index-save-restart-$phase" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/SaveRestartTests.gd'), '--', "--save-directory=$restartDirectory", "--phase=$phase") 'SAVE RESTART TESTS: PASSED'
    }
    Invoke-GodotCheck "sample-$index-menu-quit" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/MenuQuitTests.gd')) 'QUIT MENU REQUESTED'
}
$summary = [pscustomobject]@{
    timestamp = (Get-Date -Format o)
    engine = $engine
    migration_skipped = [bool]$SkipMigration
    import_skipped = [bool]$SkipImport
    checks = $checks.ToArray()
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $logs 'summary.json') -Encoding utf8
# Keep the full-import result when a later focused rerun skips import/migration.
if (-not $SkipMigration -and -not $SkipImport) {
    $summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $logs 'full-summary.json') -Encoding utf8
}
if (@($checks | Where-Object { -not $_.passed }).Count -gt 0) {
    Write-Warning "Some headless checks failed. Logs: $logs"
    exit 1
}
Write-Host "Selected headless checks passed (migration skipped=$SkipMigration, import skipped=$SkipImport). Logs: $logs"
