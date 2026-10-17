from pathlib import Path
from PIL import Image, ImageDraw
import json

root=Path(__file__).resolve().parents[2]
base=root/'Fungus Cave [16x16]'
out=root/'策划输出'
def equal(a,b):
 return a.size==b.size and a.convert('RGBA').tobytes()==b.convert('RGBA').tobytes()
def visible_equal(a,b):
 if a.size!=b.size:return False
 return all(pa[3]==pb[3] and (pa[3]==0 or pa[:3]==pb[:3]) for pa,pb in zip(a.convert('RGBA').getdata(),b.convert('RGBA').getdata()))
report={'character_frames':{},'battler_x2':{},'tileset_scaling':{},'atlas_matches':{}}
report['battler_x2_visible']={}
report['tileset_scaling_visible']={}
for p in (base/'Battlers').glob('*.png'):
 a=Image.open(p).convert('RGBA'); b=Image.open(base/'Battlers x2 size'/p.name).convert('RGBA')
 report['battler_x2'][p.name]=equal(a.resize(b.size,Image.Resampling.NEAREST),b)
 report['battler_x2_visible'][p.name]=visible_equal(a.resize(b.size,Image.Resampling.NEAREST),b)
for p in (base/'Tilesets').glob('*16x16.png'):
 a=Image.open(p).convert('RGBA')
 for n in [2,3]:
  b=Image.open(p.with_name(p.name.replace('16x16',f'{16*n}x{16*n}'))).convert('RGBA')
  report['tileset_scaling'][b.filename if hasattr(b,'filename') else p.name+f' x{n}']=equal(a.resize(b.size,Image.Resampling.NEAREST),b)
  report['tileset_scaling_visible'][p.name+f' x{n}']=visible_equal(a.resize(b.size,Image.Resampling.NEAREST),b)
full=Image.open(base/'Tilesets/Tileset - Complete 16x16.png').convert('RGBA')
cave=Image.open(base/'Tilesets/Tileset - Fungus cave and Refugee outpost 16x16.png').convert('RGBA')
sewer=Image.open(base/'Tilesets/Tileset - Sewers 16x16.png').convert('RGBA')
report['complete_is_concatenation']=equal(full.crop((0,0,128,560)),cave) and equal(full.crop((0,560,128,736)),sewer)
report['complete_visibly_concatenated']=visible_equal(full.crop((0,0,128,560)),cave) and visible_equal(full.crop((0,560,128,736)),sewer)
atlas=Image.open(base/'Characters/Characters.png').convert('RGBA')
extra=atlas.crop((240,0,288,128)); extra.resize((192,512),Image.Resampling.NEAREST).save(out/'图集额外角色_复核.png')
report['extra_atlas_character_matches_cleric']=visible_equal(extra,atlas.crop((192,0,240,128)))
report['unused_atlas_cell_alpha_bbox']=extra.getchannel('A').getbbox()
for p in (base/'Characters').glob('*.png'):
 if p.name=='Characters.png':continue
 im=Image.open(p).convert('RGBA')
 report['character_frames'][p.name]=[im.crop((c*16,r*32,(c+1)*16,(r+1)*32)).getchannel('A').getbbox() for r in range(4) for c in range(3)]
 report['atlas_matches'][p.name]=[(x,y) for y in range(0,256,128) for x in range(0,288,48) if equal(im,atlas.crop((x,y,x+48,y+128)))]
 if p.name in ['Cleric.png','Fungus - red.png','Sewers monster.png']:
  sheet=Image.new('RGB',(440,620),'#262a35'); draw=ImageDraw.Draw(sheet)
  for r in range(4):
   draw.text((8,r*150+10),f'row {r}',fill='white')
   for c in range(3):
    frame=im.crop((c*16,r*32,(c+1)*16,(r+1)*32)).resize((64,128),Image.Resampling.NEAREST)
    sheet.paste(frame,(110+c*100,r*150),frame)
  sheet.save(out/(p.stem+'_逐帧复核.png'))
(out/'素材复核_V3.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('Battler x2 exact:',sum(report['battler_x2'].values()),'/29; differing:',[k for k,v in report['battler_x2'].items() if not v])
print('Tilesets:',report['tileset_scaling'])
print('Complete concatenation:',report['complete_is_concatenation'])
print('Atlas matches:',report['atlas_matches'])
print('Cleric frame bounds:',report['character_frames']['Cleric.png'])
print('Visible x2 exact:',sum(report['battler_x2_visible'].values()),'differing:',[k for k,v in report['battler_x2_visible'].items() if not v])
print('Visible tileset scaling:',report['tileset_scaling_visible'])
print('Visible concat:',report['complete_visibly_concatenated'])
