"""Reuse matching disposable asset imports after a fresh formal migration."""
from pathlib import Path
import argparse, hashlib, shutil
p=argparse.ArgumentParser(); p.add_argument('stage',choices=['first','delivery','verified','release']); p.add_argument('--project'); args=p.parse_args()
workspace=Path(__file__).resolve().parents[2]
previous=workspace/'output/0.43/delivery'
destination=workspace/'output/0.44'/args.stage
assert destination.resolve().parent==workspace/'output/0.44'
for new in destination.iterdir():
    if not new.is_dir(): continue
    if args.project and new.name!=args.project: continue
    old=previous/new.name
    assert (new/'project.godot').is_file()
    count=0
    for sidecar in (old/'assets').rglob('*.import'):
        source=sidecar.with_suffix(''); target=new/sidecar.relative_to(old)
        asset=target.with_suffix('')
        if asset.is_file() and hashlib.sha256(source.read_bytes()).digest()==hashlib.sha256(asset.read_bytes()).digest():
            shutil.copy2(sidecar,target); count+=1
    cache=new/'.godot/imported'; cache.mkdir(parents=True,exist_ok=True)
    for file in (old/'.godot/imported').iterdir():
        if file.is_file(): shutil.copy2(file,cache/file.name)
    print(new.name, 'matching asset imports:',count)
