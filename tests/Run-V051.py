"""Run v0.51 checks only in a disposable generated project, never a user project."""
from game_test_names import migrated_game_tests
from pathlib import Path
import argparse, json, re, shutil, subprocess, time

repo = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--engine", required=True)
parser.add_argument("--fixture", required=True)
parser.add_argument("--suite", choices=["runtime", "editor", "failures", "restart"], default="runtime")
parser.add_argument("--cases", nargs="*")
parser.add_argument("--tag", default="candidate")
args = parser.parse_args()
fixture = Path(args.fixture).resolve()
assert fixture.is_relative_to((repo / ".godot").resolve()), "Use a disposable fixture inside repository .godot"
assert all((fixture / folder).is_dir() for folder in ["legacy/extras", "legacy/ordered_scripts", "legacy/ruby_scripts", "migration_docs"]), "Use the complete Flash export, including source scripts, documentation, auxiliary files and map snapshots"
assert re.fullmatch(r"[a-zA-Z0-9_-]+", args.tag)
rows = []
logs = repo / ".godot/test-logs"
logs.mkdir(parents=True, exist_ok=True)

def run(name, extra=(), fatal=False):
    source = repo / "tests/runtime" / (name + ".gd")
    if not source.exists():
        source = repo / "tests/editor" / (name + ".gd")
    script_name = f"v051_{args.tag}_{args.suite}_check.gd"
    shutil.copy2(source, fixture / script_name)
    token = str(time.time_ns())
    config = fixture / "project.godot"
    content = config.read_text("utf-8-sig")
    for setting in ["test_preferences_directory", "test_save_directory"]:
        content = re.sub(rf'(?m)^{setting}=.*\n?', "", content)
    content = content.replace("[rgmigrator]", f'[rgmigrator]\ntest_preferences_directory="res://.godot/v051-{token}-prefs"\ntest_save_directory="res://.godot/v051-{token}-saves"')
    config.write_text(content, "utf-8")
    label = name + ("-" + extra[-1].split("=", 1)[-1] if extra else "")
    log = logs / f"v051-{args.tag}-{label}.log"
    started = time.monotonic()
    try:
        result = subprocess.run([args.engine, "--headless", "--audio-driver", "Dummy", "--path", str(fixture), "--log-file", str(log), "--script", "res://"+script_name, "--quit-after", "9000", "--", *extra], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180, creationflags=0x08000000)
        output = result.stdout + result.stderr
        if fatal:
            match = re.search(r"V049 FAILURE CHECK: (.+)", output)
            evidence = json.loads(match[1]) if match else {}
            ok = result.returncode == 1 and evidence.get("ok", False) and "FATAL SCRIPT ERROR:" in output and "SCRIPT ERROR:" not in output.replace("FATAL SCRIPT ERROR:", "")
        else:
            evidence = {}
            ok = result.returncode == 0 and "PASSED" in output and not re.search(r"SCRIPT ERROR:|^FAIL:", output, re.M)
        row = {"name": label, "ok": ok, "exit": result.returncode, "seconds": round(time.monotonic()-started, 2), "markers": [line for line in output.splitlines() if "PASSED" in line or line.startswith(("FAIL:", "SCRIPT ERROR:", "V049 FAILURE CHECK:"))], "evidence": evidence}
    except subprocess.TimeoutExpired:
        row = {"name": label, "ok": False, "timeout": True}
    rows.append(row)
    print(json.dumps({key: row[key] for key in ["name", "ok", "exit"] if key in row}, ensure_ascii=True), flush=True)
    (logs / f"v051-{args.tag}-{args.suite}.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2), "utf-8")

if args.suite == "runtime":
    cases = args.cases or ["RuntimeCompileTests", "ScriptSemanticsRuntimeTests", "ScriptEventSourceTests"] + [p.stem for p in sorted((repo / "tests/runtime").glob("*Tests.gd")) if p.stem in migrated_game_tests(repo) and p.stem != "GameSaveRestartTests"]
    for name in cases:
        run(name)
elif args.suite == "editor":
    shutil.copy2(repo / "tests/editor/Editor_StructureGuideScenario.gd", fixture / ".godot/Editor_StructureGuideScenario.gd")
    for name in args.cases or ["Editor_CompileTests", "Editor_ReadabilityTests", "Editor_CommandBlockTests", "Editor_StructureGuideTests", "Editor_CustomDataTests", "Editor_ScriptUiTests", "Editor_ScriptWorkspaceTests", "Editor_ScriptSourceFlowTests"]:
        run(name)
elif args.suite == "restart":
    directory = "res://.godot/v051-restart-" + str(time.time_ns())
    for phase in ["write", "read"]:
        run("GameSaveRestartTests", ["--save-directory=" + directory, "--phase=" + phase])
else:
    for mode in args.cases or ["actor", "motion", "effect", "keyboard", "floor", "fractional-floor", "character", "support-skill", "down-switch", "debug", "deputy", "unsafe-object", "gem-id", "gem-expression", "window", "shop-catalog", "shop-quantity", "shop-zero", "shop-buy-only", "shop-sell-only", "crystal-duplicate", "crystal-element", "crystal-locked", "missing-scan", "missing-noise", "invalid-effect", "damage-worker"]:
        run("FailureIsolationProbe", ["--case=" + mode], True)
raise SystemExit(0 if all(row["ok"] for row in rows) else 1)
