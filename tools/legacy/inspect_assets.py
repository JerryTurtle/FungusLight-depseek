from PIL import Image, ImageDraw
from pathlib import Path
import json
root=Path(__file__).resolve().parents[2]
out=root/'策划输出'
out.mkdir(exist_ok=True)
files=list((root/'Fungus Cave [16x16]').rglob('*.png'))
records=[]
for p in files:
 im=Image.open(p)
 records.append({'file':str(p.relative_to(root)),'width':im.width,'height':im.height,'mode':im.mode})
(out/'素材清单.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
for folder in ['Characters','Battlers','Tilesets']:
 selected=[p for p in files if p.parent.name==folder and (folder!='Tilesets' or '16x16' in p.name)]
 w=1000; cellw=250; cellh=260 if folder!='Tilesets' else 650
 sheet=Image.new('RGB',(w,((len(selected)+3)//4)*cellh),'#252933'); d=ImageDraw.Draw(sheet)
 for i,p in enumerate(selected):
  im=Image.open(p).convert('RGBA'); im.thumbnail((240,cellh-40),Image.Resampling.NEAREST)
  x=(i%4)*cellw;y=(i//4)*cellh
  sheet.paste(im,(x+(240-im.width)//2,y+30),im)
  d.text((x+5,y+5),p.name,fill='white')
 sheet.save(out/(folder+'.png'))
