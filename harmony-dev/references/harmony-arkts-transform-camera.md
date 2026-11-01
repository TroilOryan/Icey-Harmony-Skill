> **分册：`harmony-arkts-transform-camera`** ｜ 2026-10-31 新建。来源：Icey-Player 浮名（Fume）相机投影四轮踩坑 + 云阶移植复盘（10-30 ~ 10-31，全部真机/PC 实证）。
> 触发场景见入口 `SKILL.md` 的路由表。

# ArkUI 图形变换矩阵序 / 相机跟随投影（+ Canvas 风格特效移植方法论）

## 结论（先读，四轮裁决后的定案）

1. **ArkUI 属性合成顺序 = 矩阵序 `T·R·S`：translate 后置、不被 scale 缩放**，即 `P' = T + s·P`。
   做「相机跟随」类投影（内容平面 + 相机点锚定屏幕某点）**必须用 `T = 锚点 − s·cam`**；
   用「`T = 锚点/s − cam`」会在 cam 大时线性发散（cam 点渲染位置 = `锚点/s + cam·(s−1)`，偏差 `cam·(s−1)` 随内容深度增长）。
2. **`.scale` 默认绕组件中心** ⇒ 画布语义（原点=左上）必须显式 `.scale({ x: s, y: s, centerX: 0, centerY: 0 })`，否则公式对、渲染错。
3. **诊断铁证：偏差是否随内容深度（cam 值）线性增长** —— 是 ⇒ 变换模型不匹配（查矩阵序）；不是 ⇒ 查布局/状态。
   **渲染异常优先查变换矩阵合成顺序，不能拿症状反推公式。**
4. 「先移后缩」模型 A（`P' = s·(P+T)`，配套 `T = 锚点/s − cam`）与「后置 translate」模型 B（`P' = T + s·P`，配套 `T = 锚点 − s·cam`）**各自的公式内部自洽且逐点渲染等价**（`T_B = s·T_A`）——错的是**公式与平台真实矩阵序不匹配**。同一变换 bug 曾借三种不同症状（空白/偏左/找不到焦点）表现，其中两轮修的是观感参数而非根因。
5. **移植参数必须按目标视口重新校准**（Folia 的参数是 1600px 桌面窗口调的）：公式正确 ≠ 效果正确。特写 scale 2.2、未唱透明度 0.05、辉光 radius 18 在手机窗口上全部过狠。
6. **修完根因要回查被「顺手」改掉的设计**：治乱跳时删掉的 seeded 洗牌放置其实是误诊（乱跳真因是投影公式），根因修完后已恢复洗牌。
7. **依赖精测几何的效果，在估算布局下宁可不做**（stamp 打印方块：Folia 用 pretext 精测 glyph 偏移，估算版错位成「黄色边框」）——错位比缺失更伤画面。
8. **Stack 内浮层定位优先用布局引擎**（`Row` + `Blank(layoutWeight)` + SpaceBetween），**禁用全局窗口尺寸算绝对坐标** —— Swiper 页/浮层级联下**父容器实际高度 ≠ windowHeight**，超界部分被静默裁掉（「两卡不见了」实证）。
9. 相机锚点要按**可视区**取：底部有浮层卡时锚点 y = `(视口高 − bottomInset)/2`（浮层高 + 边距 + SafeArea），否则当前行沉底被卡遮挡。
10. **AGPL 项目只借思路、不借代码**（Folia AGPL-3.0 vs 商业应用）：技术栈无移植路径时只有概念重实现，且**连参数都要重校准**。

## 一、矩阵序四轮复盘（症状 → 误诊 → 实锤）

| 轮 | 症状 | 当轮诊断/动作 | 事后判定 |
|---|---|---|---|
| 1 | 「啥都没渲染」 | 以为 `.scale` 默认绕中心导致矩阵不等价 ⇒ 加 `centerX/centerY: 0`，公式 `T = 屏心 − cam×s` | 公式仍是模型 A 混搭，方向没对 |
| 2 | 「内容偏左」（歌词贴左缘） | 观测偏左 `cam·s·(s−1)` ⇒ 假设合成序为 `P' = s·(P+T)`，改 `T = 屏心/s − cam`，手机上「很棒」 | 模型 A 假设仍错；手机文章浅 camY 小，偏差未暴露 |
| 3 | PC 大窗「当前行沉底被裁」 | 复核官方矩阵序 **T·R·S**：`P' = T + s·P`；模型 A 公式渲染 cam 点 = `锚点/s + cam·(s−1)` 随 cam 下沉 | **实锤根因**。改模型 B：`T = 锚点 − s·cam` |
| 4 | 镜头呆板（固定 scale 1.15） | 治乱跳时砍掉的逐句变焦被误当病灶 ⇒ 还原 Folia 变焦公式 + 打印锚点跟随 | 灵动性恢复；乱跳真因（投影）第三轮已修 |

**背景视差层**：背景装饰层的 `T` 与 `s` 乘视差系数 0.94（比文章层慢一点，出层次感）。

