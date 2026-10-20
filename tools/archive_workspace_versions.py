"""Archive explicitly selected releases and build a verified cleanup plan.

This tool never deletes anything. ZIPs contain every file in the selected
project directory, including project-local caches and editor state. Each entry
is checked against the SHA256 calculated while reading the source file.
"""

import hashlib
import json
import os
from pathlib import Path
import stat
import sys
import shutil
import zipfile
from datetime import datetime, timezone

REPO = Path(__file__).resolve().parents[1]
WORKSPACE = REPO.parent.resolve()
OUTPUT = WORKSPACE / "output"
ARCHIVES = OUTPUT / "archives"
CURRENT = (OUTPUT / "0.51/api-docs").resolve()
SELECTION = {
    "0.40": "first-reviewed", "0.41": "final", "0.42": "verified",
    "0.43": "delivery", "0.44": "release", "0.45": "delivery",
    "0.46": "final", "0.47": "final", "0.48": "fix-event-continuations",
    "0.49": "release", "0.5": "final", "0.51": "api-docs",
}
KEEP_SCRATCH = {
    "audio-tools", "codec", "diagnostics", "editor", "formatter-cache",
    "imported", "shader_cache", "source_reference", "test-logs", "tooling",
}
DISPOSABLE_PREFIXES = (
    "asset_safety_", "audio_import_", "custom_data_fixture_", "flash_gameplay_data_",
    "flash_message_row_", "script_event_fixture_", "source_comment_audit_",
    "test_exports_", "test_setup_fixture_", "version_contract_", "v025-",
    "v045_", "v046_", "v047_", "v048_", "v049_", "v050", "v051",
)


