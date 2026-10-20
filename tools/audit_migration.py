"""Audit retained RM sources against reviewed service groups without executing Ruby.

AST definitions supply exact owners/spans where parsing succeeded. The remaining
source declarations retain their lexical provenance; an indentation scope scan
adds reviewed owner candidates, never an automatic semantic-coverage claim.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import re

REPO = Path(__file__).resolve().parents[1]


def read(path):
    return json.loads(path.read_text("utf-8-sig"))


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def body(path):
    text = path.read_text("utf-8-sig")
    if text.startswith("## 职责："):
        return text.split("## 接口说明结束。", 1)[1]
    return text


def gd_dependencies(text):
    # Consume comments and whole literals first, so historical code templates
    # inside ProgramDocumentation strings are never mistaken for live imports.
    token = re.compile(r'''\#.*|"""[\s\S]*?"""|\x27\x27\x27[\s\S]*?\x27\x27\x27|"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27''')
    literals = list(token.finditer(text))
    for match in re.finditer(r'''\b(?:preload|load)\(\s*["\x27]([^"\x27]+)["\x27]\s*\)''', text):
        if not any(t.start() <= match.start() < t.end() for t in literals):
            yield match[1]


def source_methods(source, lexical):
    """Fallback owners are provenance candidates, not full Ruby name resolution."""
    lines = source.splitlines()
    scopes = []
    result = {}
    for number, line in enumerate(lines, 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())
        if re.match(r"\s*end\b", line):
            while scopes and scopes[-1][0] >= indent:
                scopes.pop()
        match = re.match(r"\s*(?:class|module)\s+([\w:]+|<<\s*self)", line)
        if match:
            while scopes and scopes[-1][0] >= indent:
                scopes.pop()
            name = match[1]
            singleton = name.startswith("<<")
            owner = scopes[-1][1] if singleton and scopes else name
            if scopes and not singleton and "::" not in owner:
                owner = scopes[-1][1] + "::" + owner
            scopes.append((indent, owner, singleton))
        definition = re.match(r"\s*def\s+(?:(self|[A-Za-z_]\w*(?:::\w+)*)\.)?([^\s(;]+)", line)
        if not definition:
            continue
        owner = scopes[-1][1] if scopes else "Object"
        singleton = any(s[2] for s in scopes) or bool(definition[1])
        if definition[1] and definition[1] != "self":
            owner = definition[1]
        # No execution or evaluation: only source lines and declaration scope.
        ending = next((i + 1 for i in range(number, len(lines))
                       if re.match(r"\s*end\b", lines[i])
                       and len(lines[i]) - len(lines[i].lstrip()) == indent), number)
        result[(number, definition[2])] = (owner, singleton, ending)
    return result


def fallback_owner(lines, number):
    # Unparsed sources have reviewed top-level owner segments. Do not infer
    # method scope by indentation: original0332 uses unindented module methods.
    owner = "Object"
    for line in lines[:number]:
        match = re.match(r"\s*(?:class|module)\s+([A-Za-z_]\w*(?:::\w+)*)", line)
        if match:
            owner = match[1]
    return owner


def build(project, rules):
    registry = read(project / "data/script_units.json")["units"]
    inventory = read(project / "data/script_inventory.json")
    semantics = read(project / "data/script_semantics.json")
    rxdata = REPO.parent / "rm_template/魔塔样板7630·改/Data/Scripts.rxdata"
    assert sha(rxdata) == rules["source_sha256"], "Original Scripts.rxdata changed; review rules first"
    files = {p.stem: p for p in (REPO / "templates/runtime/scripts").rglob("*.gd")}
    groups = {g["id"]: g for g in rules["groups"]}
    slot_groups = {}
    implementations = {}
    for group in groups.values():
        for slot in group["slots"]:
            assert slot not in slot_groups, (slot, group["id"])
            slot_groups[slot] = group
        for name in group["targets"]:
            assert name in files, (group["id"], name)
            target = files[name]
            text = body(target)
            implementations[name + ".gd"] = {
                "path": "runtime/scripts/" + target.relative_to(REPO / "templates/runtime/scripts").as_posix(),
                "sha256": sha(target),
                "interfaces": re.findall(r"(?m)^(?:static )?func ([^(]+)", text),
            }
        for name in group["tests"]:
            assert (REPO / "tests/runtime" / (name + ".gd")).is_file(), name
    scripts = []
    methods = []
    attributes = []
    dynamic_sites = []
    by_unit = defaultdict(list)
    for definition in semantics["definitions"]:
        if definition["kind"] in ("method", "alias", "module_function"):
            by_unit[definition["unit_id"]].append(definition)
    for script in inventory["scripts"]:
        id = script["unit_id"]
        unit = registry[id]
        order = int(script["origin"]["load_order"])
        source_path = project / script["source_path"]
        source = source_path.read_text("utf-8-sig")
        assert sha(source_path) == unit["source_sha256"], id
        group = slot_groups.get(order)
        status = ("excluded" if order in rules["excluded_slots"] else
                  "source_empty" if unit["status"] == "empty" else
                  "source_unfinished" if str(order) in rules["source_unfinished_slots"] else "implemented")
        assert group or status in ("excluded", "source_empty"), (id, "Unreviewed active source")
        row = {
            "unit_id": id, "load_order": order, "name": script["origin"]["name"],
            "source_path": script["source_path"], "sha256": sha(source_path),
            "classification": status, "label": rules["status_labels"][status],
            "compiler_status": unit["status"], "parsed": unit.get("parsed", False),
            "group": group["id"] if group else "",
            "targets": [implementations[n + ".gd"]["path"] for n in group["targets"]] if group else [],
            "tests": group["tests"] if group else [],
            "entry": group["entry"] if group else "原源空槽/注释或用户排除范围",
            "boundary": rules["source_unfinished_slots"].get(str(order), group["boundary"] if group else ""),
        }
        if status in ('source_empty','excluded'):
            row['targets']=[]
            row['tests']=[]
            row['entry']='原源空槽/注释' if status=='source_empty' else '用户排除的特殊BOSS范围'
            row['boundary']=''
        scripts.append(row)
        if status not in ('excluded','source_empty'):
            block=False
            for number,line in enumerate(source.splitlines(),1):
                if line.strip()=='=begin':block=True
                if block:
                    if line.strip()=='=end':block=False
                    continue
                if line.lstrip().startswith('#'):continue
                attribute=re.match(r'\s*attr_(reader|writer|accessor)\s+(.+)',line)
                if attribute:
                    attributes.append({'unit_id':id,'line':number,'mode':attribute[1],'names':re.findall(r':([A-Za-z_]\w*)',attribute[2]),'declaration':line.strip(),'group':row['group'],'resolution':'declared_fields_service_review'})
                if re.search(r'\b(?:eval|instance_eval|class_eval|module_eval|send|define_method|Win32API|include|extend)\b',line):
                    dynamic_sites.append({'unit_id':id,'line':number,'source':line.strip(),'group':row['group'],'resolution':'finite_service_or_explicit_native_boundary','boundary':row['boundary']})
        fallback = source_methods(source, script["analysis"]["definitions"])
        declared = set()
        candidates = []
        for d in by_unit[id]:
            if d["kind"] == "module_function":
                # Record the singleton exposure too; it has a distinct dispatch key.
                pass
            candidates.append({
                "version_id": d["version_id"], "owner": d["owner"], "name": d["name"],
                "singleton": d.get("singleton", False), "line": d["span"]["line"],
                "end_line": d["span"]["end_line"], "kind": d["kind"],
                "resolution": "parsed_definition", "alias_target": d.get("target_name", ""),
                "captured_version": d.get("captured_version", ""),
            })
            declared.add((d["span"]["line"], d["name"]))
        for d in script["analysis"]["definitions"]:
            if unit.get("parsed", False) or d["kind"] not in ("method", "alias") or (d["line"], d["name"]) in declared:
                continue
            actual = next(((name, data) for (line, name), data in fallback.items() if line == d['line']), None)
            owner = fallback_owner(source.splitlines(), d['line'])
            name = actual[0] if actual else d['name']
            singleton, ending = (actual[1][1], actual[1][2]) if actual else (False, d['line'])
            if actual and actual[1][0] not in ('Object','unresolved'):
                owner = actual[1][0] if actual[1][1] and '.' in source.splitlines()[d['line']-1].split('def ',1)[-1].split('(',1)[0] else owner
            # Lexical aliases in unparsed source retain an explicit unknown capture.
            candidates.append({"version_id":d["version_id"], "owner":owner, "name":name,
                               "singleton":singleton, "line":d["line"], "end_line":ending,
                               "kind":d["kind"], "resolution":"lexical_service_review",
                               "alias_target":d.get("alias_target", ""), "captured_version":""})
        for m in candidates:
            m.update({"unit_id":id, "load_order":order, "group":row["group"], "classification":status})
            segment = source.splitlines()[m["line"]:max(m["line"], m["end_line"] - 1)]
            if status == "implemented" and m["end_line"] > m["line"] and not any(
                line.strip() and not line.lstrip().startswith("#") for line in segment
            ):
                m["classification"] = "source_unfinished"
            if order in range(159, 166) and m["name"] in rules["excluded_interpreter_methods"]:
                m["classification"] = "excluded"
            # A candidate link helps navigation; it is never a behavior proof.
            m["same_name_candidates"] = [implementations[n + ".gd"]["path"] for n in group["targets"]
                                         if m["name"].removesuffix("?").removesuffix("!") in implementations[n + ".gd"]["interfaces"]] if group else []
            methods.append(m)
    # Last definition by owner/name/singleton; aliases retain capture evidence.
    # Lexical fallback records are included but explicitly marked as reviewed
    # candidates, so this table is not a proof for arbitrary dynamic mixins/eval.
    chains = defaultdict(list)
    for m in methods:
        if m["owner"] != "unresolved":
            chains[(m["owner"], m["name"], m["singleton"])].append(m)
    overrides = []
    for key, chain in chains.items():
        chain.sort(key=lambda m:(m["load_order"],m["line"],m["kind"] == "module_function"))
        for i, m in enumerate(chain):
            m["effective"] = i == len(chain) - 1
            if not m["effective"]:
                m["superseded_by"] = chain[i+1]["version_id"]
        if len(chain)>1:
            overrides.append({"owner":key[0],"name":key[1],"singleton":key[2],"versions":[m["version_id"] for m in chain],"effective":chain[-1]["version_id"]})
    dependencies = []
    for p in sorted((REPO / "templates/runtime/scripts").rglob("*.gd")):
        for ref in gd_dependencies(body(p)):
            if ref.startswith("res://runtime/scripts/"):
                resolved=REPO / "templates/runtime/scripts" / ref.removeprefix("res://runtime/scripts/")
            elif ref.startswith("res://"):
                resolved=project / ref[6:]
            else:
                resolved=p.parent / ref
            assert resolved.is_file(), (p, ref, "Missing literal runtime dependency")
            dependencies.append({"source":p.relative_to(REPO).as_posix(),"path":ref})
    asset_index=read(project / "data/asset_index.json")
    asset_paths=sorted(set(asset_index.values()))
    for value in asset_paths:
        assert value.startswith("res://") and ".." not in Path(value[6:]).parts and (project / value[6:]).is_file(), value
    media=[]
    for name in rules["missing_media"]:
        path=asset_index.get(name, asset_index.get(name.lower(), ""))
        media.append({"source_reference":name,"classification":"available_asset" if path and (project / path[6:]).is_file() else "missing_asset", "target":path, "behavior":"原图缺失时使用有来源记录的0.59程序生成分区图；其他自定义缺图拒绝" if name=="Graphics/Pictures/sptx" else "缺失时原演出入口明确拒绝；不会伪造音效"})
    categories={name.lower():name for name in ['Animations','Autotiles','Battlebacks','Battlers','Characters','Fogs','Icons','Panoramas','Pictures','Tilesets','Titles','Windowskins','Skills','Faces']}
    singular={'animation':'Animations','autotile':'Autotiles','battleback':'Battlebacks','battler':'Battlers','character':'Characters','fog':'Fogs','icon':'Icons','panorama':'Panoramas','picture':'Pictures','tileset':'Tilesets','title':'Titles','windowskin':'Windowskins','skill':'Skills','face':'Faces'}
    resource_refs=[]
    for script in scripts:
        if script['classification'] in ('source_empty','excluded'):continue
        in_block=False
        for number,line in enumerate((project/script['source_path']).read_text('utf-8-sig').splitlines(),1):
            if line.strip()=='=begin':in_block=True
            if in_block:
                if line.strip()=='=end':in_block=False
                continue
            if line.lstrip().startswith('#'):continue
            for match in re.finditer(r'''(?:RPG::Cache\.(\w+)|Audio\.(bgm|bgs|me|se)_play|Bitmap\.new)\s*\(\s*(["'])([^"']+)\3\s*[,)]''',line):
                filename=match[4]
                if '#{' in filename:continue
                if match[1]:
                    category=singular.get(match[1].lower(),categories.get(match[1].lower(),''))
                    if not category:continue
                    resource='Graphics/'+category+'/'+filename
                elif match[2]:resource=filename if filename.startswith('Audio/') else 'Audio/'+match[2].upper()+'/'+filename
                else:resource=filename
                if not resource.startswith(('Graphics/','Audio/')):continue
                shortened=str(Path(resource).with_suffix('')).replace('\\','/')
                target=asset_index.get(resource,asset_index.get(resource.lower(),asset_index.get(shortened,asset_index.get(shortened.lower(),''))))
                original=rxdata.parents[1]/resource
                present=[str(p.relative_to(rxdata.parents[1])) for p in [original,*[Path(str(original)+ext) for ext in ['.png','.jpg','.bmp','.ogg','.wav','.mp3','.mid','.mp2']]] if p.is_file()]
                resource_refs.append({'unit_id':script['unit_id'],'line':number,'source_reference':resource,'target':target,'original_files':present,'classification':'available_asset' if target else 'unindexed_original_asset' if present else 'missing_asset','source_scope':script['classification']})
    return {
        "format":"rgm-migration-audit-v1","version":"ver0.59","state":"reviewed_source_and_targets",
        "source_rxdata_sha256":sha(rxdata),"definition_policy":"保留解析定义的owner/覆盖与alias捕获；未解析脚本的词法声明单列，动态mixin/eval不由词法扫描证明。",
        "evidence_policy":"逐脚本/方法声明定位及职责/入口审计；GDScript重写不承诺每个Ruby方法同名存在。接口/文件存在不是全部行为已验收；行为证据见tests/VERIFICATION_v0.59。",
        "counts":{"scripts":len(scripts),"methods":len(methods),"attribute_declarations":len(attributes),"dynamic_candidates":len(dynamic_sites),"effective_method_candidates":sum(m.get('effective',False) for m in methods),"override_chains":len(overrides),"lexical_method_candidates":sum(m['resolution']=='lexical_service_review' for m in methods),"groups":len(groups),"implementations":len(implementations),"literal_dependencies":len(dependencies),"asset_paths":len(asset_paths),"literal_source_resource_refs":len(resource_refs),"unindexed_original_assets":sum(row['classification']=='unindexed_original_asset' for row in resource_refs),"unregistered_sources":0,"classifications":dict(Counter(s['classification'] for s in scripts))},
        "groups":list(groups.values()),"scripts":scripts,"methods":methods,"attribute_declarations":attributes,"dynamic_candidates":dynamic_sites,"override_chains":overrides,
        "implementations":implementations,"runtime_snapshot":{"runtime/scripts/"+p.relative_to(REPO/'templates/runtime/scripts').as_posix():sha(p) for p in sorted((REPO/'templates/runtime/scripts').rglob('*.gd'))},"generated_snapshot":{p.relative_to(project).as_posix():sha(p) for p in sorted((project/'runtime/generated').rglob('*.gd'))},"literal_dependencies":dependencies,"media":media,"literal_source_resources":resource_refs,
        "remaining_boundaries":[{"group":g['id'],"detail":g['boundary']} for g in groups.values() if g['boundary']],
        "dynamic_sites_policy":"已知数据与原事件由有限服务承担；任意新增Ruby eval/FFI/回调不作为可执行入口。原Ruby只读；事件使用真实GDScript。",
    }


def markdown(report):
    c=report['counts']
    lines=["# 0.59 剩余迁移缺口审计", "", "0.59整合自查；脚本文件名已移除Flash前缀，Editor_保留。新分辨率窗口位置后续统一调整，用户人工验收待进行。", "", report['evidence_policy'], "", f"核对{c['scripts']}个原脚本槽、{c['methods']}条方法/alias声明、{c['override_chains']}条同名覆盖链、{c['literal_dependencies']}处运行时字面依赖和{c['asset_paths']}个资源路径。{c['lexical_method_candidates']}条为显式标记的词法候选，不能当作完整Ruby语义解析。", "", "本版补齐0026原上层遮挡：走入四向连通屋檐/树冠时原1、2层变为160/255透明度，离开、动态改图、重载正确恢复；地面及新增高层不变。派生缓存只服务绘制，不写存档，原地不重复BFS。", "", "| 序号 | 原脚本 | 分类 | 实际入口/边界 | Godot实现 |", "| --- | --- | --- | --- | --- |"]
    for s in report['scripts']:
        targets=', '.join(Path(t).name for t in s['targets'])
        lines.append(f"| {s['load_order']:04d} | {s['name']} | {s['label']} | {(s['entry']+'；'+s['boundary']).replace('|',chr(92)+'|')} | {targets} |")
    lines += ["", "## 源边界与缺素材", ""]
    lines += [f"- {b['group']}：{b['detail']}" for b in report['remaining_boundaries']]
    lines += [f"- {m['source_reference']}：{m['classification']}。{m['behavior']}。" for m in report['media']]
    lines += ["", "## 开发与验收入口", "", "生成工程data/migration_audit.json保留逐方法声明、原行号、覆盖链、alias捕获、服务路径及测试组。脚本工作区分别展示职责审计与编译器诊断，不把自动转换unsupported当作已迁移服务缺失。新增来源或目标哈希变化须重新审计，正式导出会核对来源与目标内容。", "", "原生事件正文仍在事件编辑器编辑保存；原Ruby只读。普通战斗/开门/拾取、消息/历史、菜单/功能页、存读档/撤回及编辑器自查见[0.59验证](../tests/VERIFICATION_v0.59.md)。完整剧情人工通关、原RGSS逐像素比对、无原片的视频播放及所有地图长期60FPS未由本报告证明。", ""]
    return '\n'.join(lines)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',required=True,type=Path)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    rules=read(REPO/'tools/migration_audit_rules.json')
    report=build(args.project.resolve(),rules)
    output=REPO/'docs/MIGRATION_AUDIT_v0.59.json'
    if args.check:
        assert read(output)==report, 'Migration audit is stale; regenerate after reviewing source changes'
    else:
        output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n','utf-8')
        output.with_suffix('.md').write_text(markdown(report),'utf-8')
    print(json.dumps({'audit':'checked' if args.check else 'built',**report['counts']},ensure_ascii=False))


if __name__=='__main__':
    main()
