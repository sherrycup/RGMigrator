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
Invoke-GodotCheck 'ruby-ast' $projectRoot @('--script', 'res://tests/RubyAstTests.gd') 'RUBY AST TESTS: PASSED'
Invoke-GodotCheck 'ruby-semantic-model' $projectRoot @('--script', 'res://tests/RubySemanticModelTests.gd') 'RUBY SEMANTIC MODEL: PASSED'
Invoke-GodotCheck 'ruby-compiler' $projectRoot @('--script', 'res://tests/RubyCompilerTests.gd') 'RUBY COMPILER TESTS: PASSED'
Invoke-GodotCheck 'script-migration-subset' $projectRoot @('--script', 'res://tests/ScriptMigrationTests.gd') 'SCRIPT MIGRATION TESTS: PASSED'
Invoke-GodotCheck 'script-event-importer' $projectRoot @('--script', 'res://tests/ScriptEventIntegrationTests.gd') 'SCRIPT EVENT IMPORTER: PASSED'
$scriptEventFixture = Get-Content -LiteralPath (Join-Path $projectRoot '.godot/v043-fixture-path.txt') -Raw
Invoke-GodotCheck 'script-event-fixture-import' $scriptEventFixture @('--import')
Invoke-GodotCheck 'script-event-runtime' $scriptEventFixture @('--script', (Join-Path $PSScriptRoot 'runtime/ScriptEventRuntimeTests.gd')) 'SCRIPT EVENT RUNTIME: PASSED'
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
    Invoke-GodotCheck "sample-$index-editor-compile" $outputProject @('--script', (Join-Path $PSScriptRoot 'editor/Editor_CompileTests.gd')) 'EDITOR COMPILE: PASSED'
	Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor/Editor_TilesetLayersScenario.gd') -Destination (Join-Path $outputProject '.godot/Editor_TilesetLayersScenario.gd')
	Invoke-GodotCheck "sample-$index-tileset-layers" $outputProject @('--script', (Join-Path $PSScriptRoot 'editor/Editor_TilesetLayersTests.gd')) 'TILESET LAYERS TESTS: PASSED'
	Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor/Editor_MapEditingScenario.gd') -Destination (Join-Path $outputProject '.godot/Editor_MapEditingScenario.gd')
	Invoke-GodotCheck "sample-$index-map-editing" $outputProject @('--script', (Join-Path $PSScriptRoot 'editor/Editor_MapEditingTests.gd')) 'MAP EDITING TESTS: PASSED'
	Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor/Editor_EventAuthoringScenario.gd') -Destination (Join-Path $outputProject '.godot/Editor_EventAuthoringScenario.gd')
	Invoke-GodotCheck "sample-$index-event-authoring" $outputProject @('--script', (Join-Path $PSScriptRoot 'editor/Editor_EventAuthoringTests.gd')) 'EVENT AUTHORING TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-editor" $outputProject @('--script', (Join-Path $PSScriptRoot 'editor/Editor_Tests.gd')) 'EDITOR TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-command-blocks" $outputProject @('--script', (Join-Path $PSScriptRoot 'editor/Editor_CommandBlockTests.gd')) 'COMMAND BLOCK TESTS: PASSED'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor/Editor_StructureGuideScenario.gd') -Destination (Join-Path $outputProject '.godot/Editor_StructureGuideScenario.gd')
    Invoke-GodotCheck "sample-$index-structure-guides" $outputProject @('--script', (Join-Path $PSScriptRoot 'editor/Editor_StructureGuideTests.gd')) 'STRUCTURE GUIDE TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-database-editor" $outputProject @('--script', (Join-Path $PSScriptRoot 'editor/Editor_DatabaseTests.gd')) 'DATABASE EDITOR TESTS: PASSED'
	Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor/Editor_DatabaseAuthoringScenario.gd') -Destination (Join-Path $outputProject '.godot/Editor_DatabaseAuthoringScenario.gd')
	Invoke-GodotCheck "sample-$index-database-authoring" $outputProject @('--script', (Join-Path $PSScriptRoot 'editor/Editor_DatabaseAuthoringTests.gd')) 'DATABASE AUTHORING TESTS: PASSED'
	Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor/Editor_FeedbackScenario.gd') -Destination (Join-Path $outputProject '.godot/Editor_FeedbackScenario.gd')
	Invoke-GodotCheck "sample-$index-editor-feedback" $outputProject @('--script', (Join-Path $PSScriptRoot 'editor/Editor_FeedbackTests.gd')) 'EDITOR FEEDBACK TESTS: PASSED'

    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'editor/Editor_FinalUiScenario.gd') -Destination (Join-Path $outputProject '.godot/Editor_FinalUiScenario.gd')
    Invoke-GodotCheck "sample-$index-final-ui" $outputProject @('--script', (Join-Path $PSScriptRoot 'editor/Editor_FinalUiTests.gd')) 'FINAL UI TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-editor-readability" $outputProject @('--script', (Join-Path $PSScriptRoot 'editor/Editor_ReadabilityTests.gd')) 'EDITOR READABILITY TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-title" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/TitleTests.gd')) 'TITLE TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-runtime" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/RuntimeTests.gd'), '--quit-after', '1200') 'RUNTIME TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-events" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/EventTests.gd')) 'EVENT TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-event-values" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/EventValueTests.gd')) 'EVENT VALUE TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-event-movement" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/EventMovementTests.gd')) 'EVENT MOVEMENT TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-push-box" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/PushBoxRegressionTests.gd')) 'PUSH BOX TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-event-screen" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/EventScreenTests.gd')) 'EVENT SCREEN TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-event-presentation" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/EventPresentationTests.gd')) 'EVENT PRESENTATION TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-event-actor-scene" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/EventActorSceneTests.gd')) 'EVENT ACTOR SCENE TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-event-save" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/EventSaveTests.gd')) 'EVENT SAVE TESTS: PASSED'
    $eventRestartDirectory = (Join-Path $outputProject ('.godot/event_restart_' + [Guid]::NewGuid().ToString('N'))).Replace('\', '/')
    foreach ($phase in @('write', 'read')) {
        Invoke-GodotCheck "sample-$index-event-restart-$phase" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/EventSaveTests.gd'), '--', "--save-directory=$eventRestartDirectory", "--phase=$phase") 'EVENT SAVE TESTS: PASSED'
    }
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
    Invoke-GodotCheck "sample-$index-script-runtime" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/ScriptMigrationRuntimeTests.gd')) 'SCRIPT RUNTIME TESTS: PASSED'
    Invoke-GodotCheck "sample-$index-script-semantics" $outputProject @('--script', (Join-Path $PSScriptRoot 'runtime/ScriptSemanticsRuntimeTests.gd')) 'SCRIPT SEMANTICS RUNTIME: PASSED'
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
