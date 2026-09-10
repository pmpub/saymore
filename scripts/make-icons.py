#!/usr/bin/env python3
"""Generate the app icon set and the menu bar template icon (Baskerville S, Typeless-style light tile).
Run from repo root:  python3 scripts/make-icons.py
Requires Pillow:      pip3 install pillow
"""
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageFont
import os
FONT="/System/Library/Fonts/Supplemental/Baskerville.ttc"   # index 1 = Bold, 4 = SemiBold
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPICON=os.path.join(ROOT,"VoiceInk/Assets.xcassets/AppIcon.appiconset")
MENUBAR=os.path.join(ROOT,"VoiceInk/Assets.xcassets/menuBarIcon.imageset/menuBarIcon.png")
K=4; S=1024*K

def glyph(index, target_h, canvas):
    f=ImageFont.truetype(FONT,2000,index=index)
    l,t,r,b=f.getbbox("S"); w,h=r-l,b-t
    tmp=Image.new("L",(w+40,h+40),0); ImageDraw.Draw(tmp).text((20-l,20-t),"S",font=f,fill=255)
    sc=target_h/h; g=tmp.resize((int(tmp.width*sc),int(tmp.height*sc)),Image.LANCZOS)
    m=Image.new("L",(canvas,canvas),0); m.paste(g,((canvas-g.width)//2,(canvas-g.height)//2)); return m

def app_icon():
    g=glyph(1, 600*K, S)
    bg=Image.new("RGBA",(S,S),(0,0,0,0))
    grad=Image.new("RGBA",(S,S)); gd=ImageDraw.Draw(grad)
    for y in range(S):
        t=y/S; gd.line([(0,y),(S,y)],fill=(int(255-22*t),int(255-22*t),int(255-19*t),255))
    mask=Image.new("L",(S,S),0); ImageDraw.Draw(mask).rounded_rectangle([100*K,100*K,924*K,924*K],radius=184*K,fill=255)
    bg.paste(grad,(0,0),mask)
    border=Image.new("L",(S,S),0); ImageDraw.Draw(border).rounded_rectangle([100*K,100*K,924*K,924*K],radius=184*K,outline=255,width=int(2.5*K))
    bg.paste(Image.new("RGBA",(S,S),(0,0,0,26)),(0,0),border)
    sh=g.filter(ImageFilter.GaussianBlur(10*K)); shl=Image.new("RGBA",(S,S),(0,0,0,0)); shl.putalpha(sh.point(lambda v:int(v*0.35))); bg.alpha_composite(shl,(0,int(8*K)))
    ink=Image.new("RGBA",(S,S)); idr=ImageDraw.Draw(ink)
    for y in range(S):
        t=y/S; idr.line([(0,y),(S,y)],fill=(int(46-32*t),)*3+(255,))
    body=Image.new("RGBA",(S,S),(0,0,0,0)); body.paste(ink,(0,0),g); bg.alpha_composite(body)
    shift=g.transform(g.size,Image.AFFINE,(1,0,-3*K,0,1,-5*K))
    rim=ImageChops.subtract(g,shift).filter(ImageFilter.GaussianBlur(2.5*K))
    hl=Image.new("RGBA",(S,S),(255,255,255,0)); hl.putalpha(rim.point(lambda v:int(v*0.55))); bg.alpha_composite(hl)
    base=bg.resize((1024,1024),Image.LANCZOS)
    for n in (16,32,64,128,256,512,1024):
        (base if n==1024 else base.resize((n,n),Image.LANCZOS)).save(os.path.join(APPICON,f"{n}-mac.png"))
    print("app icon set written")

def menu_bar_icon():
    C=750; m=glyph(4, int(C*0.62), C)
    tpl=Image.new("RGBA",(C,C),(0,0,0,0)); tpl.paste(Image.new("RGBA",(C,C),(0,0,0,255)),(0,0),m); tpl.save(MENUBAR)
    print("menu bar template written")

if __name__=="__main__":
    app_icon(); menu_bar_icon()
