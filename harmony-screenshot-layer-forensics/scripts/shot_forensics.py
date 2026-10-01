# -*- coding: utf-8 -*-
"""截图分层取证：判「叠加层有没有画」+ 读内容。

用法：
  python shot_forensics.py mask <src> <out_dir>            # 颜色掩膜 + 连通块聚类
  python shot_forensics.py zoom <src> <out_dir> <x> <y> [half_w] [half_h]
  python shot_forensics.py tiles <src> <out_dir>           # 高对比分块放大（整体扫）

依赖 Pillow。Windows 下用 managed python 跑，输出用 Read 看。
"""
import os
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFont, ImageOps


def enhance(im: Image.Image) -> Image.Image:
    im = ImageOps.autocontrast(im, cutoff=1)
    im = ImageEnhance.Contrast(im).enhance(2.6)
    return ImageEnhance.Brightness(im).enhance(1.35)


def label_mask(px, w, h, min_px=60, min_w=24, max_h=48, min_ratio=1.6):
    """按标签特征色找候选连通块。返回 [(bbox, 平均色, 像素数)]。"""
    mask = bytearray(w * h)
    for y in range(h):
        base = y * w
        for x in range(w):
            r, g, b = px[x, y]
            cyan = (b - r) > 26 and b > 70
            neutral = r > 150 and g > 150 and b > 140 and abs(r - b) < 46
            if cyan or neutral:
                mask[base + x] = 1

    rad = 3
    dil = bytearray(mask)
    for y in range(h):
        for x in range(w):
            if not mask[y * w + x]:
                continue
            for dy in range(-rad, rad + 1):
                yy = y + dy
                if yy < 0 or yy >= h:
                    continue
                for dx in range(-rad, rad + 1):
                    xx = x + dx
                    if 0 <= xx < w:
                        dil[yy * w + xx] = 1

    seen = bytearray(w * h)
    out = []
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if not dil[i] or seen[i]:
                continue
            stack = [(x, y)]
            seen[i] = 1
            x0 = x1 = x
            y0 = y1 = y
            n = 0
            sr = sg = sb = 0
            while stack:
                cx, cy = stack.pop()
                n += 1
                x0, x1 = min(x0, cx), max(x1, cx)
                y0, y1 = min(y0, cy), max(y1, cy)
                if mask[cy * w + cx]:
                    r, g, b = px[cx, cy]
                    sr += r; sg += g; sb += b
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < w and 0 <= ny < h and dil[ny * w + nx] and not seen[ny * w + nx]:
                        seen[ny * w + nx] = 1
                        stack.append((nx, ny))
            bw, bh = x1 - x0 + 1, y1 - y0 + 1
            if n < min_px or bw < min_w or bh > max_h or bw / max(1, bh) < min_ratio:
                continue
            c = max(1, n)
            out.append(((x0, y0, x1, y1), (sr // c, sg // c, sb // c), n))
    out.sort(key=lambda t: (t[0][1], t[0][0]))
    return out


def font(size: int):
    for p in (r"C:\Windows\Fonts\msyh.ttc", r"C:\Windows\Fonts\simhei.ttf"):
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    mode, src = sys.argv[1], sys.argv[2]
    out_dir = sys.argv[3] if len(sys.argv) > 3 else "."
    os.makedirs(out_dir, exist_ok=True)
    im = Image.open(src).convert("RGB")
    w, h = im.size
    print("src", src, w, "x", h)

    if mode == "mask":
        boxes = label_mask(im.load(), w, h)
        print("候选块:", len(boxes))
        for k, ((x0, y0, x1, y1), col, n) in enumerate(boxes):
            kind = "青系(星座/青白)" if col[2] - col[0] > 26 else "白/暖白(星官/亮星/行星)"
            print("  #%02d (%d,%d)-(%d,%d) %dx%d n=%d rgb=%s %s"
                  % (k, x0, y0, x1, y1, x1 - x0 + 1, y1 - y0 + 1, n, col, kind))
            crop = enhance(im.crop((max(0, x0 - 12), max(0, y0 - 12),
                                    min(w, x1 + 12), min(h, y1 + 12))))
            f = max(1, int(460 / max(1, crop.width)))
            crop = crop.resize((crop.width * f, crop.height * f), Image.LANCZOS)
            crop.save(os.path.join(out_dir, "mask-%02d.png" % k))
    elif mode == "zoom":
        cx, cy = int(sys.argv[4]), int(sys.argv[5])
        hw = int(sys.argv[6]) if len(sys.argv) > 6 else 95
        hh = int(sys.argv[7]) if len(sys.argv) > 7 else 34
        crop = enhance(im.crop((max(0, cx - hw), max(0, cy - hh), cx + hw, cy + hh)))
        crop = crop.resize((crop.width * 7, crop.height * 7), Image.LANCZOS)
        p = os.path.join(out_dir, "zoom-%d_%d.png" % (cx, cy))
        crop.save(p)
        print("saved", p, crop.size)
    elif mode == "tiles":
        flat = enhance(im)
        cols, rows, ov = 2, 3, 0.08
        for r in range(rows):
            for c in range(cols):
                box = (int(max(0.0, c / cols - ov) * w), int(max(0.0, r / rows - ov) * h),
                       int(min(1.0, (c + 1) / cols + ov) * w), int(min(1.0, (r + 1) / rows + ov) * h))
                t = flat.crop(box)
                t = t.resize((t.width * 3, t.height * 3), Image.LANCZOS)
                t.save(os.path.join(out_dir, "tile-r%dc%d.png" % (r, c)))
        flat.resize((int(w * 0.9), int(h * 0.9)), Image.LANCZOS).save(
            os.path.join(out_dir, "full-enhanced.png"))
        print("tiles saved to", out_dir)
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
