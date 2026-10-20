"""Derive cooperative save validation from the canonical synchronous method."""
from pathlib import Path
import re
import sys
from sync_script_headers import with_header

repo = Path(__file__).resolve().parents[1]
folder = repo / "templates/runtime/scripts/10_Support/Persistence"
source = (folder / "SaveCodec.gd").read_text("utf-8-sig")
start = re.search(r"(?m)^static func prepare\(", source).start()
start = source.index(") -> Dictionary:\n", start) + len(") -> Dictionary:\n")
end = source.index("\n\nstatic func testing_records", start)
body = source[start:end].rstrip()
body = body.replace(
    "Graph.reason(value, captured_classes)",
    "((await graph_check.call(value, captured_classes)) if graph_check.is_valid() else (await Graph.reason_cooperatively(value, pulse, captured_classes)))",
)
body = re.sub(r"Graph\.reason\(([^()]*)\)", r"(await Graph.reason_cooperatively(\1, pulse))", body)
objects_call = r'preload\("\.\./Scripting/ScriptRuntime\.gd"\)\.validate_saved_objects\(\s*saved,\s*script_data\.get\("classes",\s*\{"Object":\s*\{"parent":\s*"",\s*"kind":\s*"class"\}\}\)\s*\)'
body, object_replacements = re.subn(objects_call, '(await Graph.reason_cooperatively(saved, pulse, script_data.get("classes", {"Object": {"parent": "", "kind": "class"}})))', body)
assert object_replacements == 1, "Keep the independent saved-object check cooperative."
lines = []
depth = 0
for line in body.splitlines():
    stripped = line.lstrip()
    top_level = line.startswith("\t") and not line.startswith("\t\t")
    if depth == 0 and top_level and stripped and not stripped.startswith(("#", "elif ", "else:")):
        lines += ['\tif not await pulse.call():', '\t\treturn fail("事件前记录已取消。")']
    lines.append(line)
    if stripped.startswith("for ") and line.rstrip().endswith(":"):
        indent = line[:len(line) - len(stripped)] + "\t"
        lines += [indent + "if not await pulse.call():", indent + '\treturn fail("事件前记录已取消。")']
    code = re.sub(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#.*', "", line)
    depth += sum(code.count(char) for char in "([{") - sum(code.count(char) for char in ")]}")
    assert depth >= 0, line
assert depth == 0
result = '''extends "SaveCodec.gd"
## Generated from SaveCodec.prepare by tools/sync_save_preparation.py.
## Schema validation stays on the main thread. The detached graph checker may
## validate the same bounded graph and class links on a worker.
static func prepare_cooperatively(value: Variant, definitions: RefCounted, owned_snapshot: bool, pulse: Callable, graph_check: Callable = Callable()) -> Dictionary:
''' + "\n".join(lines) + "\n"
target = folder / "SavePreparation.gd"
result = with_header(target.relative_to(repo).as_posix(), result)
if "--check" in sys.argv:
    assert target.read_text("utf-8") == result, "Regenerate SavePreparation.gd from SaveCodec.prepare."
else:
    target.write_text(result, "utf-8")
print("SavePreparation canonical parity: PASSED")
