"""Run 0.57 evidence in one explicitly disposable generated project."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import time

repo = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--engine", required=True)
parser.add_argument("--fixture", required=True)
parser.add_argument("--suite", choices=["runtime", "editor", "fatal", "restart"], default="runtime")
parser.add_argument("--cases", nargs="*")
parser.add_argument("--tag", default="candidate")
parser.add_argument("--save-directory")
args = parser.parse_args()
fixture = Path(args.fixture).resolve()
assert fixture.is_relative_to(repo / ".godot") and (fixture / "project.godot").is_file()
assert re.fullmatch(r"[a-zA-Z0-9_-]+", args.tag)
logs = repo / ".godot/test-logs"
rows = []

def run(name, extra=(), fatal=False):
    source = next(p for p in [repo / "tests/runtime" / (name + ".gd"), repo / "tests/editor" / (name + ".gd")] if p.is_file())
    target = fixture / "v057_check.gd"
    shutil.copy2(source, target)
    config_path = fixture / "project.godot"
    config = config_path.read_text("utf-8-sig")
    token = str(time.time_ns())
    for setting in ["test_preferences_directory", "test_save_directory"]:
        config = re.sub(rf'(?m)^{setting}=.*\n?', "", config)
    config = config.replace("[rgmigrator]", f'[rgmigrator]\ntest_preferences_directory="res://.godot/v057-{token}-prefs"\ntest_save_directory="res://.godot/v057-{token}-saves"')
    config_path.write_text(config, "utf-8")
    label = name + ("-" + extra[-1].split("=", 1)[-1] if extra else "")
    log = logs / f"v057-{args.tag}-{label}.log"
    started = time.monotonic()
    result = subprocess.run([args.engine, "--headless", "--audio-driver", "Dummy", "--path", str(fixture), "--log-file", str(log), "--script", "res://v057_check.gd", "--quit-after", "9000", "--", *extra], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=240, creationflags=0x08000000)
    output = result.stdout + result.stderr
    if fatal:
        match = re.search(r"NATIVE FATAL V052: (.+)", output)
        report = json.loads(match[1]) if match else {}
        ok = result.returncode == 1 and report.get("ok", False) and "FATAL SCRIPT ERROR:" in output
    else:
        report = {}
        expected_compile = name == "Editor_NativeEventV052Tests"
        script_errors = output.count("SCRIPT ERROR:")
        ok = result.returncode == 0 and "PASSED" in output and "FAIL:" not in output and (script_errors == 1 if expected_compile else script_errors == 0)
    row = {"name":label,"ok":ok,"exit":result.returncode,"seconds":round(time.monotonic()-started, 2),"log":str(log),"markers":[line for line in output.splitlines() if "PASSED" in line or line.startswith(("FAIL:","SCRIPT ERROR:","V052 FINGERPRINT:"))],"evidence":report}
    rows.append(row)
    (logs / f"v057-{args.tag}-{args.suite}.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2), "utf-8")
    print(json.dumps({key:row[key] for key in ["name","ok","exit"]}), flush=True)

if args.suite == "runtime":
    for name in args.cases or ["RuntimeCompileTests","FunctionalWindowsV057Tests","ItemPageTests","SightTests","MapSystemTests","SceneShopBusinessTests","StandaloneTests","UICommonV053Tests","MessageV054Tests","GamePresentationTests","MessageTextTests","MessageBoxStateTests","MessageControllerTests","TextRowEventTests","TitleNoteTests","TitleV055Tests","ConfigPageTests","ArchiveTests","MenuArchiveV056Tests","MenuNavigationTests","GraphicsCacheTests","NativeMigrationV052Tests","ReadableEventV052Tests","NativeEventV052Tests","IntegrationV049Tests","SnapshotV050Tests","PersistenceTests","StructureV051Tests"]:
        run(name)
elif args.suite == "editor":
    for name in args.cases or ["Editor_CompileTests","Editor_CommandBlockTests","Editor_NativeEventV052Tests","Editor_UIContrastV053Tests"]:
        run(name)
elif args.suite == "fatal":
    for mode in args.cases or ["runtime","semantic","compile","condition","binding","body_runtime","body_compile","body_api"]:
        run("NativeFatalV052Probe", ["--case=" + mode], True)
else:
    assert args.save_directory, "Use an explicitly isolated save directory."
    for phase in args.cases or ["write", "read"]:
        run("GameSaveRestartTests", ["--save-directory=" + args.save_directory,"--phase=" + phase])
raise SystemExit(0 if all(row["ok"] for row in rows) else 1)
