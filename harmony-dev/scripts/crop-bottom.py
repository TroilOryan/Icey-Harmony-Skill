"""裁剪截图底部区域并放大，用于定位"边缘渐变遮罩"的真实来源与边界。
用法: crop-bottom.py <in.jpeg> <out.png> [高度px]
"""
import sys
from PIL import Image, ImageStat

src, dst = sys.argv[1], sys.argv[2]
band = int(sys.argv[3]) if len(sys.argv) > 3 else 240

im = Image.open(src).convert("RGB")
W, H = im.size
box = (0, H - band, W, H)
crop = im.crop(box)
crop = crop.resize((W * 2, band * 2), Image.NEAREST)
crop.save(dst)

# 逐行亮度扫描：找出渐变带的上下边界与横向范围
print("size", W, H, "band", band)
rows = []
for y in range(H - band, H, 4):
    px = [im.getpixel((x, y)) for x in range(0, W, 8)]
    lum = sum((0.299 * r + 0.587 * g + 0.114 * b) for r, g, b in px) / len(px)
    mx = max((0.299 * r + 0.587 * g + 0.114 * b) for r, g, b in px)
    rows.append((y, round(lum, 1), round(mx, 1)))
print("y  avgLum  maxLum")
for y, a, m in rows:
    bar = "#" * int(a / 2)
    print(f"{y:5d} {a:6.1f} {m:6.1f}  {bar}")

# 找最亮那行的横向分布，判断宽度
best = max(rows, key=lambda r: r[1])
y0 = best[0]
line = [im.getpixel((x, y0)) for x in range(W)]
lum = [(0.299 * r + 0.587 * g + 0.114 * b) for r, g, b in line]
thr = (max(lum) + min(lum)) / 2
xs = [x for x, l in enumerate(lum) if l > thr]
print(f"\n最亮行 y={y0} 亮度={best[1]}")
print(f"  高于阈值({thr:.0f})的横向范围: x={min(xs) if xs else -1} .. {max(xs) if xs else -1}  共{len(xs)}px / 全宽{W}")
