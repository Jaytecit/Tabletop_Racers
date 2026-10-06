"""Make labelled contact sheets of saved source crops or actual rendered frames."""
import argparse
from pathlib import Path
from PIL import Image,ImageDraw

parser=argparse.ArgumentParser()
parser.add_argument('directory')
parser.add_argument('--rendered',action='store_true')
parser.add_argument('--gates',action='store_true')
args=parser.parse_args()
directory=Path(args.directory)
files=sorted(directory.glob('gate_*.jpg' if args.gates else 'section_*.jpg' if args.rendered else '[0-9][0-9][0-9].png'))
assert files,'No saved review frames'
for start in range(0,len(files),30):
    sheet=Image.new('RGB',(1600,650) if args.gates else (1200,1440))
    for index,file in enumerate(files[start:start+30]):
        im=Image.open(file);im.thumbnail((392,292) if args.gates else (232,212))
        x,y=(index%4*400,index//4*325) if args.gates else (index%5*240,index//5*240)
        sheet.paste(im,(x,y+25));ImageDraw.Draw(sheet).text((x+5,y+5),file.stem,fill='yellow')
    sheet.save(directory/('gates_review.png' if args.gates else f'review_{start//30}.png'))
