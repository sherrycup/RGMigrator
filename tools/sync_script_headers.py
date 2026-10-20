"""Maintain Chinese usage, public signatures, parameters and return documentation.

Responsibilities live in script_descriptions.json; parameter meanings and
reviewed interface contracts live in script_api_docs.json. Historical exports,
Godot caches and disposable test projects are outside the maintained roots.
"""

import argparse
import json
from pathlib import Path
import re

from gdscript_interfaces import has_await, interfaces

REPO = Path(__file__).resolve().parents[1]
CATALOG = REPO / "tools/script_descriptions.json"
ROOTS = ("scripts", "templates", "tests")
PREFIX = "## 职责："
END = "## 接口说明结束。"
API_CATALOG = REPO / "tools/script_api_docs.json"


def sources():
    return sorted(path for root in ROOTS for path in (REPO / root).rglob("*.gd"))


def strip_header(source):
    if source.startswith(PREFIX):
        if END in source.split("\n\n", 1)[0]:
            return source.partition(END + "\n")[2].lstrip("\n")
        return source.partition("\n")[2].lstrip("\n")
    return source


def resource_path(path):
    path = str(path).replace("\\", "/")
    for source, target in (("templates/runtime/scripts/", "runtime/scripts/"), ("templates/editor/addons/", "addons/")):
        if path.startswith(source):
            return "res://" + target + path[len(source):]
    return "res://" + path


def parameter_description(parameter, method, file_docs, api):
    name = parameter["name"]
    override = file_docs.get("methods", {}).get(method["name"], {})
    if name in override.get("parameters", {}):
        return override["parameters"][name]
    if name in file_docs.get("parameters", {}):
        return file_docs["parameters"][name]
    if method["name"] in ("handle_key", "press") and name in ("key", "code"):
        return "Godot 按键码，例如 KEY_UP、KEY_DOWN、KEY_ENTER 或 KEY_ESCAPE"
    if name == "direction" and method["name"] in ("navigate", "move_selection", "adjust", "change_actor"):
        return "选择或调整的方向增量；正负号按当前页面的导航逻辑处理"
    if name.startswith("_") and len(re.findall(r"\b" + re.escape(name) + r"\b", method.get("body", ""))) <= 1:
        return "为保持原接口位置保留，本实现未读取此参数"
    assert name in api["parameters"], "Document parameter meaning: " + name
    return api["parameters"][name]


def return_description(method, file_docs):
    override = file_docs.get("methods", {}).get(method["name"], {})
    if "returns" in override:
        return override["returns"]
    if method["name"] == "_init":
        return "构造函数本身不返回值；通过 .new(...) 获得该脚本的实例"
    type_name = method["return"]
    if type_name == "void":
        return "无返回值；处理结果通过对象状态、界面或相应信号体现"
    if type_name == "bool":
        if method["name"] in ("handle_key", "handle_input"):
            return "true 表示本次输入已被处理，false 表示未由该入口处理"
        return "布尔结果；true/false 的条件以本方法的判断逻辑为准"
    if type_name == "Dictionary":
        if re.search(r'[\"\']ok[\"\']\s*:', method.get("body", "")):
            return "结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供"
        return "字典结果；字段结构与本方法返回的数据一致"
    if type_name.startswith(("Array", "Packed")):
        return "按本方法约定排列的集合；元素类型见返回类型"
    if type_name in ("String", "StringName"):
        return "文本结果；空字符串是否代表成功或缺失，按本方法约定处理"
    if type_name in ("int", "float"):
        return "数值结果；编号、单位与计算含义由本接口用途决定"
    if type_name == "Variant":
        return "动态类型结果；允许的具体类型由输入和实际返回分支决定"
    return type_name + " 类型的对象或值，供调用方继续使用"


