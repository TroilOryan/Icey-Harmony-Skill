> **分册：`stellarium-viewport-alignment`** ｜ 原独立技能 `stellarium-viewport-alignment`，2026-10-03 合并进 `harmony-dev`。
> 触发场景见入口 `SKILL.md` 的路由表。

# 对齐 Stellarium 的视野 / 投影口径

## 〇、Icey-Stars 项目定案（2026-09-22 二次定案，优先于下文一切推导）

**目标是「立体投影 + 短边口径」，与上游 SWE 完全同源。**

| 项 | 定案 |
|---|---|
| 投影 | **stereographic**，`px = 2k·a/(1+c)`；`2k = (h/2)/tan(fovV/4)` |
| 视场口径 | **短边**：`aspect<1 → fovx = fov`（竖屏短边 = **宽**），`fovy = 4·atan(tan(fov/4)/aspect)` |
| 默认 / 上限 / 下限 | `50°`（短边）/ `120°`（短边）/ `1″`（短边） |
| 状态字段 | `fovS`（短边）= 缩放真源；`fovV`（垂直）由 `AstroMath.fovVerticalFromShort(fovS, w/h)` 换算 |
| 换算函数 | `AstroMath.fovVerticalFromShort` / `AstroMath.stereoScale`（`fpx` 字段语义 = **2k**，不是焦距） |

**判据优先级：反编译产物 > 开源上游 > 推理。**

⚠️ **但"铁证"要分清数值与语义**。09-18/09-21 那次踩坑正源于此：
反编译只给出 `core+0x118 = double 50.0`（**数值**，有效），而笔记里"上游是垂直 FOV 语义"
是**推断**（错误）—— 于是本项目一度把 50 当垂直角实现，比 Plus 实际窄了 **1.67 倍**
（垂直 50° 等价短边 29.9°）。**教训：从二进制只能拿到常量与字符串；
凡"这个常量是什么意思"的句子都必须回开源上游逐字核对，不能沿用笔记里的推断。**

该推断被两条独立证据否掉：
1. 上游 `proj_stereographic.c::proj_stereographic_compute_fov` 逐字写着短边口径（见第一节）；
2. 量测 Plus 默认首屏可见 **5 个 10° 高度圈** ⇒ 竖屏垂直视场 ≥95°；若 50 是垂直角，
   顶边只到 alt −67.5°、最多见 2 个圈。

## 一、上游口径（逐字，读源码时用）

**上游 SWE 里 `fov` 按"屏幕短边"角解释**，两套投影同构（区别只在 `tan(fov/2)` vs `tan(fov/4)`）：

```c
// src/projections/proj_stereographic.c :: proj_stereographic_compute_fov()
if (aspect < 1) { *fovx = fov; *fovy = 4*atan(tan(fov/4)/aspect); }   // 竖屏 → 短边是宽
else            { *fovy = fov; *fovx = 4*atan(tan(fov/4)*aspect); }   // 横屏 → 短边是高
```

⇒ 同一台手机，**竖屏与横屏的"同一个 fov 数值"对应完全不同的画面**。
别人（或自己）说"视野设成 75"时，先问清是按哪个口径说的。

⚠️ **短边口径的推论容易被误读成 bug**：屏幕越"高瘦"（aspect 越小），同一短边角对应的
垂直视场越大。872×1920（aspect 0.454）的 50° 短边 ≈ **104° 垂直**；
440×744（aspect 0.591）的 50° 短边 ≈ **82° 垂直**。两者都"正确"，
**不要去凑参考截图的圈数/圈半径** —— 那是机型差异，不是口径差异。

## 二、官方数值（别拍脑袋）

