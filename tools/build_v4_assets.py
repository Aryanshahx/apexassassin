#!/usr/bin/env python3
"""Original v0.4 character parts, character cards, and 17 knife icons."""
from pathlib import Path
import cairosvg, math
ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "assets"; SRC = ROOT / "art_source"

PAL = {
 "sable":   dict(cloth="#3a3f4a", dark="#171a20", trim="#7fd7ff", scarf="#2b6f8f", mask="#e8e2d2", eye="#7fd7ff", skin="#b97a52"),
 "dash":    dict(cloth="#e8e8ea", dark="#5a616b", trim="#20c7c9", scarf="#20c7c9", mask="#f4f4f4", eye="#20c7c9", skin="#d9a074"),
 "sage":    dict(cloth="#6a4a8f", dark="#2a1745", trim="#ffd23f", scarf="#9a45ee", mask="#efe6ff", eye="#ffd23f", skin="#c98d62"),
 "fiesta":  dict(cloth="#e63946", dark="#5c1518", trim="#20c7c9", scarf="#ffd23f", mask="#f1ead8", eye="#ff7a1f", skin="#c98d62"),
 "aegis":   dict(cloth="#c9973f", dark="#5c3a20", trim="#1f6fb2", scarf="#1f6fb2", mask="#2b2f38", eye="#7fd7ff", skin="#d9a074"),
 "sentinel":dict(cloth="#5a6b32", dark="#2e3a18", trim="#d7a54a", scarf="#8a9a5b", mask="#2b2f38", eye="#ffd23f", skin="#c98d62"),
 "crimson": dict(cloth="#b3272d", dark="#3d0f12", trim="#e8e2d2", scarf="#e63946", mask="#f1ead8", eye="#ff5a6e", skin="#c98d62"),
 "oni":     dict(cloth="#6a3a9f", dark="#2a0a4a", trim="#20c7c9", scarf="#9a45ee", mask="#7fd7ff", eye="#20c7c9", skin="#9a6ad8"),
}

