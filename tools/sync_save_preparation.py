from pathlib import Path
import re,sys
repo=Path(__file__).resolve().parents[1]
source=(repo/'templates/runtime/scripts/SaveCodec.gd').read_text('utf-8-sig')
start=source.index('static func prepare(');start=source.index('\n',start)+1
end=source.index('\n\nstatic func testing_records',start)
body=source[start:end].rstrip()
body=body.replace('Graph.reason(value,captured_classes)','(await graph_check.call(value,captured_classes)) if graph_check.is_valid() else (await Graph.reason_cooperatively(value,pulse,captured_classes))')
body=re.sub(r'Graph\.reason\(([^()]*)\)',r'(await Graph.reason_cooperatively(\1,pulse))',body)
body=body.replace('preload("ScriptRuntime.gd").validate_saved_objects(saved,script_data.get("classes",{"Object":{"parent":"","kind":"class"}}))','(await Graph.reason_cooperatively(saved,pulse,script_data.get("classes",{"Object":{"parent":"","kind":"class"}})))')
lines=[]
for line in body.splitlines():
    if line.startswith('\t') and not line.startswith('\t\t') and line.strip() and not line.lstrip().startswith(('#','elif ','else:')):
        lines.append('\tif not await pulse.call(): return fail("事件前记录已取消。")')
    lines.append(line)
    if line.lstrip().startswith('for ') and line.rstrip().endswith(':'):
        indent=line[:len(line)-len(line.lstrip())]+'\t'
        lines.append(indent+'if not await pulse.call(): return fail("事件前记录已取消。")')
result='extends "SaveCodec.gd"\n## Generated from SaveCodec.prepare by tools/sync_save_preparation.py.\n## Schema validation stays on the main thread; a detached graph checker may run\n## the same bounded graph/class validation on a worker before schema restoration.\nstatic func prepare_cooperatively(value: Variant,definitions: RefCounted,owned_snapshot: bool,pulse: Callable,graph_check: Callable=Callable()) -> Dictionary:\n'+'\n'.join(lines)+'\n'
target=repo/'templates/runtime/scripts/SavePreparation.gd'
if '--check' in sys.argv:
    assert target.read_text('utf-8')==result,'Regenerate SavePreparation.gd from the canonical synchronous validator.'
else:target.write_text(result,'utf-8')
print('SavePreparation canonical parity: PASSED')