| 项 | 值 | 出处 |
|---|---|---|
| web 引擎默认 | 50°（短边）+ `PROJ_STEREOGRAPHIC` | `stellarium-web-engine/src/core.c`: `core->fov = 50 * DD2R` |
| 桌面/安卓默认 | **60°**（短边） | `stellarium-master`、`Stellarium-android/mobileData/data/default_config.ini` → `[navigation] init_fov = 60` |
| 缩放下限/上限 | `0.0001°` / `100°` | `StelMovementMgr.cpp`: `minFov = 0.0001; maxFov = 100.` |
| web 引擎 UI 上限 | 120°(perspective) / 185°(stereographic) | `proj_*_klass.max_ui_fov` |
| 投影硬上限 | 360°(stereographic) | `proj_stereographic_klass.max_fov` |
| 默认投影 | **stereographic** | `core.c`: `core->proj = PROJ_STEREOGRAPHIC` |
| 界面网格 | 高度圈 10°（`STEPS_ALT n=36`）+ 方位子午线 15°（`STEPS_AZ n=24`） | `lines.c`；`default_config.ini` `[viewing]` |

## 三、换算：短边角 ⇄ 垂直角

```
aspect = w / h
# 立体投影（默认）
fovV  = (aspect >= 1) ? shortEdge : 4*atan(tan(shortEdge/4) / aspect)
# 真透视（perspective 投影才用）
fovV  = (aspect >= 1) ? shortEdge : 2*atan(tan(shortEdge/2) / aspect)
```

竖屏样例（aspect ≈ 0.45）：

| 短边角 | 立体投影下垂直角 | 真透视下垂直角 |
|---|---|---|
| 50° | **≈ 104°** | ≈ 96° |
| 60° | ≈ 122° | ≈ 104° |
| 120° | ≈ 179°（接近全天的极限） | ≈ 143° |

**结论模板**：用户说"我试了 X°（垂直）比较接近"时，先按**立体投影**式换算成短边角再比 ——
若明显不符，多半是被 UI 上限（滑块 15–90 之类）卡住了，真等价值根本滑不到。

## 四、不要把视野做成"用户设置项"

视野不是偏好，是与参考实现对齐的观感基准。做法：
- 常量存**短边角**（`STELLARIUM_FOV_DEFAULT_SHORT_EDGE = 50`），运行时按画布宽高比换成垂直角；
- 换算集中在**一个函数** + **一个 `syncFov()`**，在「捏合 / 复位 / 画布尺寸回调」三处调用；
  画布尺寸未知时直接 return（首帧由渲染循环的 w/h 守卫兜住），不要写"猜一个宽高比"的兜底；
- 挂到画布尺寸回调（ArkUI: `onAreaChange`）+ 首帧兜底常量（避免第 0 帧跳变）；
- 捏合缩放的上限同样用短边口径（`shortEdge` 直接 clamp，**不要**换成垂直角再 clamp ——
  两者在极端宽高比下会不一致）；
- 设置页**不给滑块**，只在星图上留一个只读读数。

## 五、离线核实用户截图里的角尺度（无需真机）

**先做可判别性检查，再动手 —— 本方法有两个致命坑：**

1. **颜色多半不可分**：网格线与地景同色相（实测两者都是橄榄黄 R≈G≫B，中位 57/59/29）。
   不要指望"阈值筛暖色"，只能靠**线条性**（顶帽/形态学）。
   注意顶帽必须写 `x − opening(x)`（先腐蚀后膨胀）；写 `x − dilate(x)` 会把细线全滤成 0。
2. **Hough 会被画面边框主导**：屏幕边缘的水平长边会产出 θ≈90°、ρ≈画面宽度的假直线，
   RANSAC 求交点会落在画面外。**改用周期性聚敛判据定极点**：
   把每个像素相对候选极点的角度 fold 到已知辐条间隔（15°）求 `Σh²`，扫一遍像素取最大值。
   对比度 > 5 即可用（实测 9.6）。

流程：

1. **提亮**：星空截图很暗（网格线 RGB 可能只有 `(42,26,13)`），先
   `ImageEnhance.Brightness(im).enhance(3.2)` + `Contrast(1.6)`；
2. **定极点**：按上面的 15° 周期性聚敛扫描（子午线汇聚点 = 天顶/天底）；
3. **取环半径**：以极点为圆心做径向轮廓，**沿角度取中位数**再找峰 ——
   环跨全角度所以中位数高，辐条/植被纹理角度上稀疏所以中位数低，天然分离；