def digest(path):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def checked(path):
    resolved = path.resolve(strict=True)
    assert resolved.is_relative_to(WORKSPACE) and resolved != WORKSPACE, path
    attributes = path.lstat()
    assert not (getattr(attributes, "st_file_attributes", 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT), path
    return resolved


def files_in(root):
    for base, directories, files in os.walk(root, followlinks=False):
        for name in directories:
            checked(Path(base) / name)
        for name in sorted(files):
            path = Path(base) / name
            checked(path)
            yield path


def scan_without_links(root):
    """Inventory real files; record Windows junctions without visiting targets."""
    stack = [root]
    files, links, size = [], [], 0
    while stack:
        directory = stack.pop()
        with os.scandir(directory) as entries:
            for entry in entries:
                attributes = entry.stat(follow_symlinks=False)
                path = Path(entry.path)
                if getattr(attributes, "st_file_attributes", 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT:
                    links.append({"path":str(path), "target":os.readlink(path), "directory":stat.S_ISDIR(attributes.st_mode)})
                elif stat.S_ISDIR(attributes.st_mode):
                    stack.append(path)
                elif stat.S_ISREG(attributes.st_mode):
                    files.append(path)
                    size += attributes.st_size
                else:
                    raise AssertionError("Unsupported filesystem entry: " + str(path))
    return files, links, size


def build_plan(records):
    """Verify existing ZIPs and prepare explicit deletion roots, without deleting."""
    assert {row["version"] for row in records} == {"0.28", *SELECTION}
    for row in records:
        path = checked(Path(row["archive"]))
        assert path.parent == ARCHIVES and row["verified"]
        assert path.stat().st_size == row["archive_bytes"] and digest(path) == row["sha256"]
        with zipfile.ZipFile(path) as saved:
            manifest = json.loads(saved.read("ARCHIVE_MANIFEST.json"))
            assert manifest["version"] == row["version"]
            assert manifest["source"] == row["source"]
            assert len(manifest["files"]) == row["files"]
            assert len(saved.infolist()) == row["files"] + 1
            assert sum(item["size"] for item in manifest["files"]) == row["source_bytes"]
            assert len({item["path"] for item in manifest["files"]}) == row["files"]
            for item in manifest["files"]:
                assert saved.getinfo(item["path"]).file_size == item["size"]
        print(json.dumps({"archive_rechecked":row["version"]}), flush=True)
    deletion = []
    for version in SELECTION:
        if version == "0.51":
            deletion.extend(checked(path) for path in (OUTPUT / version).iterdir() if path.is_dir() and path.resolve() != CURRENT)
        else:
            deletion.append(checked(OUTPUT / version))
    old_copy = REPO / "test_exports_v0.28"
    if old_copy.exists():
        deletion.append(checked(old_copy))
    scratch = REPO / ".godot"
    for path in scratch.iterdir():
        if path.is_dir() and path.name not in KEEP_SCRATCH:
            assert path.name.startswith(DISPOSABLE_PREFIXES), "Unclassified directory: " + str(path)
            deletion.append(checked(path))
    protected = [CURRENT, ARCHIVES, REPO, WORKSPACE / "rm_template"]
    roots, links = [], []
    for path in deletion:
        assert all(path != keep and not keep.is_relative_to(path) for keep in protected)
        files, found, size = scan_without_links(path)
        roots.append({"path":str(path), "files":len(files), "bytes":size})
        links.extend(found)
    fingerprints = {}
    # Protect all maintained production/test code, the live project, and original RM input.
    for root in [REPO / name for name in ("scripts", "templates", "scenes", "tests") ] + [CURRENT, WORKSPACE / "rm_template"]:
        files, found, _ = scan_without_links(root)
        assert not found, root
        for path in files:
            fingerprints[str(path)] = digest(path)
    plan = {
        "workspace":str(WORKSPACE), "current_project":str(CURRENT),
        "archive_index_sha256":digest(ARCHIVES / "index.json"),
        "verified_archives":len(records), "delete_directories":roots,
        "unlink_reparse_points":links, "keep_scratch":sorted(KEEP_SCRATCH),
        "protected_file_sha256":fingerprints,
        "free_bytes_before_deletion":shutil.disk_usage(WORKSPACE).free,
    }
    (ARCHIVES / "cleanup-plan.json").write_text(json.dumps(plan, ensure_ascii=False, indent=2)+"\n", "utf-8")
    print(json.dumps({"archives_verified":len(records), "delete_directories":len(roots), "reparse_points":len(links), "delete_GiB":round(sum(row["bytes"] for row in roots)/1024**3,2), "protected_files":len(fingerprints)},ensure_ascii=False), flush=True)


def verify_cleanup():
    """Confirm archived releases, deleted roots, and unchanged protected files."""
    plan = json.loads((ARCHIVES / "cleanup-plan.json").read_text("utf-8-sig"))
    result = json.loads((ARCHIVES / "cleanup-result.json").read_text("utf-8-sig"))
    index = json.loads((ARCHIVES / "index.json").read_text("utf-8"))
    assert not result["errors"]
    assert set(result["deleted"]) == {row["path"] for row in plan["delete_directories"]}
    assert set(result["unlinked"]) == {row["path"] for row in plan["unlink_reparse_points"]}
    assert digest(ARCHIVES / "index.json") == plan["archive_index_sha256"]
    assert all(not os.path.lexists(row["path"]) for row in plan["delete_directories"])
    assert {path.name for path in OUTPUT.iterdir()} == {"archives", "0.51"}
    assert {path.name for path in (OUTPUT / "0.51").iterdir()} == {"api-docs"}
    assert {path.name for path in (REPO / ".godot").iterdir() if path.is_dir()} == KEEP_SCRATCH
    assert not list(ARCHIVES.glob("*.partial"))
    assert len(list(ARCHIVES.glob("*.zip"))) == len(index["archives"]) == 13
    for row in index["archives"]:
        assert digest(Path(row["archive"])) == row["sha256"], row["archive"]
    print("All 13 ZIP checksums and directory boundaries passed.", flush=True)
    for name, checksum in plan["protected_file_sha256"].items():
        assert digest(Path(name)) == checksum, name
    # Compare the retained live project with the completed 0.51 archive too.
    latest = next(row for row in index["archives"] if row["version"] == "0.51")
    with zipfile.ZipFile(latest["archive"]) as saved:
        manifest = json.loads(saved.read("ARCHIVE_MANIFEST.json"))
    prefix = manifest["archive_root"] + "/"
    current_files, links, _ = scan_without_links(CURRENT)
    assert not links and len(current_files) == latest["files"]
    for row in manifest["files"]:
        assert row["path"].startswith(prefix)
        path = CURRENT / row["path"][len(prefix):]
        assert plan["protected_file_sha256"][str(path)] == row["sha256"], path
    verification = {
        "verified_at":datetime.now(timezone.utc).isoformat(),
        "archives_verified":len(index["archives"]),
        "deleted_directories":len(result["deleted"]),
        "unlinked_reparse_points":len(result["unlinked"]),
        "protected_files_unchanged":len(plan["protected_file_sha256"]),
        "live_project_matches_archive":True,
        "reclaimed_bytes":result["reclaimed_bytes"],
        "archive_bytes":sum(row["archive_bytes"] for row in index["archives"]),
        "ok":True,
    }
    (ARCHIVES / "cleanup-verification.json").write_text(json.dumps(verification, ensure_ascii=False, indent=2)+"\n", "utf-8")
    print(json.dumps(verification, ensure_ascii=False), flush=True)


def archive(version, source, relative_root, note=""):
    checked(source)
    reports = list(source.glob("*/migration_report.json"))
    assert reports, source
    for report in reports:
        value = json.loads(report.read_text("utf-8-sig"))
        assert value.get("ok") and not value.get("errors"), report
        assert value.get("version", value.get("tool_version")) == "RGMigrator ver" + version, report
        assert (report.parent / "project.godot").is_file(), report
    target = ARCHIVES / ("RGMigrator-" + version + ("-available" if note else "-final") + ".zip")
    temporary = target.with_suffix(".zip.partial")
    assert not target.exists() and not temporary.exists(), target
    manifest = {"version":version,"source":str(source),"archive_root":relative_root,"note":note,"files":[]}
    with zipfile.ZipFile(temporary, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=1, allowZip64=True, strict_timestamps=False) as output:
        for path in files_in(source):
            before = path.stat()
            name = relative_root + "/" + path.relative_to(source).as_posix()
            info = zipfile.ZipInfo.from_file(path, name, strict_timestamps=False)
            info.compress_type = zipfile.ZIP_DEFLATED
            info._compresslevel = 1
            checksum = hashlib.sha256()
            with path.open("rb") as original, output.open(info, "w", force_zip64=True) as compressed:
                while block := original.read(1024 * 1024):
                    checksum.update(block)
                    compressed.write(block)
            after = path.stat()
            assert before.st_size == after.st_size and before.st_mtime_ns == after.st_mtime_ns, path
            manifest["files"].append({"path":name,"size":after.st_size,"sha256":checksum.hexdigest()})
        output.writestr("ARCHIVE_MANIFEST.json", json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    with zipfile.ZipFile(temporary) as saved:
        assert len(saved.infolist()) == len(manifest["files"]) + 1
        for row in manifest["files"]:
            assert saved.getinfo(row["path"]).file_size == row["size"]
            with saved.open(row["path"]) as handle:
                assert hashlib.file_digest(handle, "sha256").hexdigest() == row["sha256"], row["path"]
    temporary.rename(target)
    result = {"version":version,"source":str(source),"archive":str(target),"sha256":digest(target),"files":len(manifest["files"]),"source_bytes":sum(row["size"] for row in manifest["files"]),"archive_bytes":target.stat().st_size,"verified":True,"note":note}
    print(json.dumps({"archived":version,"files":result["files"],"MiB":round(result["archive_bytes"]/1024**2,1),"verified":True}), flush=True)
    return result


def main():
    ARCHIVES.mkdir(exist_ok=False)
    records = []
    old_copy = REPO / "test_exports_v0.28"
    if old_copy.is_dir():
        records.append(archive("0.28", old_copy, "0.28/available-copy", "现存0.28验收副本；记录中的后续fix-01输出已不在工作区，未将此副本冒称为后续修复版。"))
    for version, folder in SELECTION.items():
        records.append(archive(version, OUTPUT / version / folder, version + "/" + folder))
        (ARCHIVES / "index.json").write_text(json.dumps({"current_project":str(CURRENT),"archives":records}, ensure_ascii=False, indent=2)+"\n", "utf-8")
    build_plan(records)


if __name__ == "__main__":
    if sys.argv[1:] == ["--plan-existing"]:
        build_plan(json.loads((ARCHIVES / "index.json").read_text("utf-8"))["archives"])
    elif sys.argv[1:] == ["--verify-cleanup"]:
        verify_cleanup()
    else:
        assert not sys.argv[1:], sys.argv[1:]
        main()
