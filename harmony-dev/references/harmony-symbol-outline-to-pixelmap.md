> **分册：`harmony-symbol-outline-to-pixelmap`** ｜ 原独立技能 `harmony-symbol-outline-to-pixelmap`，2026-10-03 合并进 `harmony-dev`。
> 触发场景见入口 `SKILL.md` 的路由表。

# 系统符号轮廓 → PixelMap（HM Symbol 提形法）

**核心原则：永远不要手绘近似形。** `sys.symbol.*` 的真实形状直接从 DevEco SDK 自带的 HM Symbol 字体里提，一次到位。（踩坑实录：按 Material `music_note` 手绘单音符，实际 `sys.symbol.music` 是**双八分音符 + 斜横梁**，被打回重做。）

## 一、定位字体与码位

```
<DevEco Studio>/sdk/default/hms/previewer/resources/fonts/HMSymbolVF.ttf   # HM Symbol Regular, upem 1000
                                                                          # 手表另有 HMSymbolVF_watch.ttf
<同目录>/hm_symbol_config_next.json     # 分层/动画配置（只有 glyph id，没有符号名，别在这找）
```

符号名 → 码位：字体 cmap 的 **glyph name 就是符号名**（`sys.symbol.` 前缀去掉）。

```python
from fontTools.ttLib import TTFont
f = TTFont(FONT); cmap = f.getBestCmap()          # {cp: glyphName}
rev = {g: cp for cp, g in cmap.items()}
print(hex(rev['music']))                          # music -> 0xF00AD
```

已查证（2026-09-16）：`music`=U+F00AD、`music_fill`=U+F00AA、`music_note_list`=U+F00AC。
带 `_mask` 后缀的 glyph **没有 cmap**（是分层蒙版，非独立符号）。

fontTools 不必装进环境：`pip install --target <tmpdir> fonttools`，脚本里 `sys.path.insert(0, tmpdir)`。

## 二、提取轮廓（该字体全二次贝塞尔，无 cubic）

```python
from fontTools.pens.basePen import BasePen
class RecPen(BasePen):
    def __init__(self, gs): super().__init__(gs); self.cur = []
    def _moveTo(self, pt): self.cur = [('M', pt)]
    def _lineTo(self, pt): self.cur.append(('L', pt))
    def _qCurveToOne(self, c, pt): self.cur.append(('Q', c, pt))
    def _curveToOne(self, *a): raise RuntimeError('unexpected cubic')
    def _closePath(self):
        if self.cur: contours.append(self.cur); self.cur = []
    def _endPath(self): self._closePath()
glyphset = f.getGlyphSet(); glyphset['music'].draw(RecPen(glyphset))
```

**必做的自检**：以 `fontTools` 提取的轮廓采样后画成折线，叠加在 `PIL` 用同一字体渲染出的字形上（红线应完全贴合灰字）。
不贴合 = 取错 glyph 或漏了 contour，别往下走。字形 bbox 从 `f['glyf'][name]` 的 `xMin/yMin/xMax/yMax` 拿（用于居中）。

## 三、落地到 ArkTS（drawing.Path + PixelMap）

1. **PixelMap 必须可编辑**，否则 `new drawing.Canvas(pm)` 抛错：
```ts
const options: image.InitializationOptions = {
  size: { width: edge, height: edge },
  pixelFormat: image.PixelMapFormat.RGBA_8888,
  editable: true,
};
const pm = await image.createPixelMap(new ArrayBuffer(edge * edge * 4), options);
```
2. **轮廓数据扁平编码**：`[0,x,y]=moveTo` / `[1,x,y]=lineTo` / `[2,cx,cy,x,y]=quadTo` / `[3]=close`，存 `number[][]`。
3. **坐标映射（字号语义）**：`s = edge * fontSizeRatio / upem`，`ox = edge/2 - CX*s`，`oy = edge/2 + CY*s`
   （`CX/CY` = 字形 bbox 中心，upem 坐标），绘制时 `px = ox + x*s`、`py = oy - y*s`（**y 轴翻转**）。
   这样得到的墨迹高 = 字形墨迹比 × fontSizeRatio × edge，与 ArkUI `SymbolGlyph` 的 `fontSize` 视觉一致（HM Symbol 墨迹高≈0.86em）。
4. 用 `path.quadTo(cx, cy, x, y)`（**不是 quadraticCurveTo**）、`moveTo/lineTo/close` + `canvas.drawPath(path)`。
   填充规则用默认 winding，轮廓方向由字体给出，内孔自动镂空。
5. **底色/前景色**：主题色里带 alpha 的值（如深色 `textSecondary = #99FFFFFF`）必须先按 `fg*a + bg*(1-a)` 混到底色再画，直接画得到的是错的所见色。
   底色**铺满不画圆角**——消费方（播控中心等）会按自己的形状裁切，四角留透明会露黑边。

## 四、ArkGraphics 2D API 坑

| 坑 | 正解 |
|---|---|
| `canvas.drawRect(0,0,w,h)` | 签名只收对象：`canvas.drawRect({left,top,right,bottom} as common2D.Rect)` |
| `canvas.save/translate/scale` | 可用（API 12+），但**坐标直接映射**少一层依赖、更好排错 |
| AVSession 传 PixelMap | 有大小上限：**256² 安全，1024²（≈2.9MB）复制后 SIGSEGV**（`CopyPixMapToDst` 后 `SIGSEGV in managed thread`） |
| 无封面占位 | `setAVMetadata` 是字段级合并，不传就保留上一首——占位图要显式传，`avQueueImage` 也要一并给，否则历史歌单卡片残留旧封面 |

## 五、验证方式（不靠真机）

把**文件里最终那份轮廓数据**重新解析出来，本地用 PIL 栅格化（even-odd scanline 填充）出与目标同尺寸的图，肉眼比对形状/比例/颜色，再交给真机。
数据往返 + 本地栅格化能拦掉绝大多数错误，比"编译过了就上机"可靠。
