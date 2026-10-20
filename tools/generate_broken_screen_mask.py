"""Create a deterministic, flat-label Voronoi mask for the original480px effect.

This is a new project asset, not a recovered RM original. No external packages
or image model are needed: pixel labels must remain exact, without antialiasing.
"""
from pathlib import Path
import argparse,hashlib,json,struct,zlib

ROOT=Path(__file__).resolve().parents[1]

def image_bytes():
    seeds=[]
    for y in range(6):
        for x in range(6):
            i=y*6+x
            seeds.append((x*80+20+(i*37+13)%41,y*80+20+(i*23+7)%41,8+i*7))
    raw=bytearray()
    for y in range(480):
        raw.append(0)
        for x in range(480):
            raw.append(min(seeds,key=lambda p:(x-p[0])**2+(y-p[1])**2)[2])
    def chunk(kind,body):
        return struct.pack('>I',len(body))+kind+body+struct.pack('>I',zlib.crc32(kind+body)&0xffffffff)
    png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',480,480,8,0,0,0,0))+chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b'')
    return png

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--check',action='store_true');args=ap.parse_args()
    target=ROOT/'templates/runtime/assets/broken_screen_mask.png';png=image_bytes()
    info={'format':'rgm-generated-effect-asset-v1','origin':'Generated in0.59; original Flash project lacks Graphics/Pictures/sptx.png. Not copied from another RM project.','algorithm':'6x6 deterministic jittered Voronoi cells;36 distinct opaque grayscale labels, no antialiasing.','size':[480,480],'sha256':hashlib.sha256(png).hexdigest(),'generator':'tools/generate_broken_screen_mask.py','usage':'Fallback only for missing default sptx/sptx.png; existing source texture always takes priority. Custom missing filenames still fail. Original480px crop/timing remains unchanged.'}
    metadata=target.with_name('broken_screen_mask.json')
    if args.check:
        assert target.read_bytes()==png and json.loads(metadata.read_text('utf-8'))==info
    else:
        target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(png);metadata.write_text(json.dumps(info,ensure_ascii=False,indent=2)+'\n','utf-8')
    print('Broken screen mask: '+('verified' if args.check else 'generated')+' /480x480 /36 labels /'+info['sha256'])

if __name__=='__main__':main()
