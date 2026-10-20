"""Refresh source paths and public contracts while preserving hand-written notes."""
from pathlib import Path
import re

repo = Path(__file__).resolve().parents[1]
doc_path = repo / "AGENTS.md"
doc = doc_path.read_text("utf-8")
files = [repo / "scripts/Main.gd", repo / "scripts/Version.gd"]
for root in ("templates/runtime/scripts", "templates/editor/addons/rgm_editor", "scripts/importer"):
    files.extend((repo / root).rglob("*.gd"))
signature = re.compile(r"^(?:static )?func ([A-Za-z_][A-Za-z0-9_]*)\(.*\)\s*->\s*[^:]+")
member = re.compile(r"^(?:(?:static )?var|const) ([A-Za-z][A-Za-z0-9_]*)")


def logical_lines(source):
    declaration = []
    for line in source.splitlines():
        if declaration:
            declaration.append(line.strip())
            if line.strip().endswith(":"):
                yield " ".join(declaration)
                declaration = []
        elif line.startswith(("func ", "static func ")) and not line.endswith(":"):
            declaration.append(line)
        else:
            yield line


new_sections = []
methods_count = 0
for path in sorted(files):
    parent = class_line = ""
    fields, constants, signals, constructors, methods = [], [], [], [], []
    for line in logical_lines(path.read_text("utf-8-sig")):
        if line.startswith("extends "): parent = line
        if line.startswith("class_name "): class_line = line
        if line.startswith("signal "): signals.append(line)
        match = member.search(line)
        if match:
            if line.startswith("const "):
                if "preload(" not in line: constants.append("`" + match[1] + "`")
            else: fields.append("`" + match[1] + "`")
        match = signature.search(line)
        if match:
            if match[1] == "_init" and "_init()" not in match[0]: constructors.append(match[0].strip())
            elif not match[1].startswith("_"): methods.append(match[0].strip())
    methods_count += len(methods)
    contract = [parent] + ([class_line] if class_line else []) + signals + constructors + methods
    if not methods and not constructors: contract.append("# 本类未声明自定义公共方法。")
    header = "### " + path.name + "\n"
    match = re.search(r"(?ms)^" + re.escape(header) + r".*?(?=^### |^## |\Z)", doc)
    if match:
        section = match[0]
        section = re.sub(r"公开字段：[^\n]*", "公开字段：" + ("、".join(fields) or "无") + "。", section)
        section = re.sub(r"常量（不含依赖脚本引用）：[^\n]*", "常量（不含依赖脚本引用）：" + ("、".join(constants) or "无") + "。", section)
        section = re.sub(r"源文件：[^。]+。", "源文件：" + path.relative_to(repo).as_posix() + "。", section)
        section = re.sub(r"```gdscript\n.*?```", "```gdscript\n" + "\n".join(contract) + "\n```", section, count=1, flags=re.S)
        doc = doc[:match.start()] + section + doc[match.end():]
    else:
        new_sections.append(header + "\n公开字段：" + ("、".join(fields) or "无") + "。\n\n常量（不含依赖脚本引用）：" + ("、".join(constants) or "无") + "。\n\n源文件：" + path.relative_to(repo).as_posix() + "。职责与调用方式见 docs/SCRIPT_STRUCTURE_v0.51.md。\n\n```gdscript\n" + "\n".join(contract) + "\n```\n")
doc += "\n" + "\n".join(new_sections)
doc = re.sub(r"全部\d+个生产脚本", f"全部{len(files)}个生产脚本", doc)
doc = doc.replace("# RGMigrator ver0.5 —", "# RGMigrator ver0.51 —", 1)
doc_path.write_text(doc.rstrip() + "\n", "utf-8")
print(f"Agent contracts: {len(files)} scripts, {methods_count} public methods.")