4. **判投影类型**：用**相邻环半径的比值**（与宽高比、视场都无关，只取决于投影式）：
   高度圈 10° 间隔下，立体投影 = 2.015/1.520/1.358/1.281、等距 = 2.0/1.5/1.333/1.25、
   真透视 = 2.064/1.586/1.453/1.420。实测 Plus：2.021/1.513/1.356/1.279 ⇒
   立体投影（误差 **0.44%**），等距 2.27%，真透视 **11%**。
   （也可以直接对 `r = 2k·tan(θ/2)` 拟合每个环求 2k，看离散度：实测 ±0.4%。）
5. **反解视场**：`2k = (w/2)/tan(fovShort/4)`（竖屏短边 = 宽）⇒ 由 2k 与半宽反解 `fovShort`，
   再用第三节换算式得垂直角。
6. **标定图**：在图上叠 100px 网格 + 坐标数字再回看，读数误差从 ±30px 降到 ±5px。

样板脚本（本项目）：
- `.workbuddy/scripts/verify-stereo-fov.py` —— 口径换算 vs 上游逐字、环形比值判据、
  本机可见圈数、正反投影往返、逐像素天顶判据 == 解析判据（**改完 FOV/投影必跑**）；
- `.workbuddy/scripts/fov-probe.py` / `fov-center.py` / `fov-profile.py` —— 截图量测三件套；
- `.workbuddy/scripts/verify-fov-convention.mjs` —— 换算一致性 + 反解自洽 + 四角角半径检查。

## 六、gnomonic vs stereographic（换投影要同步改的四处）

- Stellarium 默认 **stereographic**：`r = 2k·tan(θ/2)`，边缘拉伸温和，`max_ui_fov` 185°；
- 很多自研实现是 **gnomonic（真透视）**：`r = k·tan θ`，好处是大圆仍是直线（地平线笔直），
  但**离轴拉伸是 `sec²θ`**。θ=54° 时已 3 倍，肉眼可见，且能用不过 120° 的视场。

**换投影时四处必须一起改，只改一半必然出怪现象：**

1. **正投影**（屏幕点 = f(方向)）：`px = 2k·a/(1+c)`（单位向量，`a=v·R̂`、`c=v·F̂`）；
2. **反投影**（拖拽/命中用）：`θ = 2·atan(r/2k)` —— 只改正投影会让"按住的那颗星跟着手指走"失效；
3. **可见性裁剪**：立体投影下 **θ 可以 >90°**（视场拉到最远时屏幕四角 θ≈97°）⇒
   **必须去掉 gnomonic 时代的 `zf>0` 裁剪**，越界只由 w/h 边界判断；
4. **地平线判据**：立体投影**大圆不是直线** ⇒ 旧的"线性半平面"`A·px + B·py + C`（只对
   gnomonic 成立）**必须废弃**，改成逐像素反解高度角（把 `[rz, −uz, fz]` 三个天顶分量传进
   着色器，逐像素 `θ = 2·atan(r/2k)` 再点乘）。忘了这步会出现"地平线弯了/地面斜切"。

四角角半径自检（立体投影，`2k` 口径）：
`θ_corner = 2·atan(hypot(w/2, h/2)/2k)`，`< 90°` 才不需要负 z 分支。

## 七、参考仓库位置（别乱克隆）

- **Stellarium 桌面源码**：stellarium / stellarium-master / stellarium-web-engine /
  Stellarium-android / stellarium-skycultures 等，通常已解压在开发机的某个
  `Downloads\Stellarium` 一类目录下。换设备第一步先 `ls` 本地是否有，没有再从
  <https://github.com/Stellarium/stellarium> clone。
- **反编译产物**：桌面版 APK 全量解包 + `notes/reverse-findings.md` 的分析笔记，
  位于本机某个 `Stellarium Plus\` 工作目录。
- 只读参考；先 `ls` 确认再读，不要新克隆一份（用户明确反感）。
