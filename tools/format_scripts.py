"""Format production GDScript with AST and comment preservation checks.

Development-only dependency: gdtoolkit 4.5.0 (installed in .godot/tooling).
The generated game has no Python or formatter dependency.
"""
from pathlib import Path
import argparse
import json
import sys

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / ".godot/tooling"))
from gdtoolkit.parser import parser
from gdtoolkit.formatter import format_code
from gdtoolkit.formatter.safety_checks import check_tree_invariant, check_comment_persistence

parser._cache_dirpath = str(REPO / ".godot/formatter-cache")


def main():
    arguments = argparse.ArgumentParser(description=__doc__)
    arguments.add_argument("--check", action="store_true")
    args = arguments.parse_args()
    roots = [REPO / part for part in ("templates/runtime/scripts", "templates/editor/addons/rgm_editor", "scripts/importer")]
    rows = []
    failures = []
    for path in sorted(p for root in roots for p in root.rglob("*.gd")):
        if path.name in ("SavePreparation.gd", "ScriptPaths.gd"):
            continue  # Maintained by their canonical generators.
        original = path.read_text("utf-8-sig")
        try:
            formatted = format_code(original, max_line_length=100)
        except Exception as error:
            failures.append(str(path.relative_to(REPO)))
            print(f"Formatter input error: {path.relative_to(REPO)}: {str(error).splitlines()[0]}", flush=True)
            continue
        check_tree_invariant(original, formatted)
        check_comment_persistence(original, formatted)
        if not args.check:
            path.write_text(formatted, "utf-8")
        rows.append({"path": str(path.relative_to(REPO)), "changed": original != formatted, "ast_preserved": True, "comments_preserved": True})
    logs = REPO / ".godot/test-logs"
    logs.mkdir(parents=True, exist_ok=True)
    (logs / ("v051-format-check.json" if args.check else "v051-format.json")).write_text(json.dumps(rows, indent=2), "utf-8")
    changed = sum(row["changed"] for row in rows)
    print(f"Formatting: {len(rows)} scripts checked; {changed} changed; AST and comments preserved.")
    return int(bool(failures) or args.check and changed > 0)


if __name__ == "__main__":
    raise SystemExit(main())
