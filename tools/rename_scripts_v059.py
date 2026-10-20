"""Apply the reviewed 0.59 filename migration once, preserving historical reports."""
from pathlib import Path
import argparse,json,re

ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply',action='store_true')
    args=parser.parse_args()
    sources=[p for folder in ['scripts','templates','tests'] for p in (ROOT/folder).rglob('Flash*.gd')]
    exceptions={'FlashActorState':'Game_ActorState','FlashPresentationTests':'GamePresentationTests','FlashSaveRestartTests':'GameSaveRestartTests'}
    records=[]
    for p in sorted(sources):
        q=p.with_name(exceptions.get(p.stem,p.stem[5:])+'.gd')
        assert not q.exists(),q
        records.append({'old':p.relative_to(ROOT).as_posix(),'new':q.relative_to(ROOT).as_posix()})
    names={Path(x['old']).stem:Path(x['new']).stem for x in records}
    assert len(names)==len(records)
    if not args.apply:
        print(json.dumps(records,ensure_ascii=False,indent=2));return
    assert sources and (ROOT/'.godot/test-logs/v059-source-before.zip').is_file()
    target=ROOT/'tools/script_renames_v059.json';assert not target.exists()
    pattern=re.compile(r'\b('+'|'.join(sorted(names,key=len,reverse=True))+r')\b')
    for folder in ['scripts','templates','tests','tools']:
        for p in (ROOT/folder).rglob('*'):
            if not p.is_file() or p==Path(__file__).resolve() or p.suffix not in ['.gd','.py','.ps1','.json','.tscn','.cfg']:continue
            # Raw replacement preserves CRLF, historical import/header byte aliases,
            # and all unrelated text. Existing published evidence stays unchanged.
            if p.name.startswith('VERIFICATION_') or p.parent.name=='verification':continue
            raw=p.read_bytes();s=raw.decode('utf-8-sig')
            changed=pattern.sub(lambda m:names[m[0]],s)
            if changed!=s:p.write_bytes((b'\xef\xbb\xbf' if raw.startswith(b'\xef\xbb\xbf') else b'')+changed.encode('utf-8'))
    for row in records:
        p=ROOT/row['old'];q=ROOT/row['new'];p.rename(q)
        if p.with_suffix('.gd.uid').exists():p.with_suffix('.gd.uid').rename(q.with_suffix('.gd.uid'))
    value={'version':'0.59','policy':'Current filenames omit Flash; old symbols remain navigation aliases, no duplicate runtime scripts. Original RM and published verification reports remain unchanged.','files':records}
    target.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n','utf-8')
    print(f'Renamed {len(records)} maintained scripts; reference and metadata replacements applied.')

if __name__=='__main__':main()
