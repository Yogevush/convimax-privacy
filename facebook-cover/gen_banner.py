#!/usr/bin/env python3
"""Generates banner.html: a 1640x624 Facebook Page cover (2x of the 820x312 desktop display).

Layout (RTL, Hebrew):
  - top    : white headline over the dark back of the hall
  - middle : audience silhouettes fading into darkness (illusion of a hall that keeps going)
  - bottom : dark strip with the two closing lines

Optional: pass a photo path as argv[1] to use a real photo as the background instead of the
illustrated hall. Texts stay in the same, mobile-safe positions.
"""
import random
import sys
from pathlib import Path

W, H = 1640, 624
HERE = Path(__file__).resolve().parent
FONTS = HERE / "fonts"

photo = sys.argv[1] if len(sys.argv) > 1 else ""

HEADLINE_1 = "להשפיע יותר"
HEADLINE_2 = "על אחרים ועל עצמך"
LINE_A = "כלים מוכחים מדעית לחיים"
LINE_B = "לתובנות וכלים לחיים מדי שבוע, אשמח לראות אותך בין העוקבים."


def silhouettes():
    """Rows of heads and shoulders, smaller and darker toward the back (top)."""
    rng = random.Random(11)
    out = [
        # top-lit look: a faint warm highlight on the crown of each head and shoulder line
        '<defs>'
        '<radialGradient id="hg" cx="50%" cy="6%" r="80%">'
        '<stop offset="0" stop-color="#2b2620"/><stop offset="0.22" stop-color="#0d1017"/><stop offset="1" stop-color="#04060b"/>'
        '</radialGradient>'
        '<linearGradient id="sg" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#1a1b22"/><stop offset="0.18" stop-color="#090c13"/><stop offset="1" stop-color="#04060b"/>'
        '</linearGradient>'
        '</defs>'
    ]
    rows = [
        # y_center, head_radius, spacing, opacity  (back rows first, drawn first)
        (286, 11, 34, 0.45),
        (304, 13, 40, 0.58),
        (326, 16, 48, 0.72),
        (352, 20, 58, 0.84),
        (384, 25, 72, 0.93),
        (424, 31, 90, 0.98),
        (474, 39, 114, 1.00),
        (540, 50, 150, 1.00),
    ]
    for (cy, r, sp, op) in rows:
        x = -sp * rng.random()
        while x < W + sp:
            jx = rng.uniform(-sp * 0.16, sp * 0.16)
            jy = rng.uniform(-r * 0.22, r * 0.22)
            hx, hy = x + jx, cy + jy
            sw = r * 3.4  # shoulder width
            sh = r * 3.2  # shoulder block height (runs under the next row)
            tilt = rng.uniform(-9, 9)
            rx = r * rng.uniform(0.86, 0.96)   # heads are slightly taller than wide
            ry = r * rng.uniform(1.0, 1.08)
            out.append(
                f'<g opacity="{op:.2f}" transform="rotate({tilt:.1f} {hx:.1f} {hy:.1f})">'
                f'<rect x="{hx - sw / 2:.1f}" y="{hy + r * 0.62:.1f}" width="{sw:.1f}" height="{sh:.1f}" rx="{r * 0.95:.1f}" fill="url(#sg)"/>'
                f'<ellipse cx="{hx:.1f}" cy="{hy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="url(#hg)"/>'
                f"</g>"
            )
            x += sp * rng.uniform(0.82, 1.18)
    return "\n".join(out)


if photo:
    background = f"""
      <img class="photo" src="file://{Path(photo).resolve()}" alt="">
      <div class="wall-haze"></div>"""
else:
    background = f"""
      <div class="hall"></div>
      <div class="spot"></div>
      <svg class="crowd" viewBox="0 0 {W} {H}" width="{W}" height="{H}" xmlns="http://www.w3.org/2000/svg">
        {silhouettes()}
      </svg>
      <div class="floor-fog"></div>"""

