# 商店宣传图 / 海报批量生成（竖稿源文件 + 横稿管线重排）

> 适用：任何应用的商店截图宣传图、版头海报、尺寸衍生图。
> 模式：**竖稿（设计源文件）随仓库走 = 唯一真源；其它尺寸全部由脚本从竖稿派生**。
> 派生产物入库且可逐字节复现 —— 谁在任何机器上重跑脚本，产物都不变；
> 换设计稿时只换竖稿再重跑，杜绝「改了横稿忘了竖稿 / 下次重跑被打回旧版」。

## 结论（先读）

1. **竖稿入库、横稿派生、脚本随仓库、产物可复现**。脚本用相对路径（`os.path.dirname(__file__)`），
   源稿读 `1080x1920/Frame N - 名称.png`，输出写回同仓库同名目录。禁止依赖 Downloads / 桌面散文件。
2. **像素级验证，别目测**。派生产物 vs 上一版按「分区」做 diff：粉带区 / 文案区 / 品牌区应**逐字节一致**
   （diff 均值 0.0），只有主视觉区该变；边界质量用「边界条带最深值（距纯白的差）」量化，阈值见下。
3. **软阴影裁切是最高频翻车点**（2026-11-09 七张全组实案）：手机群四周阴影被 bbox 修剪线 /
   固定裁切线切断，肉眼是「手机周围有一圈矩形硬边」。解法是「保持裁切位置 + 按边羽化」，
   **不是调低 bbox 阈值去追阴影尾巴**（会撞画布上部底噪/装饰污染，bbox 直接炸到画布边）。

## 四个坑（都有实测数据，别踩回去）

### 坑 1：文案块当矩形贴到别处，露灰底方块

原稿机身投影渗进文案区（亮度 240~254 的浅灰）。⇒ `key_light()` 按亮度做 alpha 抠掉浅背景，
文字灰阶不变：

```python
def key_light(img, hi=245.0, lo=232.0):
    rgb = np.asarray(img.convert("RGB")).astype(np.float32)
    v = rgb.max(2)
    a = np.clip((hi - v) / (hi - lo), 0, 1)
    out = img.convert("RGBA")
    out.putalpha(Image.fromarray((a * 255).astype(np.uint8)))
    return out
```

### 坑 2：主视觉裁切必须从 y≥106 起（品牌行余灰）

品牌字 y 84~92 有抗锯齿余灰，裁切带上会出现一个脏点（放大后可见）。固定从 y=106 起裁主视觉。

### 坑 3：手机群四周软阴影被裁出硬边（核心）

两处来源：
- **bbox 阈值修剪**：`content_bbox(thr)` 通常按「距纯白 >14」判内容，会把亮度 241~254 的最外圈浅影
  当空白修掉 ⇒ 阴影停在亮度 ~240 处，四周出现矩形硬边；
- **固定裁切线**：主视觉底固定裁某行（如 1685），新设计手机群越排越低、软阴影一直延到文案标题前
  （实测：切线处阴影亮度 238~240、每行 450+ 非白像素）⇒ 拦腰硬切。

**正确解法（阴影安全裁切三规则）**：

1. **底裁切自动取「文案标题顶 − 2」**——切在亮度 ≥253 处，不可见。标题顶由文案区 bbox 反推：
   `title_top = copy_window_y0 + content_bbox(copy_crop, 20)[1]`。
2. **bbox 阈值保持原档（如 14），别调低去追阴影尾**。实测数据（阈值 2）：
   - 6/7 张画布上部有 v 3~14 的底噪/品牌余灰 ⇒ **bbox 上沿炸到 y=0**（把整个画布上部当内容收进来）；
   - 有装饰的稿子下角还有 v≤7 的污染会被收进主视觉。
   - 例外：**webp 等转码来的干净画布**（无上部底噪）可以放低阈值把整圈浅影直接收进 bbox。
