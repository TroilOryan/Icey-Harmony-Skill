> **分册：`harmony-arkts-text-glow`** ｜ 2026-10-31 新建。来源：Icey-Player 云阶（Partita）歌词辉光四轮踩坑 + 浮名（Fume）黄框（10-30 ~ 10-31，全部真机逐轮裁决）。
> 触发场景见入口 `SKILL.md` 的路由表。

# 文字辉光（Text Glow）与 Canvas 装饰层

## 结论（先读，全部真机四轮裁决后的定案）

1. **文字光晕唯一可靠方案 = 双层 Text**：glow 层（**同文本**、accent 色、`.blur(14)`、低透明度）叠 body 层（实色字）。`.blur` 作用在**文字渲染内容**上 = 贴字形的光晕；两层同字体同排版管线，**物理不可能错位**。零 Canvas、零重绘时机问题。
2. **禁止用 `.shadow` 做文字光晕**：ArkUI `.shadow` 的轮廓 = **组件矩形**（整个 Text 行的边框），不是文字轮廓。accent 取色偏暖时整行阴影读作「框住内容的黄框」。**永远不要对 Text 行挂光晕 shadow**（除非逐字 canvas，而那也已弃用，见下）。
3. **Canvas 辉光（shadowBlur 路线）已弃用**：矩形阴影 → 重影 → 裁切 → 间距暴涨 → resize 空白**四连坑**，每修一个引入一个新问题（实录见第三节）。若历史代码还在用，迁移到双层 Text。
4. **组件级 `.blur(n)` 必须给组件加 ≥ 3×n 的对称 padding 余量**，否则模糊采样超出组件边界被裁，四边出现硬边 = 「文字矩形区域可见」。余量模型 = **高斯可见铺开 ≈ 3σ**（`blur(14)` 实铺 ~42px）；**无需乘 scale**（「≥ blur×scale」模型已被实证证伪，见第四节）。
5. **Canvas 重绘时机三要素必须全覆盖**：①首次 `onReady` ②尺寸变化 ③内容/状态变化。⚠️ **resize 会静默清空位图且不再触发 `onReady`**（onReady 仅首次）—— 必须 `@Watch` 尺寸手动重绘。漏任何一个 = Canvas 空白/内容消失。
6. **装饰画布必须 `position` 脱离布局流**：Canvas（辉光/描边等比内容大的层）若参与 Stack 布局，`width auto` 会取其**物理尺寸**（含辉光余量）→ 撑爆父容器/撑大词间距。`position` 定位 + 负偏移居中覆盖，布局尺寸永远由内容本体（body Text）决定。
7. **Canvas 的尺寸字段必须是 `@State`**：普通字段改数值不触发 Canvas 组件 resize，物理画布停留在初始尺寸，绘制超出即被裁。
8. 焦点醒目化口径（云阶定案）：**镜头逐句变焦表达焦点，不要叠加字号放大**（两处都放大会过度）；变焦公式还原 Folia 原版 `clamp(minSide×0.115/lineHeight, 0.88, 2.2)`。配套见 `harmony-arkts-transform-camera.md`。

## 一、终版方案：双层 Text（可直接抄）

```ets
Stack() {
  // glow 层：同文本 + accent 色 + blur + 低透明度；position 脱离布局流（不占位）
  Text(this.word)
    .fontColor(this.accentColor)
    .blur(14)
    .opacity(0.75)
    .padding({ left: 56, right: 56, top: 56, bottom: 56 })   // ≥ 3×blur(14)=42 的余量，防边界裁切
    .position({ x: -56, y: -56 })                             // 抵消 padding 偏移，文字回到原位
  // body 层：实色字，唯一可见字形
  Text(this.word)
    .fontColor(this.bodyColor)
}
```

- **词距不受影响**：glow 层 `position` 不参与布局，Stack 尺寸由 body 层决定；若给 body 层也加 padding（它有 `blur(10)`），必须 `translate(-56, -56)` 抵消，**且要确认它不撑坏已验收的排版**——云阶终版里 body 层的 blur 仅 waiting 态存在而 waiting opacity=0 不可见，最终 **body 层不加 padding**。
- blur 余量（56）大于 3×14=42 是刻意留的额外保险（含字宽估算误差）。

## 二、为什么 `.shadow` 不行（矩形轮廓，10-30 黄框实证）

- 现象：当前歌词行出现「超出文字宽度的黄色框」。根因：当前行挂 `.shadow({ color: accent, radius: 10 })` —— shadow 画的是**组件矩形**；封面取色偏暖时 accent 偏黄，全行阴影读作「框住内容的黄框」。
- Folia（canvas 实现）的辉光是**逐字 shadowBlur 跟字形**，语义完全不同；把 canvas 语义平移成 `.shadow` 是这坑的根源。
- **判据**：凡「光晕/发光/辉光」需求出现在 Text 上，直接上双层 Text；**不试验 `.shadow`**（哪怕 radius 很小，矩形轮廓在暗背景下必现）。

## 三、Canvas 辉光四连坑实录（别重走）