def svg(w,h,body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>'

def render(name, text, scale=3):
    p = SRC / f"{name}.svg"; p.parent.mkdir(parents=True, exist_ok=True); p.write_text(text)
    out = ART / f"{name}.png"; out.parent.mkdir(parents=True, exist_ok=True)
    cairosvg.svg2png(bytestring=text.encode(), write_to=str(out), scale=scale)

def parts(kind):
    c=PAL[kind]
    torso=svg(64,64,f'''<path d="M18 24 Q32 16 46 24 L48 46 Q32 54 16 46 Z" fill="{c['cloth']}" stroke="{c['dark']}" stroke-width="3"/>
    <path d="M22 26 Q32 22 42 26 L40 44 Q32 48 24 44 Z" fill="{c['dark']}" opacity="0.35"/>
    <path d="M20 28 L44 40" stroke="{c['trim']}" stroke-width="3" opacity="0.8"/>
    <rect x="27" y="36" width="10" height="7" rx="2" fill="{c['trim']}"/>''')
    head=svg(64,64,f'''<path d="M32 10 C18 10 14 24 16 34 C20 42 44 42 48 34 C50 24 46 10 32 10 Z" fill="{c['cloth']}" stroke="{c['dark']}" stroke-width="3"/>
    <path d="M22 26 Q32 20 42 26 L40 36 Q32 40 24 36 Z" fill="{c['mask']}"/>
    <path d="M24 27 L29 27 M35 27 L40 27" stroke="{c['eye']}" stroke-width="3" stroke-linecap="round"/>
    <path d="M32 12 L32 22" stroke="{c['trim']}" stroke-width="2" opacity="0.7"/>''')
    arm=svg(32,48,f'''<rect x="9" y="4" width="14" height="30" rx="7" fill="{c['cloth']}" stroke="{c['dark']}" stroke-width="3"/>
    <rect x="10" y="24" width="12" height="8" rx="3" fill="{c['trim']}"/>
    <circle cx="16" cy="37" r="6" fill="{c['skin']}" stroke="{c['dark']}" stroke-width="2"/>''')
    leg=svg(32,48,f'''<rect x="9" y="2" width="14" height="30" rx="7" fill="{c['dark']}"/>
    <rect x="8" y="28" width="16" height="14" rx="5" fill="{c['cloth']}" stroke="{c['dark']}" stroke-width="2"/>''')
    scarf=svg(48,64,f'''<path d="M20 4 Q30 18 22 34 Q16 48 26 60 L34 56 Q28 44 34 30 Q40 14 30 4 Z" fill="{c['scarf']}" stroke="{c['dark']}" stroke-width="2"/>''')
    blade=svg(32,64,f'''<rect x="13" y="38" width="6" height="18" rx="2" fill="{c['dark']}"/>
    <rect x="8" y="34" width="16" height="6" rx="2" fill="{c['trim']}"/>
    <path d="M16 2 Q24 18 20 34 L12 34 Q8 18 16 2 Z" fill="#dfe7ee" stroke="#5a6570" stroke-width="2"/>
    <path d="M16 6 L16 30" stroke="#ffffff" stroke-width="2" opacity="0.8"/>''')
    rifle=svg(32,72,f'''<rect x="12" y="4" width="8" height="44" rx="2" fill="#20242c" stroke="#0d0f13" stroke-width="2"/>
    <rect x="10" y="30" width="12" height="18" rx="3" fill="{c['trim']}"/>
    <rect x="14" y="0" width="4" height="10" fill="#0d0f13"/>
    <rect x="8" y="48" width="16" height="10" rx="3" fill="#3a2417"/>''')
    for n,t in [("torso",torso),("head",head),("arm",arm),("leg",leg),("scarf",scarf),("blade",blade),("rifle",rifle)]:
        render(f"characters/{kind}/{n}",t)
    card=svg(256,256,f'''<circle cx="128" cy="128" r="118" fill="{c['dark']}" opacity="0.25"/>
    <path d="M128 34 C82 34 66 82 74 122 C86 158 170 158 182 122 C190 82 174 34 128 34 Z" fill="{c['cloth']}" stroke="{c['dark']}" stroke-width="8"/>
    <path d="M92 108 Q128 86 164 108 L156 148 Q128 162 100 148 Z" fill="{c['mask']}"/>
    <path d="M100 112 L116 112 M140 112 L156 112" stroke="{c['eye']}" stroke-width="8" stroke-linecap="round"/>
    <path d="M86 160 Q128 190 170 160 L178 210 Q128 236 78 210 Z" fill="{c['scarf']}" stroke="{c['dark']}" stroke-width="6"/>
    <path d="M128 44 L128 84" stroke="{c['trim']}" stroke-width="6" opacity="0.8"/>''')
    # Card portraits are shipped as painted PNGs; do not overwrite them with the SVG fallback.
    if not (ART / f"home/card_{kind}.png").exists():
        render(f"home/card_{kind}",card,2)

KNIVES = [
 ("standard","#dfe7ee","#8a5a33","straight"),("spear","#cfd6dd","#2b2f38","spear"),
 ("breaker","#9aa0a8","#20242c","cleaver"),("batwing","#b9c2cc","#2a0a4a","bat"),
 ("spearhead","#dfe7ee","#5a616b","spear"),("wingblade","#e8eef4","#59616b","wing"),
 ("crimson","#e63946","#6b4a00","curve"),("hammer","#7fd7ff","#6b4a00","hammer"),
 ("sickle","#dfe7ee","#8a5a33","sickle"),("claws","#cfe7ff","#d7a54a","claw"),
 ("butcher","#e8e2d2","#8a5a33","cleaver"),("frost","#7fd7ff","#20c7c9","wave"),
 ("tree","#4caf20","#e63946","tree"),("candy","#ffffff","#e63946","candy"),
 ("bat","#e8d27f","#b3272d","batwood"),("vip","#cfe7ff","#6a3a9f","star"),
 ("apex","#ffd23f","#20c7c9","apex"),
]

def knife_svg(blade, handle, shape):
    b=blade; h=handle
    if shape=="straight":
        path=f'<path d="M48 6 Q62 34 56 66 L40 66 Q34 34 48 6 Z" fill="{b}" stroke="#5a6570" stroke-width="3"/>'
    elif shape=="spear":
        path=f'<path d="M48 4 L64 44 L54 66 L42 66 L32 44 Z" fill="{b}" stroke="#5a6570" stroke-width="3"/><circle cx="48" cy="44" r="7" fill="#5a6570"/>'
    elif shape=="cleaver":
        path=f'<path d="M30 10 L66 14 L66 62 L34 66 Z" fill="{b}" stroke="#5a6570" stroke-width="3"/><circle cx="58" cy="22" r="4" fill="#5a6570"/>'
    elif shape=="bat":
        path=f'<path d="M48 8 Q70 30 58 66 L44 66 Q46 44 30 40 Q40 30 48 8 Z" fill="{b}" stroke="#5a6570" stroke-width="3"/>'
    elif shape=="wing":
        path=f'<path d="M48 8 Q66 34 56 66 L42 66 Q36 42 22 46 Q34 28 48 8 Z" fill="{b}" stroke="#5a6570" stroke-width="3"/>'
    elif shape=="curve":
        path=f'<path d="M40 8 Q74 30 58 66 L44 66 Q54 40 30 24 Z" fill="{b}" stroke="#7a1020" stroke-width="3"/>'
    elif shape=="hammer":
        path=f'<rect x="24" y="12" width="48" height="34" rx="6" fill="{b}" stroke="#5a6570" stroke-width="3"/><rect x="42" y="46" width="12" height="20" fill="{h}"/>'
    elif shape=="sickle":
        path=f'<path d="M62 10 Q76 44 48 62 L40 52 Q60 40 52 18 Z" fill="{b}" stroke="#5a6570" stroke-width="3"/>'
    elif shape=="claw":
        path=f'<path d="M30 10 Q34 44 44 66 M48 6 Q50 44 54 66 M66 10 Q62 44 58 66" fill="none" stroke="{b}" stroke-width="8" stroke-linecap="round"/>'
    elif shape=="wave":
        path=f'<path d="M48 6 Q66 24 50 40 Q66 54 54 66 L42 66 Q34 50 44 38 Q32 22 48 6 Z" fill="{b}" stroke="#20c7c9" stroke-width="3"/>'
    elif shape=="tree":
        path=f'<path d="M48 6 L64 30 L56 30 L70 52 L54 52 L54 66 L42 66 L42 52 L26 52 L40 30 L32 30 Z" fill="{b}" stroke="#1d5a10" stroke-width="3"/>'
    elif shape=="candy":
        path=f'<path d="M60 8 Q76 8 76 26 Q76 40 62 40 L54 40 L54 66 L42 66 L42 28 Q42 18 52 18 Q60 18 60 26" fill="none" stroke="{b}" stroke-width="12" stroke-linecap="round"/><path d="M46 24 L58 36 M46 44 L54 56" stroke="{h}" stroke-width="6"/>'
    elif shape=="batwood":
        path=f'<path d="M40 66 L44 30 Q48 6 56 8 Q64 10 60 34 L54 66 Z" fill="{b}" stroke="#5c3a20" stroke-width="3"/><path d="M46 24 L58 28 M45 40 L57 44" stroke="{h}" stroke-width="4"/>'
    elif shape=="star":
        path=f'<path d="M48 6 L58 36 L88 40 L62 54 L70 84 L48 66 L26 84 L34 54 L8 40 L38 36 Z" fill="{b}" stroke="#5a6570" stroke-width="3"/>'
    else:
        path=f'<path d="M48 4 L62 34 L56 66 L40 66 L34 34 Z" fill="{b}" stroke="#20c7c9" stroke-width="3"/><path d="M48 10 L48 60" stroke="#ffffff" stroke-width="3"/>'
    return svg(96,96,f'''{path}<rect x="42" y="66" width="12" height="24" rx="4" fill="{h}" stroke="#101218" stroke-width="2"/><rect x="34" y="64" width="28" height="8" rx="3" fill="#d7a54a"/>''')

def main():
    for k in PAL: parts(k)
    for kid,b,h,shape in KNIVES:
        render(f"knives/{kid}", knife_svg(b,h,shape), 2)
    print("v0.4 assets built")
if __name__=="__main__": main()