def header(description, source="", path=""):
    api = json.loads(API_CATALOG.read_text("utf-8"))
    file_docs = api["files"].get(Path(path).name, {})
    info = interfaces(source)
    rows = [PREFIX + description, "##", "## 调用方式："]
    usage = file_docs.get("usage", [])
    if not usage:
        if str(path).replace("\\", "/").startswith("tests/"):
            usage = ["在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。"]
        else:
            usage = []
            static = [m for m in info["methods"] if m["static"]]
            instance = [m for m in info["methods"] if not m["static"]]
            if static:
                usage.append("静态接口：preload(\"" + resource_path(path) + "\").方法名(...)。")
            if instance:
                usage.append("实例接口：先用 preload(\"" + resource_path(path) + "\").new(...) 构造，再调用下列方法。")
            if info["parent"] not in ("RefCounted", "Object") and not info["parent"].startswith('"') and instance:
                usage.append("节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。")
            if not usage:
                if info["callbacks"]:
                    usage.append("脚本由所属场景或插件挂载；下列回调由 Godot 调用。")
                else:
                    usage.append("通过 preload(\"" + resource_path(path) + "\") 读取本文件的常量或作为父类使用。")
    rows.extend("##   " + line.replace("preload(运行路径)", 'preload("' + resource_path(path) + '")').replace("preload(编辑器路径)", 'preload("' + resource_path(path) + '")') for line in usage)
    rows += ["##", "## 调用接口："]
    if not info["methods"]:
        rows.append("##   本文件未声明额外公开方法；使用常量、继承接口或下列场景树回调。")
    for method in info["methods"]:
        method_docs = file_docs.get("methods", {}).get(method["name"], {})
        purpose = method_docs.get("description", api["methods"].get(method["name"], ""))
        if method["name"] == "_init":
            purpose = purpose or "构造本实例并记录初始化依赖"
        rows.append("##   " + method["signature"])
        if purpose:
            rows.append("##     用途：" + purpose.rstrip("。") + "。")
        if not method["parameters"]:
            rows.append("##     参数：无。")
        for parameter in method["parameters"]:
            default = "；默认值 " + parameter["default"] if parameter["default"] is not None else "；必填"
            meaning = parameter_description(parameter, method, file_docs, api)
            rows.append(f'##     参数 {parameter["name"]}（{parameter["type"]}{default}）：{meaning.rstrip("。")}。')
        rows.append("##     返回：" + return_description(method, file_docs).rstrip("。") + "。")
        if has_await(method.get("body", "")):
            rows.append("##     等待：本方法包含异步等待；需要完成结果的调用方使用 await。")
        rows.append("##")
    if info["signals"]:
        rows += ["## 对外信号："]
        for signal in info["signals"]:
            args = ", ".join(p["name"] + ": " + p["type"] for p in signal["parameters"])
            meaning = file_docs.get("signals", {}).get(signal["name"], api.get("signals", {}).get(signal["name"], "由持有方发出，通知对应状态或操作结果"))
            rows.append("##   " + signal["name"] + "(" + args + ")：" + meaning.rstrip("。") + "。")
            for parameter in signal["parameters"]:
                description = file_docs.get("parameters", {}).get(parameter["name"], api["parameters"].get(parameter["name"], parameter["name"]))
                rows.append("##     " + parameter["name"] + "：" + description.rstrip("。") + "。")
        rows.append("##")
    if info["callbacks"]:
        rows.append("## 场景树回调（Godot 自动调用）：")
        for method in info["callbacks"]:
            rows.append("##   " + method["signature"])
            for parameter in method["parameters"]:
                rows.append("##     " + parameter["name"] + "：" + parameter_description(parameter, method, file_docs, api) + "。")
        rows.append("##")
    if info["constants"]:
        rows.append("## 公开常量：" + "、".join(info["constants"]) + "。")
    for note in file_docs.get("notes", []):
        rows.append("## 注意：" + note.rstrip("。") + "。")
    rows.append(END)
    return "\n".join(rows) + "\n\n"


def with_header(path, source):
    descriptions = json.loads(CATALOG.read_text("utf-8"))
    body = strip_header(source)
    return header(descriptions[Path(path).name], body, path) + body


def validate_overrides(files):
    api = json.loads(API_CATALOG.read_text("utf-8"))
    by_name = {path.name: path for path in files}
    for name, file_docs in api["files"].items():
        assert name in by_name, "Stale API documentation: " + name
        declared = {method["name"]: method for method in interfaces(by_name[name].read_text("utf-8-sig"))["methods"]}
        for name_value, method_docs in file_docs.get("methods", {}).items():
            assert name_value in declared, (name, name_value)
            parameters = {parameter["name"] for parameter in declared[name_value]["parameters"]}
            assert set(method_docs.get("parameters", {})) <= parameters, (name, name_value)


def synchronize(check=False):
    descriptions = json.loads(CATALOG.read_text("utf-8"))
    files = sources()
    names = [path.name for path in files]
    validate_overrides(files)
    assert len(names) == len(set(names)), "Use distinct script basenames for the description catalog."
    assert set(names) == set(descriptions), (set(names) - descriptions.keys(), descriptions.keys() - set(names))
    changed = []
    for path in files:
        description = descriptions[path.name]
        assert description.endswith("。") and "\n" not in description, path
        source = path.read_text("utf-8-sig")
        expected = with_header(path.relative_to(REPO).as_posix(), source)
        if source != expected:
            changed.append(path.relative_to(REPO).as_posix())
            if not check:
                path.write_text(expected, "utf-8")
        if path.is_relative_to(REPO / "templates/editor") or path.is_relative_to(REPO / "tests/editor"):
            assert path.name.startswith("Editor_"), path
    assert not check or not changed, "Missing/stale script headers: " + ", ".join(changed)
    print(f"Script headers and editor prefix: PASSED / {len(files)} scripts / {len(changed)} updated")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    synchronize(parser.parse_args().check)