3. **羽化兜底 + 按边门控**：bbox 四边里「边界 3px 条带最深值 ≤30（即纯浅影）」的边做 20px alpha
   线性渐隐，化进白底；**边界是实体的边绝不羽化**（实测：有的稿子顶边=手机顶边，条带最深 142~153，
   羽化会糊掉真边——门控判据就是条带最深值）。

```python
def content_bbox(im, thr=14):
    a = np.asarray(im.convert("RGB")).astype(int)
    seg = (np.abs(a - 255).max(2) > thr)
    ys = np.where(seg.sum(1) > 3)[0]
    xs = np.where(seg.sum(0) > 2)[0]
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1

def feather_edges(img, width=20, gate=30, strip=3):
    """bbox 四边中「边界 strip px 条带是浅影（最深 ≤ gate）」的边做 width px 线性渐隐，返回 RGBA"""
    rgb = np.asarray(img.convert("RGB")).astype(np.float32)
    v = 255.0 - rgb.min(2)                      # 0 = 纯白
    h, w = v.shape
    width = max(1, min(width, h // 2, w // 2))
    alpha = np.ones((h, w), dtype=np.float32)
    lr = np.linspace(0.0, 1.0, width)
    def faint(vals):
        return float(vals.max()) <= gate
    if faint(v[:, :strip]):
        alpha[:, :width] = np.minimum(alpha[:, :width], lr[None, :])          # 左
    if faint(v[:, -strip:]):
        alpha[:, -width:] = np.minimum(alpha[:, -width:], lr[::-1][None, :])  # 右
    if faint(v[:strip, :]):
        alpha[:width, :] = np.minimum(alpha[:width, :], lr[:, None])          # 上
    if faint(v[-strip:, :]):
        alpha[-width:, :] = np.minimum(alpha[-width:, :], lr[::-1][:, None])  # 下
    return Image.fromarray(np.dstack([rgb, alpha[..., None] * 255]).astype(np.uint8), "RGBA")
```

贴回画布时一律 `canvas.paste(art, pos, art)`（RGBA 自带 alpha 作 mask；羽化后恒为 RGBA）。

**验收口径**（数字说话）：
- 羽化边内侧 4px 条带最深 ≤6/255（不可见）；衰减曲线逐行单调平滑（实测 59→47→39→31→21→13→7→2→0）；
- 放大目检四边裁片，无矩形硬边；
- 品牌行 / 文案区 / 底部装饰带与上一版 diff 均值 = 0.0（逐字节一致）。

### 坑 4：品牌行的「特殊标记」会随宽裁混进来

若某张竖稿的品牌行带第二品牌标（如 HarmonyOS 字标）而定案要求横稿不带，
`brand` 裁切窗**恒用窄裁**，别留「首张宽裁」之类的特例参数——仓库竖稿更新后特例会把标记带回来
（实测：定稿时用的是去标竖稿，仓库里存的还是带标原版，重跑即回归）。

## 管线骨架（横稿 = 竖稿重排）

16:9 里放 9:16 内容只能重排（左栏主视觉 + 右栏文案），直接把竖稿拉宽 = 中间一根细柱两片空白：

```python
ART_BOX   = (80, 150, 980, 972)      # 左栏主视觉框，等比 fit 居中
COPY_X, COPY_Y, SCALE = 1020, 520, 1.35   # 右栏文案（key_light 抠底后放大贴入）
# brand：品牌行窄裁 → content_bbox 修边 → 贴 (110, 32)
# band：底部装饰带取自某张竖稿的底条 resize，保证全组风格一致
```

## 工程约定

- **逐帧参数覆盖**：`ART_SPEC = {N: dict(...)}` 显式列出特殊帧 + 写明为什么；
  默认参数必须让「未特列的帧重跑逐字节一致」，否则派生不变量就断了。
- **换设计稿的完整动作** = 竖稿入库 → 重跑脚本 → 分区 diff + 边界数值验收 → 产物与脚本一个 commit。
- 依赖只有 pillow + numpy；脚本内不得出现本机专属绝对路径（字体等资源用环境变量/自动探测/参数传入）。