| # | 症状 | 根因 | 修复 | 后续 |
|---|---|---|---|---|
| 1 | 辉光有分界明显的矩形 | glow 层 Text 挂 `.shadow` = 矩形光块 | 改 Canvas `shadowBlur`（绘制指令只影响画出的字形，贴字形） | 引入 2~5 |
| 2 | 高亮字出现**两个一样的字** | Canvas `fillText` 画了实色字形 + body 层 Text 字形**亚像素错位** | **destination-out 挖心**：画字形+shadow 后 `globalCompositeOperation='destination-out'` 再 fillText 同位置挖掉字形本体，Canvas 只剩纯光晕 | 挖心本身正确（保留技巧价值） |
| 3 | 阴影仍被裁 | `canvasW/canvasH` 是**普通字段非 `@State`** —— 改数值不触发 Canvas resize，物理画布停留初始 200×96 | 改 `@State` + `aboutToAppear` 先算尺寸（首帧即目标尺寸） | 引入 4、5 |
| 4 | 字间距暴涨、尾词出屏 | Canvas 物理尺寸 = 词宽+160（辉光余量）且**参与 Stack 布局** —— Stack width auto 取最大子宽，每词占位多 160 | Canvas `.position` 脱离布局流，以 `-(canvasW-textW)/2` 偏移居中覆盖 | 引入 5 |
| 5 | 改 position 后辉光/字**看不到** | **resize 静默清空位图且不重新触发 onReady**（onReady 仅首次） | `canvasW/canvasH` 加 `@Watch` → ready 时手动重绘 | 四连坑齐 → 弃用 Canvas，改双层 Text |

**挖心代码（若确需 Canvas 光晕，这是唯一正确画法）**：

```ts
ctx.font = ...; ctx.shadowBlur = 20; ctx.shadowColor = accent;
ctx.fillText(word, x, y);                              // 字形 + 辉光
ctx.globalCompositeOperation = 'destination-out';
ctx.shadowBlur = 0;
ctx.fillText(word, x, y);                              // 把字形本体挖掉，只留光环
ctx.globalCompositeOperation = 'source-over';
```

**每修一个引入新问题的模式要警觉**：当一条路线的修复开始**成串引入新症状**（本例第 3 修完冒出 4、5），该回头评估换路线，而不是继续在原路线上打补丁——本例在第四坑后放弃 Canvas 改双层 Text，问题归零。

## 四、blur 边缘裁切：余量模型三轮定案 = 3×blur

**现象**：云阶高亮字 `.blur(14)` 后，文字周围出现**直线硬边** = 文字矩形区域可被轻易发现。

| 轮 | 余量 | 模型 | 结果 |
|---|---|---|---|
| 1 | padding 18/12 | 「加点余量」 | 裁（18 < 14 本身都不够） |
| 2 | padding 28/20 | 余量 ≥ blur × scale（14×1.4=19.6） | **仍裁**（28 ≥ 19.6）→ 模型证伪 |
| 3 | padding 56/56 | **高斯可见铺开 ≈ 3×blur 半径（3σ）**，blur(14) 实铺 ~42px | 净 ✓ |

**3× 模型的两条论证（别再改回去）**：

- 高斯分布 2σ 处振幅仍有 ~13%，暗背景下肉眼可见被位图边界硬截成直线边；3σ 处才衰减到不可见。
- **无需乘 scale**：blur 在节点位图上采样、后经 transform 上屏，padding 与模糊范围**等比放大，比例恒定** —— 第 2 轮「28 仍裁」的真因不是 scale 吃掉余量，而是 28 本就小于实铺 42。

**配套手法**：挂 blur 的组件加 ≥3×blur 对称 padding + `position`/`translate` 负偏移抵消，保证文字原位与词距不变。

## 五、Canvas 重绘时机三要素（通用，超出辉光场景也成立）

```ets
Canvas(this.context)
  .onReady(() => this.redraw())                    // ① 首次
  .onAreaChange(() => this.redraw())               // ② 尺寸变化 —— resize 清空位图且不触发 onReady
@State @Watch('onStatusChange') status: number = 0; // ③ 内容/状态变化
```

- **resize 静默清空**是隐形坑：`@State` 尺寸变化 → Canvas 重建尺寸 → 位图清空 → 无重绘 = 永远空白。
- 重绘入口收敛成一个 `redraw()`，配 `canvasReady` 守卫（onReady 前不画）。
- 先例：Icey-Reader 阅读页 Canvas 自绘正文（`harmony-app-template.md` LSN-031）同样三处触发。

## 六、舞台类歌词特效的架构结论（云阶/Folia 移植配套）

- **镜头跟随 = 单行舞台**：只渲染当前行的 chunks 居中显示，行切换整组换场（`transition` OPACITY ~280ms）——「镜头跟着歌词走」天然成立；**不要堆叠渲染全部行**（多行时下面的滚出屏幕，镜头感消失）。
- **舞台要有视口约束**：chunks 容器放进 **65% 视口高**的容器居中（Folia `h-[70vh]` 同语义；行数公式 `floor(H×0.65/100)` 正是配这个容器），整组永在屏内。
- 全屏沉浸页**禁右滑**进歌词页：宿主 Swiper `.disableSwipe(沉浸态)`（编程切换 changeIndex 不受影响）。
- 变焦/相机/投影公式与移植方法论（参数重校准、洗牌误诊、stamp 取舍）→ **`harmony-arkts-transform-camera.md`**。

## 来源

- Icey-Player-Harmony 2026-10-30（浮名黄框）/ 10-31（云阶 14:31 → 22:39 四轮），用户真机逐轮截图裁决。
- 关联分册：`harmony-arkts-transform-camera.md`（矩阵序/相机）、`harmony-arkts-lint-fix.md`（响应式死依赖）、`harmony-material-layer.md`（材质 scope）。