html = f"""<!doctype html>
<html lang="he" dir="rtl">
<head>
<meta charset="utf-8">
<title>Facebook cover</title>
<style>
  @font-face {{ font-family: "Heebo"; font-weight: 400; src: url("file://{FONTS}/heebo-400.ttf"); }}
  @font-face {{ font-family: "Heebo"; font-weight: 500; src: url("file://{FONTS}/heebo-500.ttf"); }}
  @font-face {{ font-family: "Heebo"; font-weight: 700; src: url("file://{FONTS}/heebo-700.ttf"); }}
  @font-face {{ font-family: "Heebo"; font-weight: 800; src: url("file://{FONTS}/heebo-800.ttf"); }}
  @font-face {{ font-family: "Heebo"; font-weight: 900; src: url("file://{FONTS}/heebo-900.ttf"); }}
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  html, body {{ width: {W}px; height: {H}px; overflow: hidden; background: #05080f; }}
  .cover {{ position: relative; width: {W}px; height: {H}px; overflow: hidden; font-family: "Heebo", sans-serif; color: #fff; }}

  /* --- illustrated hall --- */
  .hall {{ position: absolute; inset: 0;
    background:
      radial-gradient(ellipse 60% 55% at 50% 118%, rgba(255,170,90,0.28), rgba(0,0,0,0) 70%),
      linear-gradient(180deg, #0a1020 0%, #0b1426 42%, #070c17 70%, #04070d 100%); }}
  .spot {{ position: absolute; inset: 0;
    background:
      radial-gradient(ellipse 34% 70% at 50% -10%, rgba(255,214,150,0.30), rgba(255,214,150,0.08) 45%, rgba(0,0,0,0) 72%),
      /* lit haze behind the crowd, so the heads read as silhouettes */
      radial-gradient(ellipse 66% 34% at 50% 58%, rgba(255,196,135,0.50), rgba(170,180,225,0.22) 50%, rgba(0,0,0,0) 80%),
      radial-gradient(ellipse 80% 40% at 50% 100%, rgba(0,0,0,0) 40%, rgba(0,0,0,0.35) 100%); }}
  .crowd {{ position: absolute; inset: 0; }}
  .floor-fog {{ position: absolute; inset: 0;
    background: linear-gradient(180deg, rgba(0,0,0,0) 0%, rgba(0,0,0,0) 58%, rgba(0,0,0,0.55) 78%, rgba(0,0,0,0.94) 100%); }}

  /* --- real photo variant --- */
  .photo {{ position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; object-position: center; }}
  .wall-haze {{ position: absolute; inset: 0;
    background:
      linear-gradient(180deg, rgba(4,7,13,0.86) 0%, rgba(4,7,13,0.62) 30%, rgba(4,7,13,0.0) 52%),
      linear-gradient(180deg, rgba(0,0,0,0) 58%, rgba(0,0,0,0.60) 78%, rgba(0,0,0,0.94) 100%); }}

  /* --- vignette and grain --- */
  .vignette {{ position: absolute; inset: 0; pointer-events: none;
    background: radial-gradient(ellipse 75% 85% at 50% 45%, rgba(0,0,0,0) 55%, rgba(0,0,0,0.55) 100%); }}

  /* --- text --- */
  .headline {{ position: absolute; top: 74px; left: 0; right: 0; text-align: center;
    font-weight: 800; font-size: 82px; line-height: 1.12; letter-spacing: -0.5px;
    text-shadow: 0 4px 24px rgba(0,0,0,0.75), 0 1px 3px rgba(0,0,0,0.6); }}
  .headline span {{ display: block; }}
  .headline .l2 {{ font-weight: 700; font-size: 70px; }}
  .bottom {{ position: absolute; left: 0; right: 0; bottom: 44px; text-align: center; }}
  .line-a {{ font-weight: 700; font-size: 44px; line-height: 1.2; letter-spacing: -0.2px;
    text-shadow: 0 2px 14px rgba(0,0,0,0.7); }}
  .rule {{ width: 120px; height: 3px; margin: 12px auto 12px; border-radius: 2px;
    background: linear-gradient(90deg, rgba(255,196,120,0), rgba(255,196,120,0.9), rgba(255,196,120,0)); }}
  .line-b {{ font-weight: 400; font-size: 30px; line-height: 1.35; color: rgba(255,255,255,0.92);
    text-shadow: 0 2px 12px rgba(0,0,0,0.7); }}
</style>
</head>
<body>
  <div class="cover">
    {background}
    <div class="vignette"></div>
    <div class="headline"><span class="l1">{HEADLINE_1}</span><span class="l2">{HEADLINE_2}</span></div>
    <div class="bottom">
      <div class="line-a">{LINE_A}</div>
      <div class="rule"></div>
      <div class="line-b">{LINE_B}</div>
    </div>
  </div>
</body>
</html>
"""

(HERE / "banner.html").write_text(html, encoding="utf-8")
print("wrote", HERE / "banner.html", "photo" if photo else "illustrated")
