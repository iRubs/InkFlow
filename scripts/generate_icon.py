from pathlib import Path
from PIL import Image, ImageDraw
root=Path(__file__).resolve().parents[1]
# Marca original construida con geometría: hoja, tinta y punta de lápiz.
im=Image.new('RGBA',(512,512),(0,0,0,0));d=ImageDraw.Draw(im)
d.rounded_rectangle((12,12,500,500),radius=116,fill='#1E40AF')
d.rounded_rectangle((108,92,362,424),radius=30,fill='#F8FAFC')
for y in [168,222,276,330]:d.rounded_rectangle((146,y,290,y+10),radius=5,fill='#BFDBFE')
d.polygon([(225,343),(274,367),(405,152),(355,125)],fill='#38BDF8')
d.polygon([(225,343),(218,394),(274,367)],fill='#0F172A')
d.polygon([(355,125),(405,152),(420,127),(370,99)],fill='#0F172A')
for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
 im.resize((size,size),Image.Resampling.LANCZOS).save(root/f'app/android/app/src/main/res/mipmap-{density}/ic_launcher.png')
im.save(root/'app/windows/runner/resources/app_icon.ico',sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])
im.save(root/'assets/inkflow-icon.png')
