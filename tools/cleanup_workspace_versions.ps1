# Execute only the explicitly verified workspace cleanup plan. Junction targets
# are never visited: unlink each junction, then reject remaining reparse points.
$ErrorActionPreference = 'Stop'
$cleanupWorkspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$cleanupRepo = Join-Path $cleanupWorkspace 'RGMigrator'
$cleanupOutput = Join-Path $cleanupWorkspace 'output'
$cleanupArchive = Join-Path $cleanupOutput 'archives'
$cleanupPlan = Get-Content -LiteralPath (Join-Path $cleanupArchive 'cleanup-plan.json') -Raw | ConvertFrom-Json
$cleanupResultPath = Join-Path $cleanupArchive 'cleanup-result.json'
if (Test-Path -LiteralPath $cleanupResultPath) { throw 'A cleanup result already exists; inspect it before rerunning.' }
if ($cleanupPlan.workspace -ne $cleanupWorkspace) { throw 'Wrong workspace.' }
if ((Get-FileHash -LiteralPath (Join-Path $cleanupArchive 'index.json') -Algorithm SHA256).Hash -ne $cleanupPlan.archive_index_sha256) { throw 'Archive index changed.' }

function Test-ChildPath([string]$Path, [string]$Parent) {
    return $Path.StartsWith($Parent.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Assert-NormalAncestors([string]$Path) {
    $ancestor = Get-Item -LiteralPath $Path -Force
    while ($null -ne $ancestor) {
        if ($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse ancestor: $($ancestor.FullName)" }
        if ($ancestor.FullName -eq $cleanupWorkspace) { return }
        $ancestor = $ancestor.Parent
    }
    throw "Path escaped workspace: $Path"
}

function Assert-DeletionRoot([string]$Path) {
    $absolute = [IO.Path]::GetFullPath($Path)
    if ($absolute -ne $Path -or !(Test-ChildPath $absolute $cleanupWorkspace)) { throw "Invalid path: $Path" }
    $item = Get-Item -LiteralPath $absolute -Force
    if (!$item.PSIsContainer) { throw "Not a directory: $Path" }
    Assert-NormalAncestors $absolute
    $allowedVersions = @('0.40','0.41','0.42','0.43','0.44','0.45','0.46','0.47','0.48','0.49','0.5')
    $allowedCandidates = @('candidate','final','script-comments','script-comments-final','script-comments-release')
    $scratchPrefixes = @('asset_safety_','audio_import_','custom_data_fixture_','flash_gameplay_data_','flash_message_row_','script_event_fixture_','source_comment_audit_','test_exports_','test_setup_fixture_','version_contract_','v025-','v045_','v046_','v047_','v048_','v049_','v050','v051')
    $allowed = ($item.Parent.FullName -eq $cleanupOutput -and $item.Name -in $allowedVersions) -or
        ($item.Parent.FullName -eq (Join-Path $cleanupOutput '0.51') -and $item.Name -in $allowedCandidates) -or
        ($absolute -eq (Join-Path $cleanupRepo 'test_exports_v0.28'))
    if ($item.Parent.FullName -eq (Join-Path $cleanupRepo '.godot') -and $item.Name -notin $cleanupPlan.keep_scratch) {
        foreach ($prefix in $scratchPrefixes) { if ($item.Name.StartsWith($prefix, [StringComparison]::Ordinal)) { $allowed = $true } }
    }
    if (!$allowed) { throw "Unapproved deletion root: $Path" }
    foreach ($protected in @($cleanupRepo, (Join-Path $cleanupWorkspace 'rm_template'), $cleanupArchive, $cleanupPlan.current_project)) {
        if ($absolute -eq $protected -or (Test-ChildPath $protected $absolute)) { throw "Protected path: $Path" }
    }
}

function Assert-NoReparseChildren([string]$Path) {
    $stack = [Collections.Generic.Stack[IO.DirectoryInfo]]::new()
    $stack.Push([IO.DirectoryInfo]::new($Path))
    while ($stack.Count) {
        $directory = $stack.Pop()
        foreach ($entry in $directory.EnumerateFileSystemInfos()) {
            if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Remaining reparse point: $($entry.FullName)" }
            if ($entry.Attributes -band [IO.FileAttributes]::Directory) { $stack.Push([IO.DirectoryInfo]$entry) }
        }
    }
}

$cleanupResult = [ordered]@{
    started = [DateTimeOffset]::Now.ToString('o')
    workspace = $cleanupWorkspace
    free_bytes_before = ([IO.DriveInfo]::new([IO.Path]::GetPathRoot($cleanupWorkspace))).AvailableFreeSpace
    unlinked = [Collections.Generic.List[string]]::new()
    deleted = [Collections.Generic.List[string]]::new()
    errors = [Collections.Generic.List[object]]::new()
}
function Save-CleanupResult {
    $cleanupResult | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $cleanupResultPath -Encoding utf8
}

# Validate every final absolute target before the first removal.
foreach ($root in $cleanupPlan.delete_directories) { Assert-DeletionRoot $root.path }
Save-CleanupResult
foreach ($link in $cleanupPlan.unlink_reparse_points) {
    $path = [IO.Path]::GetFullPath($link.path)
    $owners = @($cleanupPlan.delete_directories | Where-Object { Test-ChildPath $path $_.path })
    if ($owners.Count -ne 1 -or $path -ne $link.path) { throw "Link outside a single deletion root: $path" }
    Assert-NormalAncestors ([IO.Path]::GetDirectoryName($path))
    $item = Get-Item -LiteralPath $path -Force
    if (!($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Expected a reparse point: $path" }
    # Deliberately omit -Recurse: remove only the directory junction itself.
    Remove-Item -LiteralPath $path -Force
    if (Test-Path -LiteralPath $path) { throw "Junction removal failed: $path" }
    $cleanupResult.unlinked.Add($path)
}
Save-CleanupResult
Write-Output "Unlinked $($cleanupResult.unlinked.Count) reparse points without visiting their targets."
foreach ($root in $cleanupPlan.delete_directories) {
    try {
        Assert-DeletionRoot $root.path
        Assert-NoReparseChildren $root.path
        Remove-Item -LiteralPath $root.path -Recurse -Force
        if (Test-Path -LiteralPath $root.path) { throw 'Directory still exists.' }
        $cleanupResult.deleted.Add($root.path)
        if ($cleanupResult.deleted.Count % 25 -eq 0 -or (Test-ChildPath $root.path $cleanupOutput)) {
            Write-Output "Deleted $($cleanupResult.deleted.Count)/$($cleanupPlan.delete_directories.Count): $($root.path)"
            Save-CleanupResult
        }
    } catch {
        $cleanupResult.errors.Add(@{path=$root.path; error=$_.Exception.Message})
        Save-CleanupResult
        Write-Output "Failed: $($root.path): $($_.Exception.Message)"
    }
}
$cleanupResult.finished = [DateTimeOffset]::Now.ToString('o')
$cleanupResult.free_bytes_after = ([IO.DriveInfo]::new([IO.Path]::GetPathRoot($cleanupWorkspace))).AvailableFreeSpace
$cleanupResult.reclaimed_bytes = $cleanupResult.free_bytes_after - $cleanupResult.free_bytes_before
Save-CleanupResult
Write-Output ([pscustomobject]$cleanupResult | Select-Object started,finished,reclaimed_bytes,@{n='deleted_count';e={$_.deleted.Count}},@{n='errors_count';e={$_.errors.Count}} | ConvertTo-Json)
if ($cleanupResult.errors.Count) { exit 1 }
