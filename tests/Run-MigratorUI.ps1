param([Parameter(Mandatory = $true)][string]$GodotPath)
$ErrorActionPreference = 'Stop'
$engine = (Get-Item -LiteralPath $GodotPath).FullName
if ((Get-Item -LiteralPath $engine).PSIsContainer) {
    $engine = (Get-ChildItem -LiteralPath $engine -Filter '*_console.exe' | Select-Object -First 1).FullName
}
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$log = Join-Path $repository '.godot/test-logs/v019-migrator-ui.log'
$arguments = @('--path', ('"{0}"' -f $repository), '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy',
    '--position', '-10000,-10000', '--log-file', ('"{0}"' -f $log), '--script', 'res://tests/MigratorUITests.gd')
$process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait
$content = [string](Get-Content -LiteralPath $log -Raw)
Write-Host $content
if ($process.ExitCode -ne 0 -or $content -match 'SCRIPT ERROR:|(?m)^ERROR:|(?m)^FAIL:' -or -not $content.Contains('MIGRATOR UI TESTS: PASSED')) {
    throw "Migrator UI failed. Log: $log"
}