**弹簧参数（浮名相机）**：retarget 时钟用**墙钟**不用歌时间（seek/暂停不再扰动 boost）；稳态**过阻尼 ζ≈1.15**（到位即稳，只留 idle float 浮沉）；手机窗口焦点 scale 固定小变焦（1.05~1.3）或逐句变焦均可，**变焦本身就是乱跳源**，参数要成套调。

## 二、相机跟随投影公式（模型 B，可直接抄）

```ets
// 文章层：把内容平面上的相机点 cam 渲染到屏幕锚点 anchor
.stack({ alignContent: Alignment.TopStart }) {
  Column() { /* 文章块，绝对 position */ }
    .translate({ x: anchorX - this.s * this.camX, y: anchorY - this.s * this.camY })
    .scale({ x: this.s, y: this.s, centerX: 0, centerY: 0 })   // 原点=左上，配合上式
}
// 验证：cam 点渲染位置 = T + s·cam = anchor ✓（数学上与 Folia canvas 管线
// translate(C)→scale→translate(−cam) ⇒ P' = C + s·(P − cam) 逐点等价）
```

- `anchor` = 可视区中心：`(windowWidth/2, (windowHeight − bottomInset)/2)`；`bottomInset = 底部浮层高 + 边距 + SafeArea.bottom`。
- 每帧步进（16ms tick）更新 `@State camX/camY/s`，弹簧追赶目标。

## 三、移植 Canvas 视差/相机类特效的取舍清单（Folia → ArkUI）

**移植了什么（验证有效）**：
- 文章式布局管线：列数按视口分档（≥1120→4/≥760→3/≥500→2/否则 1）、密度二分（8 次）逼近目标高度、字号二分尽量单行 —— 「每首歌像专门排过版」的观感在 ArkTS 上可复刻。
- seeded 洗牌放置（FNV-1a，种子=seedKey:行下标:文本）：**构图均匀疏朗**，是原版「composed rather than strictly chronological」的手法；`block.sourceLineIndex` 仍记真实行号，焦点/透明度/逐字链路不受影响。
- 三态逐字：waiting 近隐（0.05~0.14）、当前字 printReveal 渐显（前快后稳）、passed 淡痕（0.6 级）+ textHold 渐暗。

**刻意不移植（已验证的取舍）**：
- **stamp 打印方块**：依赖逐字几何精测，估算版错位成「每行开头一个色块」⇒ 整个移除。
- **canvas 文章预排版 + 全帧重绘**：ArkUI 布局系统 + 单行舞台已承载同样观感，预排版收益低成本高。
- **洗牌布局 × 小视口**曾改为时间序顺流（治乱跳）——后来证明是误诊，恢复洗牌；**教训：改掉原设计前先确认它是不是根因**。

**方法论**：
- 大文件移植（万行级）：先用 Explore/子代理精读产出「视觉规则 + 参数表 + 可舍弃清单」的移植蓝本，**只取视觉骨架**；每样式一舞台、共享 `StageBase`（三态枚举/词判定/指数平滑/色工具/正弦随机）组合复用。
- 一轮只交付 1~2 个模式，逐个真机验收；模式多时设置下拉用**选项表 `{style, label}`**（ForEach 绑 style 非下标），显示顺序与枚举值解耦。

## 四、浮层定位：布局引擎优先，禁全局窗口坐标

**症状**：两颗控制胶囊 `position({ x: 20, y: windowHeight−84 })` 定位后**整组消失**。
**根因**：宿主 Stack 在 Swiper 页内 —— 页实际高度 ≠ windowHeight（播放页展开态/缩放变换中），y 超界部分被 Swiper 裁掉。
**正解**：

```ets
Row() {
  this.card1()                    // 左
  Blank()                         // layoutWeight 弹性
  this.card2()                    // 右
}.justifyContent(FlexAlign.SpaceBetween)
 .padding({ left: 20, right: 20, bottom: 20 + safeAreaBottom })
```

- 布局引擎对父容器实际尺寸自适配，**无越界可能**；确需绝对定位时以**父容器实测尺寸**（onAreaChange）为准，不以窗口为准。

## 五、tooltip（拖动气泡）被裁的两处成因

1. **宿主 clip**：卡片 `clip(true)`（裁圆角）会把 `position y: -25` 的上方气泡一起裁 ⇒ 气泡改 `tooltipBelow`（条下方）或加高卡片。
2. **位置基准**：气泡 `position` 相对**内部 Stack**（高 = 条高）而非卡片，改卡高/条位时要重新核算 4~5vp 级的边距，别目测。

## 来源

- Icey-Player-Harmony 2026-10-30（浮名 14:33 → 20:39 四轮）/ 10-31（洗牌恢复 10:22、分侧两卡 13:51、变焦还原 09:28）。
- 关联分册：`harmony-arkts-text-glow.md`（辉光/blur 余量）、`harmony-arkts-lint-fix.md`（响应式死依赖——窗口尺寸必须订阅）、`harmony-canvas-frame-pacing.md`（帧率打点口径）。
