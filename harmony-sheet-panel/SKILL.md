---
name: harmony-sheet-panel
description: HarmonyOS/ArkTS 半模态弹窗（bindSheet）自绘标题带 + 标题边缘渐变模糊的完整落地范式。当需要弹窗标题「内容滚进来被糊住看到」（官方 AppGallery 评分弹窗观感）；或内容穿不进标题带、标题下有一道硬切割/硬边；或弹窗高度要么恒满屏要么塌成一条、横竖屏观感不一致；或手机横屏弹窗变成屏幕正中悬浮卡片（白面板黑卡片）；或标题与系统关闭按钮不对齐、弹窗自带白色底与面板灰底冲突时使用；或同页多弹窗**两层蒙层叠压**、列表每行内联弹窗导致首建掉帧、一个组件挂多个 bindSheet 闪烁、需要「宿主收敛 / 弹窗互斥 / 全局触发信号」时使用。含「为什么必须弃用 SheetOptions.title」「linearGradientBlur 半径单位是 px」「模糊档位与底色档位必须同组位置」「宽屏判定按窗口短边」四条定案。
agent_created: true
---

# Harmony 半模态弹窗（bindSheet）自绘标题带 + 边缘渐变模糊

## 结论（先读，全部是用户真机逐轮裁决后的定案）

1. **标题必须自绘浮层，不能用 `SheetOptions.title`。**
   官方文档（FAQ 1088 正文 + 开发指导《绑定半模态页面》）明文：*「通过 `SheetOptions` 的 title 属性设置的**标题区域与 builder 处于同级布局**」* ⇒ 系统标题带是与内容**上下排列的兄弟区域**，**占位且不透光** ⇒ 系统标题下的内容**物理上无法穿进标题带、更不可能被模糊**。而官方 AppGallery「评分与评论」弹窗的真机观感恰是「内容滚进标题带、被糊着看到」⇒ 想复刻**只能自绘浮层**。
   （`showClose` **保留** —— 系统关闭按钮仍由平台渲染在右上角，且不受 title 影响。）

2. **模糊用 `linearGradientBlur`（渐变模糊），不用 `backdropBlur`（均匀模糊）。**
   `backdropBlur` 带内糊、带外清楚 ⇒ 边界处模糊强度**突变** ⇒ 必留一条硬边（用户原话「边缘明显能看出来硬切割」）。`linearGradientBlur` 是**前景模糊**（模糊组件**自身内容**），强度可逐档渐变 ⇒ 无硬边。⚠️ 该属性作用在组件自身内容上，而**浮层没有内容可糊** ⇒ 只能挂在**滚动内容层**，浮层只负责「标题文字 + 底色渐隐」。

3. **`linearGradientBlur` 的半径单位是 px，不是 vp（全仓唯一例外）。**
   `common.d.ts` 原文 "Blur radius … Value range: [0, 1000]"，而 `backdropBlur` / `backgroundBlurStyle` / `blur` **全是 vp**。取 `20` 只有 ≈6.7vp ⇒ 肉眼几乎只是"变淡"、**没有模糊感**。要用 **64 及以上**。</br>⚠️ 这是「感觉只是一个渐变的遮罩 没有模糊效果」的根因。

4. **模糊档位与标题带底色档位必须「同一组区间节奏、各自逐档归零」。**
   两者带长可以不等（底色带 76 / 模糊带 96），但档位比例要落在同一组 0~1 节奏上，且都**在带尾收到 0**；只要档位错开，就会重新出现"模糊已停但底色还在"的**可见分割**（硬切割回归）。
   ⚠️ **底色带长有硬上限 = 内容静止起点**（`SHEET_TITLE_AREA_VP + PANEL_PAD_V` = 76vp）：超了会让**不滚动**的初始状态就压暗首行内容（见第四节）。

4.5. **`linearGradientBlur` 要想"看得见"，内容必须真的能滚进标题带。**
   内容层顶部留白（76vp）**属于内容** ⇒ 它把可用滚动行程吃掉 76vp，内容最多只能滚到"留白下沿"，面板顶部那 76vp 恒空 ⇒ 模糊最强档永远压不到任何内容上，用户读作「**还是无法到达弹窗的顶部最边缘 明显差了一点距离**」。
   补偿 = `.contentEndOffset(76 - 现有行程)`（只在内容**已溢出**时给，见第三节）。⚠️ 另一条独立红线：**不能**把标题带做成独立的兄弟节点去"让位"——那会让模糊物理上不可能发生（结论 1）。

5. **面板高度 = 「比例上限 + 内容自适应」，竖屏 `auto` / 横屏 `100%`。**
   竖屏 `height('auto')`（内容矮则面板随内容收紧）、横屏 `height('100%')`（撑满受限高度滚动），再由 `constraintSize({ maxHeight })` 封顶成真实滚动视口。⚠️ 竖屏**绝不能用 `height('100%')`**：曾把内容少的弹窗撑到 440vp 高。

6. **宽屏判定按「窗口短边」≥600vp，不是「物理屏宽」。**
   手机**横屏**时 `display.getDefaultDisplaySync().width` 随旋转变成 ~744vp ⇒ `>=600` 成立 ⇒ 手机被**误判成平板** ⇒ 弹窗改走窗口级居中 dialog，而非底部半模态。短边口径：手机竖屏 440×744 / 横屏 744×440 → 短边**恒 440** → 恒窄屏 ✓。

6.5. **自绘返回按钮必须做成「圆形 + 光感」的按钮，尺寸与关闭按钮对齐。**
   自绘浮层里那个返回按钮**很容易只做成一个裸 chevron**（因为它只是个 `onClick`），而**右上角那个系统关闭按钮是带圆形背板的** ⇒ 同一行两个按钮**不像一套**，用户读作「**返回按钮没有和关闭按钮垂直居中** 和**做光感按钮效果** **大小尺寸也注意对齐**」。
   三件事一起做才对：
   - **垂直居中**：命中块固定见方（40×40）、行高 64 + `Row.alignItems(Center)` ⇒ **块心 = 行心**，与**同一行里的标题文字**同一条中线。⚠️ 但这**不等于**与系统关闭按钮同心 —— 实测关闭按钮圆心在**面板顶 +38**、64 行行心在 **+32** ⇒ 自绘侧（标题 **和** 返回按钮）**整体再下沉 6vp**（`SHEET_TITLE_ROW_DROP_VP`，加在浮层 `Column` 的 `padding.top`；`.height()` 含 padding ⇒ 带高不变、档位零连锁）。⚠️ 标题与返回按钮**同行同中线 ⇒ 一起偏高、必须一起下沉**，只挪按钮会让两者错开。别再各写 `margin/padding` 去"微调对齐"。
   - **光感按钮**：走宿主项目里既有的"光感承载层"做法（本仓 = `MaterialLayer`，Toggle 绕过法），`Stack { 承载层; SymbolGlyph }` + `.borderRadius(直径/2)` + **`.clip(true)`** + `.onClick`；材质不可用时回落「半透明底 + `backgroundBlurStyle` + 0.5 描边」（材质接管时底色必须透明、且不再叠模糊，否则发灰）。
   - **尺寸导出成常量**：`SHEET_BACK_BTN_SIZE(40)` / `SHEET_BACK_ICON_SIZE(24)`，**窄屏浮层与宽屏 dialog 共用同一组**（各写各的必然分叉）。

7. **弹窗多了之后，架构问题会先于视觉问题爆发 —— 宿主、互斥、触发信号三件事要先定。**
   前六条解决"弹窗长什么样"，本条解决"**由谁承载、在哪触发、如何不打架**"（详见第十节）：
   - **一个组件最多挂 1 个 `bindSheet`**（链式多个会状态纠缠 ⇒ 弹出动画被对方 `onDisappear` 重置 ⇒ **闪烁**）；
   - **宿主收敛**：列表**每行内联** `AppSheet` ⇒ 20 行 = **20 个宿主**，全压在页面首建那一帧
     （实测 `appsheet.init n=29`），而同一时刻最多只有 1 个弹窗会打开 ⇒ 改为**每页一个宿主 + 请求分发**；
     ⚠️ 但**不能**"全局只挂一个"—— 半模态 `bindSheet` **只能挂当前页面组件树内**（挂 `NavDestination`
     之外**弹不出来**）⇒ 宿主随页面走，多宿主用**栈**决定谁响应；
   - **互斥**：同页多弹窗叠加 = **两层蒙层叠压** ⇒ 全局注册表按 `group` 自动关门
     （只关**同 group** 且 `dismissible=true` 的，防误关导入进度）。

## 一、为什么必须自绘浮层（完整推理链，可引用）

| 曾试过的方案 | 为何不成立 |
|---|---|
| 自绘标题**行**（排在内容流里） | 永远"看起来是自绘的"；且内容无法从它下方穿过 |
| Hds `HdsNavDestination.titleBar` | 它是**内容区里的浮层**：56vp 标题基准与系统关闭按钮不在同一行 ⇒ **必然不齐**；且自带 64vp 背板底色 ⇒ 白色底与面板灰底冲突（用户反馈「为什么自带了白色 和弹窗本身的灰色放一起了」） |
| `bindSheet` 原生 `SheetOptions.title` | 与 builder **同级布局**、占位不透光 ⇒ 内容穿不进 |
| **自绘浮层标题带** ✓ | 内容视口扩到**面板整高**，标题带作为 `Stack` 浮层（`alignContent: Alignment.Top`）压在内容之上 ⇒ 内容可滚进标题带下方并被模糊 |

配套三件事，缺一不可：
- `SheetOptions.title` **不再传**（系统标题带消失，内容视口升到面板顶）；
- 内容层顶部预留 `SHEET_TITLE_AREA_VP` 的 padding（**静止时**内容仍从标题带下沿开始，不会一上来就被标题盖住）；
- 内容层跑 `linearGradientBlur` 负责"滚上来变糊"。

## 二、组件骨架

```
AppSheet（宿主）
  build():
    Stack(){}.width(1).height(1)          // 1×1 占位，配置集中
      .hitTestBehavior(HitTestMode.Transparent)
      .bindSheet(show, this.sheetBuilder, {
        detents: [SheetSize.FIT_CONTENT, SheetSize.LARGE],   // ⚠️ 与内容层高度口径是「同一口径的两半」
        // ⚠️ `group` **不是** SheetOptions 字段 —— 它是本宿主自己的 @Prop（互斥分组），
        //    由 AppSheet 在 aboutToAppear / onShowChange 里交给 `SheetManager`（见第十节）
        dragBar: false,
        showClose: true,
        // ⚠️ 不传 title —— 见结论 1
        systemMaterial: materialFor('sheet'),
        blurStyle: BlurStyle.NONE,
        backgroundColor: ThemeManager.opaqueBackground,      // 不透明兜底（材质在其上接管）
        onWillDismiss: (action) => { ... },                  // 关闭/返回唯一拦截点
        onDisappear: () => { ... },
      })

  @Builder sheetBuilder():
    Stack({ alignContent: Alignment.Top }) {   // ← 关键：标题带叠在内容之上
      this.content()                           //   内容视口因此升到面板顶
      if (sheetTitle.length > 0 || showBack) {
        this.sheetHeader()                     //   标题带浮层
      }
    }
    .width('100%')
    .clip(true)        // ⚠️ Stack 默认不裁子组件：渐变底会延伸到面板圆角外 ⇒ 四角"方角透出"

  @Builder sheetHeader():                      // 标题行 64 + Blank() 撑到 SHEET_HEADER_BAND_VP，再挂渐变底
```

### 标题行对齐（必须与系统关闭按钮同线）
- 左缘 = `PANEL_PAD_H`（16，与内容同左缘）；
- 垂直 = 标题带（`SHEET_TITLE_AREA_VP = 64`）居中后**再整体下沉 `SHEET_TITLE_ROW_DROP_VP`(6)**；
- 标题 `maxLines(1)` + 右侧避让 `+32vp`（系统关闭按钮在右上角，不在浮层内）；
- ⚠️ 浮层带高（`SHEET_HEADER_BAND_VP`）变化**只加/减"渐隐余量"，不挪标题** ——
  标题文字恒居中于 `SHEET_TITLE_AREA_VP(64)` 行 **+ 整行下沉量**。
  ⚠️ 且带高**不得超过内容静止起点**（见「浮层底色带长」一节），否则会压暗静止内容。
- **返回按钮**（有层级时）：见第八节 —— 必须做成**圆形光感按钮**，命中块 40×40 固定在**同一行**内居中
  （块心 = 行心，整行下沉后与右上角关闭按钮同心）。

#### ⚠️ 垂直位置：自绘侧（标题 + 返回按钮）必须整行一起下沉 6vp

**行心 ≠ 关闭按钮圆心。** 实测（本项目真机逐像素比对）：
系统关闭按钮圆心落在**面板顶 +38**，而 64vp 标题行的行心在**面板顶 +32** ⇒ **自绘的两个元素整体偏高 6vp**。

用户原话分两步给出，第二步是关键：
> 「返回按钮整体来说基本对 但是要**稍微下来 6vp**试试 然后**有返回按钮存在的话 标题需要右移一点距离**吧」
> 「等下 那要这么说 其实**标题也没有和关闭按钮居中对齐** 因为我看**返回按钮和标题是居中对齐了**
> 所以**标题也一起下沉**一下看看效果」

⇒ **标题与返回按钮在同一行 ⇒ 它们同一条中线 ⇒ 要偏就是一起偏。** 只挪按钮会让按钮与标题**错开**
（比"整体偏高"更糟）。**正解 = 整行一起下沉。**

做法（浮层 `Column` 上）：
```ts
export const SHEET_TITLE_ROW_DROP_VP = 6;

Column() {
  Row() { /* 返回按钮? + 标题 */ }.height(SHEET_TITLE_AREA_VP)   // 行仍 64
  Blank()
}
.width('100%')
.height(SHEET_HEADER_BAND_VP)
.padding({ top: SHEET_TITLE_ROW_DROP_VP })      // ← 整行下沉
.linearGradient({ angle: 180, colors: titleBandStops() })
```

⚠️ **为什么用 `padding.top` 而不是 `offset` / 负 `margin`**：
ArkUI 的 `.height()` **包含 padding**（border-box）⇒ 带总高仍是 `SHEET_HEADER_BAND_VP`，
**渐变档位（位置是比例）与内容层顶部留白一律不用动，零连锁**。
`offset` 是**绘制位移**（命中区是否跟随需另证）；负 `margin` 会把行顶探出浮层顶、靠 `.clip(true)` 勉强裁住。
⚠️ **只影响窄屏自绘浮层**：宽屏 dialog 无系统关闭按钮，其标题行与返回按钮同行居中即自洽，**不加**下沉。

### 浮层手势必须穿透
```
.hitTestBehavior(HitTestMode.None)
```
`HitTestMode.None` 的**准确语义**（`enums.d.ts`）：*「**节点自身**不响应命中，**且不阻断子节点/兄弟/祖先**的命中」*
⇒ 浮层内**子组件自己**仍可点（返回按钮的 `onClick` 正常工作），而浮层的空白/标题文字**不挡下层滚动** —— 两者要的效果正好同时成立。
（整树禁用的语义是 `BLOCK_HIERARCHY`，别混用。）

## 三、内容容器（SheetContainer）

职责**只有两件**：① 内容滚动（唯一 `Scroll`）② 四周留白。**标题不归它管。**

```ts
Column() {
  Scroll() {
    Column() { this.content() }
      .width('100%')
      .padding(this.contentPad())     // ← 四周留白全在内容层
  }
  .width('100%')
  .height(this.windowIsLandscape ? '100%' : 'auto')     // ← 结论 5
  .constraintSize({ maxHeight: this.contentMax() })
  .scrollBar(BarState.Off)
  .contentEndOffset(this.endFill())                     // ← 让内容能滚进标题带（见下）
  .edgeEffect(EdgeEffect.Spring)                        // ⚠️ 不要 EdgeEffect.None
  .linearGradientBlur(SHEET_BLUR_RADIUS, {
    fractionStops: blurStops(this.viewportH),           // ← 用实测视口高换算
    direction: GradientDirection.Bottom,                //   Bottom = 档位 0 在视口顶部
  })
  .onAreaChange((_oldV: Area, newV: Area) => {          // ← 实测视口高
    const h = Math.round(Number(newV.height));
    if (h > 0 && h !== this.viewportH) this.viewportH = h;   // 只在跨整数 vp 时赋值
  })
}
.width('100%')
.constraintSize({ maxHeight: sheetPanelMaxHeight(...) })  // 面板可视高上限
.padding({ bottom: PANEL_PAD_V })                         // ⚠️ 只留下 padding，上留白下放
.backgroundColor(Color.Transparent)                       // ⚠️ 绝不能自带底色
```

### ⚠️ 内容"滚不到弹窗顶部"：顶部留白吃掉了滚动行程（2026-10-02 补）

**现象**（用户原话）：「我感觉内容往上滚动的话 **还是无法到达弹窗的顶部最边缘 明显差了一点距离**」。

**根因**：`可滚动范围 = 内容高 − 视口高`，这是滚动行程的**唯一来源**。而顶部留白
（`SHEET_TITLE_AREA_VP + PANEL_PAD_V` = 76vp）是加在**内容层**上的 ⇒ **它属于内容** ⇒
把那 76vp 行程一并吃掉了：内容最多只能滚到"留白下沿"，面板顶部那 76vp **恒空**
⇒ `linearGradientBlur` 的最强档永远压不到任何内容上（"糊不到顶"的老毛病回来了，
只是这次不是视口的问题，是**行程**的问题）。

**解法 = 终点偏移**（`ScrollableCommonMethod.contentEndOffset`，@since 22；`List` 从 11 起也支持）：

```ts
/// 滚动终点补偿：只补"超出视口的那部分"到 SHEET_TITLE_SCROLL_OFFSET(76)
private endFill(): number {
  if (!this.contentTopPad) return 0;
  if (this.viewportH <= 0 || this.contentH <= 0) return 0;  // 首帧兜底，别用 0 高算出满额偏移
  const away = this.contentH - this.viewportH;              // 现有行程
  if (away <= 0) return 0;                                  // ← 关键，见下
  const fill = SHEET_TITLE_SCROLL_OFFSET - away;
  return fill > 0 ? fill : 0;
}
```

- ⚠️ **`away ≤ 0`（内容没超出视口）必须返回 0**，不能"补满 76"：那种情况内容本就完整可见、
  无需滚动；更糟的是竖屏 Scroll 是 `height('auto')`，若偏移被算进布局高，面板会凭空高出
  76vp ⇒ **直接破坏"跟随内容"**。只对**已经溢出**（面板已顶到上限）的弹窗补偏移。
- ⚠️ **不要同时给 `contentStartOffset`**：官方语义（`list.d.ts` 原文）是
  `contentStartOffset + contentEndOffset` 一旦**超过内容区长度就双双归零**，而矮内容恒会触发
  ⇒ 偏移静默失效。内容层的顶部 `padding` 已经充当了"起始偏移"，只差终点这一个。
- ⚠️ 必须实测**内容盒高**（`onAreaChange` 在内容 `Column` 上）与**视口高**（在 `Scroll` 上）
  两个值，别用 `contentMax()` 去推（视口高 = `min(内容高, 上限)`）。

**另一条路（内容自带滚动器时更干净）：`contentTopPad = false`。**
若内容本身就是一个占满面板的 `List`（如播放队列），让容器**不再加顶部留白**，留白改由
那个 `List` 的**首个 spacer item** 承担 —— spacer 是 item、能被完整滚出视野，天然可滚进标题带：
```ts
List() {
  ListItem() { Blank().height(SHEET_TITLE_SCROLL_OFFSET) }   // ← 留白做进列表的第一项
  LazyForEach(...)
}
.height(listHeight())
```
⚠️ 用这条路时 `ScrollToIndex` 的索引要 +1（spacer 占了 `[0]`）。

### 为什么四周留白必须放在「内容层」而不是「面板层」
Scroll 视口 = **面板整宽 + 面板整高** ⇒ 两个收益：
1. **横向**：浮动件（搜索胶囊、带材质的卡片）的**外阴影/光感**有余量可落，不再被视口边缘裁掉；
2. **纵向**：视口顶 = **面板顶** ⇒ `linearGradientBlur` 的**最强档正好压在面板顶边**（用户原话「无法完全到弹窗的顶部边缘」）。
   旧版面板层留 `PANEL_PAD_V(12)` 上白 ⇒ 顶部那道 12vp 恒清晰，模糊"差一口气到顶"。

内容层 padding：
```ts
{ left: PANEL_PAD_H + safeAreaLeft, right: PANEL_PAD_H + safeAreaRight,
  top: SHEET_TITLE_AREA_VP + PANEL_PAD_V, bottom: CONTENT_BOTTOM_PAD }
```
- ⚠️ **不用 `Blank()` 垫空块**：Blank 在主轴方向带 `flexGrow` 语义，在「高度由内容决定」的 Column 里可能反过来把**矮内容撑到视口高**，破坏"跟随内容"。
- ⚠️ **禁「内缩卡片式」写法**（`.width('100%')` + 左右 `margin`）：百分比按父级**内容宽**解析、margin 在外叠加 ⇒ 真宽 = 100% + 32vp **溢出父级**，内缩全部失效、贴死面板两边。

### 去卡片化（同步的重要前提）
弹出面板 = **面板底**（宿主 `backgroundColor` + `systemMaterial('sheet')` 提供）+ **一个 Scroll** + 内容 padding，**没有卡片层**。
- 内容自带底色/卡片会把**面板材质盖死**，标题区与内容区观感分叉；
- 「卡片途中突然出现一个浮层」在滚动手感上是两层容器；
- ⚠️ **去卡片化后，各弹窗行内为「卡片内缩」加的 `padding({left:16,right:16})` 必须清零**，否则与内容层的 `PANEL_PAD_H(16)` 叠成 32vp。

## 四、标题边缘渐变模糊（核心调参）

### 半径
```ts
export const SHEET_BLUR_RADIUS = 64;   // px！不是 vp（结论 3）
```

### 带长（vp）—— 高弹窗封顶、矮弹窗按比例收缩
```ts
const SHEET_BLUR_BAND_VP = 96;         // 高弹窗封顶
const SHEET_BLUR_BAND_RATIO = 0.42;    // 矮弹窗按视口占比收缩

export function blurBandVp(componentHeight: number): number {
  if (componentHeight <= 0) return SHEET_TITLE_AREA_VP;      // 首帧兜底
  let band = componentHeight * SHEET_BLUR_BAND_RATIO;
  if (band > SHEET_BLUR_BAND_VP) band = SHEET_BLUR_BAND_VP;
  if (band < SHEET_TITLE_AREA_VP) band = SHEET_TITLE_AREA_VP;
  return band;
}
```
⚠️ **带长必须 ≤ 内容静止留白**（`SHEET_TITLE_AREA_VP + PANEL_PAD_V` = 76vp），否则弹窗刚打开、内容还没滚动时，**首行内容就已经落在模糊带里被糊住**（观感 = 内容发虚、读不清）。
高弹窗封顶 96 时首行位于 79% 处、强度已 ≈0；矮弹窗（视口小）再按 0.42 收缩。

### ⚠️ 浮层底色带长同样必须 ≤ 内容静止留白（2026-10-02 补，踩过反例）
**同一条约束也适用于「标题浮层那条渐变底色带」，而且是更硬的一条** —— 因为**底色本身就盖内容**，
不像模糊只影响观感清晰度。

**反例**（本项目真实走过）：为了「范围更大」把浮层带拉到 **120vp**，比内容静止起点（76vp）多 44vp
⇒ 弹窗**完全不滚动的初始状态**下，内容首行已经在带内：76vp 处底色 alpha 尚 ≈49%，
**顶部卡片被压暗近三成**。用户原话：*「我非滚动状态下 媒体信息的卡片都被模糊的渐变影响到了」*。

**正解**：浮层带高 = **内容静止起点本身**（`SHEET_TITLE_AREA_VP + PANEL_PAD_V`），
并让渐变档位在此前就归零：

```ts
export const SHEET_CONTENT_TOP_VP = SHEET_TITLE_AREA_VP + PANEL_PAD_V;  // 与内容层 padding({top}) 同源
export const SHEET_HEADER_BAND_VP = SHEET_CONTENT_TOP_VP;               // 浮层只画到内容起点

// 档位：透明段整体前移，在内容出现前收干净（位置是比例！带变矮必须同步重排）
[[`#FF${rgb}`, 0], [`#FF${rgb}`, 0.2], [`#E6${rgb}`, 0.36], [`#A8${rgb}`, 0.5],
 [`#5C${rgb}`, 0.62], [`#2E${rgb}`, 0.72], [`#00${rgb}`, 0.78], [`#00${rgb}`, 1]]
//   0.5(38vp) → 0.62(47vp) → 0.72(55vp) → 0.78(59vp) 起全透 ⇒ 内容首行(76vp)处零压暗
```

⚠️ **缩带必须同步重排档位**：位置档是**比例**，沿用长带那组会把不透明段同比压扁、
而且原本落在缓冲区里的档位会整体前移——**看起来改了、其实静止时依然盖着内容**。

⚠️ **代价与补救方向**：带长 = 内容起点后，"纯渐隐缓冲区"只剩 76−64 = 12vp，过渡更紧。
但视觉上仍读不出硬边 —— 真正的柔化靠 `linearGradientBlur` 作用在**滚动内容**上
（滚动时内容穿进标题带被逐档糊掉），底色带只承担"标题文字背板"，不需要长尾。
⇒ 若真机觉得标题下沿偏生硬，**优先加长模糊带，不要再拉长底色带**（拉长必然压回内容，就是这次修掉的问题）。

### 档位曲线（9 档，导出给自管布局的弹窗复用）

⚠️ **命名口径**：参考实现里函数体叫 `blurStops(componentHeight)`（文件内私有，供 `SheetContainer`
自身的 `Scroll` 用）；**对外必须再导出一个别名 `blurStopsFor()`
（= 直接转发 `blurStops`）**，给**自己管布局、不走 `SheetContainer`** 的弹窗复用
（本仓 = `DownloadImportSheet` 那份 320 高的 `List`）。
⇒ 调用点：容器内用 `blurStops`、容器外用 `blurStopsFor`，**别只导出一个、也别各写一份**。
```ts
const blur: number[] = [1, 1, 0.9, 0.68, 0.44, 0.22, 0.06, 0.015, 0];
const frac: number[] = [0, 0.16, 0.28, 0.4, 0.52, 0.64, 0.76, 0.88, 1];

function blurStops(componentHeight: number): FractionStop[] {
  const h = componentHeight > 0 ? componentHeight : SHEET_BLUR_BAND_VP * 2;  // 首帧兜底
  let band = blurBandVp(componentHeight) / h;
  if (band > 1) band = 1;
  const stops: FractionStop[] = [];
  for (let i = 0; i < frac.length; i++) {
    let p = band * frac[i];
    if (p > 1) p = 1;
    stops.push([blur[i], p]);
  }
  return stops;
}
```
曲线语义 = 「顶部恒定全糊 → 中段快衰减 → 尾部务必收到 0」。
- 尾部（0.76 / 0.88 处 ≈ 0.06 / 0.015）正好压在**内容静止留白**（76/96 ≈ 0.79）附近 ⇒ 弹窗打开时首行几乎无残余模糊，而滚动时 0~50% 区间（强度 ≥ 0.44）糊得明显。

### 四条铁律
1. **位置档必须严格递增、数组 ≥2 项**；首帧视口高未上报（0）时必须兜底，否则报"位置非递增"。
2. **档位位置是「组件高的比例」（0~1）**，而 Hds 用的是 vp 偏移 ⇒ **必须用 `onAreaChange` 实测 Scroll 视口高再换算**，否则矮弹窗的模糊带会等比缩窄（观感与高弹窗不一致）。
3. ⚠️ **本接口会受 `BlendApplyType.OFFSCREEN` 的 `blendMode` 干扰**（`common.d.ts`：OFFSCREEN 下 "may cause issues with screen capture for APIs such as linearGradientBlur"）⇒ 本链路上**不要**给 Scroll / 内容加 OFFSCREEN 的 blendMode。
4. ⚠️ 更高层的 `ScrollEffectOptions`（`navigation.d.ts` / Hds `ScrollEffectType.GRADIENT_BLUR`）**只能挂在 Navigation / NavDestination 标题栏上**，`bindSheet` 挂不上 ⇒ 只能把底层属性下放到**内容层**。

### 性能
GPU 模糊，作用在滚动列表上**每帧重采样**。若真机滚动掉帧：优先调小 `SHEET_BLUR_RADIUS`；仍不足则缩短 `SHEET_BLUR_BAND_VP`。

## 五、标题带底色渐隐（浮层侧）

```ts
@Builder sheetHeader() {
  Column() {
    Row() { /* 返回按钮 + 标题 */ }
      .width('100%')
      .height(SHEET_TITLE_AREA_VP)              // 64：标题行
      .padding({ left: PANEL_PAD_H, right: PANEL_PAD_H + 32 })
      .alignItems(VerticalAlign.Center)
    Blank()                                     // 余下高度 = 渐隐缓冲（76 − 64 = 12vp，见第四节的硬约束）
  }
  .width('100%')
  .height(SHEET_HEADER_BAND_VP)                 // = SHEET_CONTENT_TOP_VP（64 + 12 = 76）
  .linearGradient({ angle: 180, colors: this.titleBandStops() })
  .hitTestBehavior(HitTestMode.None)
}

private titleBandStops(): [ResourceColor, number][] {
  // ⚠️ 基色 = **面板的实际观感底色**，不是 opaqueBackground（见下）
  const rgb: string = SettingsManager.sheetSurfaceColor().substring(1);
  return [
    [`#FF${rgb}`, 0],
    [`#FF${rgb}`, 0.2],
    [`#E6${rgb}`, 0.36],
    [`#A8${rgb}`, 0.5],
    [`#5C${rgb}`, 0.62],
    [`#2E${rgb}`, 0.72],
    [`#00${rgb}`, 0.78],
    [`#00${rgb}`, 1],
  ];
}

/// ⚠️ 面板底色有**两层**：bindSheet 的 backgroundColor + systemMaterial('sheet')。
/// 材质是**半透**的（深色 `#6B000000` 42% 黑）且**视觉层级高于 backgroundColor**
/// ⇒ 面板实际 =「42% 黑 + 模糊采样到的背后画面」，**比纯黑亮**。
/// 浮层若按 opaqueBackground（深色 `#010101` 纯黑）画底色 ⇒ 标题带比弹窗**更黑**，
/// 用户读作「**深色模式下 我怎么感觉你是加了一个纯黑的渐变？弹窗不是这个颜色啊**」。
/// ⇒ 材质生效时取 `colors.surface`（深色 `#191919` / 浅色 `#FFFFFF`，正是灰阶里"比页面亮一档"那级）；
///   材质不可用（API<26，面板就是 opaqueBackground 实色）时必须回退 opaqueBackground。
/// ⚠️ **落位**：本方法自 2026-10-03（第十四轮 `a49e7f4`）**引入即在** `SettingsManager`
///   —— 因为它是「弹窗面板观感底色」这类**跨组件口径**，不属于任何单个弹窗组件；
///   目前唯一消费者是 `AppSheet.titleBandStops()`（窄屏浮层标题带渐变基色）。
///   **判据**：口径若会被两个以上地方用到、或语义上不属于某个组件 ⇒ 一律放服务层/管理器，别塞进组件私有方法。

// SettingsManager.ets
static sheetSurfaceColor(): string {
  if (!SettingsManager.materialAvailable()) return ThemeManager.opaqueBackground;
  return ThemeManager.colors.surface;
}
```

四条要点：
1. **多档曲线（7 档），不要两/三档折线** —— 折线在档位之间仍是**线性突变**，多档逼近曲线后肉眼才看不出分段。
2. ⚠️ 位置档 **0 / .2 / .36 / .5 / .62 / .72 / .78 / 1** 用的**比例区间要与内容层 `blurStops()` 的模糊衰减对齐**（同一组 0~1 节奏），两边**各自逐档归零**：本带在 0.78（≈59vp）处已全透，模糊在 96vp 处收到 0 ⇒ 内容起点（76vp）到带尾这段是"无底色 + 模糊已极弱"的收尾区，**没有台阶**。
   ⚠️ 带长从 120 收到 76 时**档位必须同步重排**（位置是比例，沿用长带那组会把不透明段同比压扁）。
3. ⚠️ 透明档**必须保持同一 RGB**（只降 alpha）—— 混色会重新"变实"、把模糊感压掉。
4. ⚠️ **基色必须取"面板观感底色"，不能硬取 `opaqueBackground`** —— 面板叠了半透材质后比纯色亮一档，浮层按纯色画会表现为"**贴了一条纯黑渐变**"（深色模式尤其明显）。见上面 `sheetSurfaceColor()`。
5. ⚠️ **绝不加 `backgroundBlurStyle`** —— 普通模糊会在透明处叠灰度，出现"自带了白色"。
6. ⚠️ 透明色必须写 **ARGB `#AARRGGBB`**（ArkUI 的 ResourceColor 十六进制是 ARGB，不是 `#RRGGBBAA`）。
7. **不含底缘发丝线** —— 用户明确说「标题区域下面要加分割线 不需要」。

### 浮层带长与模糊带长「解耦但无硬切割」
- 浮层带 = `SHEET_HEADER_BAND_VP`（= `SHEET_CONTENT_TOP_VP` = 76vp，**被内容静止留白硬钉死**）；模糊带 = 96vp（可调）。两者**不必相等**。
- 内容起点（76vp）到模糊带尾（96vp）这 20vp 是"无底色 + 模糊已≈0"的收尾区；
- 硬边来自"某处强度/颜色**突变**"，两者各自的归零点都是**逐档渐进**的 ⇒ 这段只有"由虚转实"，**没有台阶**。
- ⚠️ 想让过渡更长时**只动模糊带**：底色带长度上限是内容起点，拉长必然在静止状态压暗内容（第四节反例）。

## 六、横竖屏高度口径（用户明确点名的部分）

### 面板高度上限 = `min(比例值, 窗口净空)`
```ts
const PANEL_RATIO_PORTRAIT = 0.75;
const PANEL_RATIO_LANDSCAPE = 0.55;
const MIN_PANEL_HEIGHT = 180;

export function sheetPanelMaxHeight(windowHeight: number, windowIsLandscape: boolean,
  safeAreaBottom: number, bottomSpace: number): number {
  const h = windowHeight > 0 ? windowHeight : 600;
  const ratio = windowIsLandscape ? PANEL_RATIO_LANDSCAPE : PANEL_RATIO_PORTRAIT;
  const byRatio = h * ratio;
  const chrome = safeAreaBottom + bottomSpace;
  const available = h - chrome;
  const cap = available > 0 ? Math.min(byRatio, available) : byRatio;
  const floor = Math.min(MIN_PANEL_HEIGHT, available > 0 ? available : MIN_PANEL_HEIGHT);
  return cap < floor ? floor : cap;
}
```
- 比例值本身也可能**超出可用空间**（小屏 / 横屏 / 分屏 / 平板悬浮窗必现）⇒ 必须与**净空**取较小者；
- `bottomSpace` = 面板外还挂了底栏时（如「知道了」按钮条）传它的高度，否则底栏会被顶出屏幕；
- ⚠️ **不扣 `SHEET_TITLE_AREA_VP`** —— 标题已改自绘浮层，浮层**不占布局高度**（内容视口 = 面板整高），没有"同级占位区域"要扣了。
- ⚠️ 真机若观感偏太高/偏矮，**只调 `PANEL_RATIO_LANDSCAPE` / `PANEL_RATIO_PORTRAIT`**。

### 两处口径必须同步
`AppSheet.detents = [SheetSize.FIT_CONTENT, SheetSize.LARGE]` ↔ 内容层 `height(auto)` + `constraintSize(maxHeight)`。
**两者是同一口径的两半**，只改一边会出现"面板高但内容塌"或反之。

### 不要用 `layoutWeight(1)` 撑满
底栏是 `SheetContainer` 的**兄弟节点**，flex 方案要求调用方给容器加 `layoutWeight(1)`（几十个调用点全改）且依赖"bindSheet 百分比有确定参照"这一**未验证前提**。显式上限 + `bottomSpace` 记账已在真机跑通多轮。

## 七、宽屏判定：按「窗口短边」≥600vp

```ts
const WIDE_SCREEN_SHORT_SIDE_MIN = 600;

private isWideScreen(): boolean {
  // 平板/二合一按设备类型（会话内恒定）
  if (!wideDeviceKnown) {
    wideDeviceKnown = true;
    try { const t = deviceInfo.deviceType; wideDeviceValue = (t === 'tablet' || t === '2in1'); }
    catch (_) { wideDeviceValue = false; }
  }
  if (wideDeviceValue) return true;
  // 手机/折叠屏按「窗口短边」
  const key = AppStorage.get<number>('windowWidth') ?? -1;
  if (wideCachedValid && wideCachedKey === key) return wideCachedValue;
  let v = false;
  const w = AppStorage.get<number>('windowWidth') ?? 0;
  const h = AppStorage.get<number>('windowHeight') ?? 0;
  if (w > 0 && h > 0) v = (w < h ? w : h) >= WIDE_SCREEN_SHORT_SIDE_MIN;
  wideCachedValid = true; wideCachedKey = key; wideCachedValue = v;
  return v;
}
```

### 为什么不用 `display.getDefaultDisplaySync().width`
`display.width` 是**屏幕当前方向**的宽 —— 手机**横屏**时随旋转变成 ~744vp ⇒ `>=600` 成立 ⇒ **手机被误判成平板**。
| 场景 | 窗口 | 短边 | 判定 |
|---|---|---|---|
| 手机竖屏 | 440×744 | 440 | 窄屏 ✓ |
| 手机横屏 | 744×440 | **440** | 窄屏 ✓（旧实现误判宽屏 ✗） |
| 展开态折叠屏 | 939×664 | 664 | 宽屏 ✓ |
| 分屏窄窗 | 400×700 | 400 | 窄屏 ✓ |

- 取值 600 = Hds 官方 `HdsBarWidthRangeOptions` 的 small↔medium 断点（`<600` / `>=600` 是两套布局行为）；
- ⚠️ 数据源用 **AppStorage 的 windowWidth/windowHeight**（由 App 广播）—— 旋转实时、**无同步 IPC**；
- ⚠️ 窗口未就绪（0）时**保守判窄屏**（bindSheet 是默认形态，不会闪成居中 dialog）；
- ⚠️ **性能**：本方法在**每个 AppSheet 的 build 里**被调用，而列表**每一行都可能挂一个 AppSheet** ⇒ 一个 20 行页面 = 40+ 次判定，全部集中在首次构建那一帧（切 tab / 进详情页掉帧来源之一）⇒ 设备类型缓存一次 + 判定结果按 `windowWidth` 失效键缓存。

### 宽屏链路可能的连带缺陷：「白面板 + 黑卡片」
宽屏走 `promptAction.openCustomDialog`（窗口级居中），若其 `backgroundColor: Color.Transparent`：
`systemMaterial('sheet')` 是**半透**材质（浅色档 ≈42% 白）⇒ 材质之下再无底色 ⇒ 模糊采样到的是 `maskColor '#66000000'`（暗蒙层）+ 背后页面，整体**压暗**；其上卡片再叠一层材质时同样采样到黑蒙层 ⇒ 真机表现即「**白色弹窗里面有黑色的卡片**」。
**修法**：`backgroundColor: ThemeManager.opaqueBackground`，与窄屏 `bindSheet` **完全同口径**（ENABLE 模式下材质优先级高于 backgroundColor，不透明底只在 API<26 / 材质不可用时露出）。

## 八、关闭 / 返回的唯一拦截点：`onWillDismiss`

```ts
onWillDismiss: (action: DismissSheetAction) => {
  // 有视图层级且当前确实能返回 → 吞掉本次返回，只退视图（不 dismiss）
  if (this.showBack && action.reason === DismissReason.PRESS_BACK) {
    this.onBack();
    return;
  }
  if (this.dismissible) {
    this.close();
    action.dismiss();      // ← 不调用 dismiss() = 不关闭（系统不会替你关）
  }
}
```

⚠️ **用 `onWillDismiss` 而不是 `shouldDismiss`**（官方 `common.d.ts` 查实）：
- `shouldDismiss?: (sheetDismiss: SheetDismiss) => void`（@since 11）—— 只有 `dismiss()`、**拿不到关闭原因**，无法区分"返回"与"下滑/点蒙层"；
- `onWillDismiss?: Callback<DismissSheetAction>`（@since 12）—— `action.reason: DismissReason` **才带原因**；
- ⇒ **只注册 `onWillDismiss`，不再注册 `shouldDismiss`**（避免两者同时生效）。

⚠️ `DismissReason.PRESS_BACK = 0` 官方注释：*「Touching the **Back** button, swiping left or right on the screen, or pressing the **Esc** key」*
⇒ **返回键 + 返回手势 + ESC 三者同归 `PRESS_BACK`**，正是要拦的那一种；
而下滑（`SLIDE_DOWN`）/ 点蒙层（`TOUCH_OUTSIDE`）/ 关闭按钮（`CLOSE_BUTTON`）**一律保持正常关闭**（用户点关闭按钮/点蒙层的意图就是"关掉"）。

⚠️ 宽屏 `DismissDialogAction.reason` 同样是 `DismissReason` ⇒ 两条链路同一套判据。

### 返回按钮 =「圆形 + 光感」，与关闭按钮同心
```ts
export const SHEET_BACK_BTN_SIZE = 40;   // 命中块 = 光感底盘直径（圆角 = 直径/2）
export const SHEET_BACK_ICON_SIZE = 24;  // chevron_left 字号
export const SHEET_BACK_TITLE_GAP = 8;   // 按钮右缘 → 标题左缘（有返回按钮时"标题右移"）
export const SHEET_TITLE_ROW_DROP_VP = 6; // 整行下沉，见第二节

if (this.showBack) {
  Stack() {
    MaterialLayer({                      // ← 宿主项目的"光感承载层"（Toggle 绕过法）
      layerRadius: SHEET_BACK_BTN_SIZE / 2,
      scope: 'menu',                     // 压在同材质的**面板**上，取厚档才读得出按钮形态
      active: materialAvailable(),
    })
    SymbolGlyph($r('sys.symbol.chevron_left'))
      .fontSize(SHEET_BACK_ICON_SIZE)
      .fontColor([ThemeManager.colors.textPrimary])
  }
  .width(SHEET_BACK_BTN_SIZE)
  .height(SHEET_BACK_BTN_SIZE)
  .borderRadius(SHEET_BACK_BTN_SIZE / 2)
  .clip(true)                            // ⚠️ 承载层圆角外是直角，不裁会露方角
  .backgroundColor(materialOn() ? Color.Transparent : (isDark ? '#33000000' : '#33FFFFFF'))
  .backgroundBlurStyle(materialOn() ? BlurStyle.NONE : BlurStyle.COMPONENT_REGULAR, {
    adaptiveColor: AdaptiveColor.AVERAGE, colorMode: ThemeColorMode.SYSTEM,
  } as BackgroundBlurStyleOptions)
  .border({ width: materialOn() ? 0 : 0.5, color: divider })   // 材质自带边界感 ⇒ 不叠描边
  .margin({ right: SHEET_BACK_TITLE_GAP })
  .onClick(() => { this.onBack(); })
}
```
- **为什么必须"有形态"**：右上角关闭按钮是**带圆形背板**的；自绘侧若只放一个裸 chevron，
  两个按钮就不像一套（用户原话「**没有和关闭按钮垂直居中** 和**做光感按钮效果** **大小尺寸也注意对齐**」）。
- **`scope` 怎么选**：本按钮压在**同样有材质的面板**上 ⇒ 用厚档（本仓 `'menu'`）；
  若宿主里那档在深色下与面板几乎同色、按钮"消失"，才改薄档（`'system'`）。**只调这一处**。
- ⚠️ **垂直居中靠"行对齐 + 整行下沉"，不要靠 margin 微调**：命中块固定 40×40，行高 `SHEET_TITLE_AREA_VP(64)`
  且 `Row.alignItems(VerticalAlign.Center)` ⇒ 块心 = 行心。
  ⚠️ **但行心 ≠ 关闭按钮圆心**：实测关闭按钮圆心在**面板顶 +38**、64 行行心在 **+32** ⇒ 必须给浮层 `Column`
  加 `.padding({top: SHEET_TITLE_ROW_DROP_VP(6)})` **整行下沉**（`.height()` 含 padding ⇒ 带高不变、零连锁）。
  ⚠️ **标题与返回按钮在同一行 ⇒ 一起偏高 ⇒ 必须一起下沉**；只挪按钮会让两者错开。详见第二节。
  （扁块 `40 × 行高` 圆心也对，但看不出对齐——因为没有形态可比。）
- ⚠️ **有返回按钮时标题要"右移"**：**不要**给标题加 `margin.left` —— 它是 `layoutWeight(1)`，
  左缘由前一个兄弟（返回按钮）的右缘决定；加 `margin` 只会让文字在剩余宽度里偏移、与"左对齐"语义打架，
  且会让**长标题的省略号提前出现**。用户真正感知的是"标题贴着返回按钮太近" ⇒ 调**这一处间距**
  `SHEET_BACK_TITLE_GAP(8)`，观感上就是"标题被让开了"。
- ⚠️ **窄屏/宽屏都用同一组常量**（含 `SHEET_BACK_TITLE_GAP`），否则同一个按钮在两处观感分叉。
- 返回按钮**替代**标题的左留白（而不是挤在标题前面）；块内图标居中 ⇒ 图标左缘
  = `PANEL_PAD_H + (40−24)/2` = 24。
- ⚠️ **不要用 `.padding()` 撑点击区**：padding 会把它**推出**标题行（用 `width/height`）。
- ⚠️ **窄屏与宽屏共用同一组常量**：宽屏 dialog 没有系统关闭按钮（退化为"和标题文字居中"），
  但尺寸/形态要一致，否则同一个按钮在手机/平板观感分叉。
- ⚠️ 调用方须**同时**把"当前能不能真的返回"喂进来（如 `canGoBack`）—— 否则在根视图上按返回会变成"**没反应**"（既不关弹窗也不退视图）。
- ⚠️ **`showBack` 为真时即使没标题也要画浮层**（否则有层级的弹窗会丢掉返回按钮）。

## 九、宿主关闭回调的竞态保护

```ts
onDisappear: () => {
  if (this.dismissible) {
    setTimeout(() => {
      if (!this.show) { this.show = false; this.onDismiss(); }
    }, 300) as number;          // 延迟同步：立即设会打断关闭动画 ⇒ "回弹一下才关"
  }
  // dismissible=false（外部信号驱动）：不在此设 show=false ——
  // false→true 重开时旧实例的关闭动画也会触发 onDisappear，若覆盖会把父信号误置 false
}
```
⚠️ 延迟期间若用户**已重新打开**弹窗（`show=true`），**不能再设 false**（否则刚重开的新弹窗被自动关闭 —— "短时间再次点击就自动关闭"的根因）。

### 退后台**不要**主动关弹窗
旧逻辑在 `onBackground` 里 `close()` ⇒ 触发 bindSheet 的关闭动画，而该动画发生在**应用已退到后台、窗口不可见**的时刻 ⇒ 系统未能完整执行「面板下滑 + 遮罩淡出」这套成对动作 ⇒ 回前台后**面板已消失、蒙层却残留**。
`bindSheet` 是**页面内浮层**，退后台时随窗口一起隐藏、回前台随窗口一起恢复 ⇒ 状态天然一致，**不需要也不应该**主动关闭。

## 十、弹窗管理架构（宿主收敛 + 互斥 + 触发信号）

> **长相之外的另一半。** 前九节解决"弹窗长什么样"；本节解决"弹窗**由谁承载、在哪触发、如何不打架**"。
> 弹窗数量上到十几个时，**架构问题会先于视觉问题爆发**（两层蒙层叠压、20 行列表 = 20 个宿主）。

### 10.1 一条硬约束：一个组件最多挂 1 个 `bindSheet`

ArkUI 中**一个组件链式绑定多个 `bindSheet` 会状态纠缠** —— 弹出动画被对方的 `onDisappear` 重置
⇒ 真机表现为**闪烁**。官方建议每个弹窗绑定在各自组件上。
⇒ 本仓 `PlayMediaSheetHost` / `PlayOutputSheetHost` / `ChangelogSheetHost` / `RedeemCodeSheetHost`
**全部是"一个组件只挂 1 个 bindSheet"**（文件头都写了这条铁律的出处）。

⚠️ 反过来说：**一个宿主可以承载多个面板**（如单宿主多面板的 `ReaderSheetHost`）——
那是**同一个** `bindSheet` 内部按状态切换 `@BuilderParam` 内容，**不是**多个 bindSheet。别混。

### 10.2 宿主收敛：从「每行一个宿主」到「每页一个宿主」

**反例**（本仓实测）：`MediaListTile` 每行内联 `AppSheet + MediaActionSheet`
⇒ 一个 20 行列表页 = **20 个弹窗宿主**，每个都要挂 2 个 `@StorageLink`（含 `appBackgrounded` / `importReopen`）
+ 一次 `SheetManager.register` + 一次**同步屏宽 IPC**，且全部压在"页面首建"那一帧
（诊断日志实测 `appsheet.init n=15`（详情页）/ `n=29`（媒体库），而同一时刻**最多只有 1 个弹窗会打开**）。

**方案 = 请求分发**（`MediaSheetManager`）：弹窗收敛为**每页一个** `MediaSheetHost`（挂在页面 build 顶层）；
行 / 格只发一个"打开请求"，由宿主按自己页面的状态渲染。宿主数 **N → 1**，页面改动 = 加一行。

```ts
export type MediaSheetRequest = (song, inPlaylist, playlistId, onDataChanged) => void;

export class MediaSheetManager {
  private static sinks: MediaSheetRequest[] = [];           // 按挂载顺序入栈
  static bind(fn: MediaSheetRequest): void { ... }          // 宿主挂载时登记
  /// ⚠️ 按**引用**删除而非 `pop()`：页面树整体重建（如媒体库 `.key()` 换主题色）时可能出现
  ///    「新宿主 aboutToAppear 早于旧宿主 aboutToDisappear」⇒ 按引用删除与顺序无关
  static unbind(fn: MediaSheetRequest): void { ... }
  /// 交给**栈顶**宿主（最后挂载 = 当前可见页面）；无宿主时**静默丢弃**（页面已退场，请求无意义）
  static open(song, inPlaylist, playlistId, onDataChanged): void { ... }
}
```

⚠️ **为什么不是"全局只挂一个"**：半模态 `bindSheet` 只能挂载在**当前页面的组件树内**
（本仓 `SearchPage` 早期实验结论：挂在 `NavDestination` 之外**弹不出来**）。
而详情页 / 媒体库都是 `NavDestination` ⇒ **宿主必须随页面走** ⇒ 多宿主并存时用**栈**决定由谁响应。
（例外：挂 Index 根的那些才是"全局唯一"宿主 —— `ImportSheetHost` / `ChangelogSheetHost`，
因为 Index 本身就是根页面，且它们由**全局信号**驱动。）

### 10.3 触发信号：`AppStorage` 计数器 + `@Watch` 消费

| 机制 | 场景 | 要点 |
|---|---|---|
| **计数器信号 +1** | 全局宿主由任意页面触发 | `ImportSheetManager.openPickFile()` / `openDownload()` 各自 `AppStorage.set(key, n + 1)`，宿主 `@Watch` 消费 |
| ⚠️ **两个独立键**，不是"一个信号 + 来源字段" | 同一入口有**两个来源** | AppStorage 写入与 `@Watch` 消费**不在同一帧** ⇒ 字段方式会读到被下一次点击覆盖后的值 ⇒ **来源串台** |
| `importReopen` 重建信号 | 系统选择器关闭后，宽屏 dialog 可能被系统顶掉 / 残留 | `importing` 值未变**不触发重建** ⇒ 另发 `importReopen` +1；宿主收到后**先关再开**（`setTimeout 120ms`，避免同帧关+开冲突） |

⚠️ **该用菜单而不是弹窗的场合**（本仓用户定案）：*「只做选项/入口的一律用 menu，复杂内容才用弹窗」*
—— 所以"来源选择"从弹窗**退回**成了标题栏「更多操作 → 导入音频」的二级菜单项，
弹窗只保留"下载文件夹多选确认"这种真需要内容承载的场景。**别为了统一而把菜单也做成弹窗。**

### 10.4 互斥：`SheetManager`（同一 group 自动关门）

**问题**：同页多弹窗叠加 ⇒ **两层蒙层叠压**（画面整体变暗、点蒙层要关两次）。

**方案**（借鉴 DialogHub 的弹窗栈思想，轻量落地）：`AppSheet` 把自己的关闭能力注册进一张**全局注册表**，
打开时**关掉同 group 的其他弹窗**。

```ts
export interface SheetEntry {
  id?: number;              // register 分配
  group: string;            // 互斥分组（空串 = 不参与互斥）
  dismissible: boolean;     // 是否可手动关闭
  close: () => void;        // AppSheet 注入：show = false + onDismiss
}

export class SheetManager {
  static register(e: SheetEntry): number { ... }   // AppSheet.aboutToAppear
  static unregister(id: number): void { ... }      // AppSheet.aboutToDisappear
  /// 互斥：只关**同 group** 且 `dismissible` 的（`exceptId` = 自己，正在打开不关自己）
  static closeGroup(group: string, exceptId: number): void { ... }
  static closeAll(): void { ... }                  // 退后台/页面销毁（⚠️ 本仓已改为不用，见下）
}
```

约定与要点：
- `group` 默认 `''` = **不参与互斥**（向后兼容；**嵌套弹窗**如 ConfirmSheet 嵌在 MediaActionSheet 内时
  留空/换组，**不会被外层误关** —— 这是刻意的安全默认值）；
- 用法口径：Index 根级弹窗 `group='index'`、页面级 `group='page:xxx'`、导入下载 `group='importDownload'`；
- **触发点两处都要**：`aboutToAppear`（初始就已显示时）+ `onShowChange`（show 变 true 时，@Watch 不回调初始值）；
- ⚠️ `closeGroup` **只关 `dismissible=true`** 的 —— 否则会把"导入进度"这种**不可手动关闭**的弹窗一起关掉；
- ⚠️ 别用"关掉所有弹窗"替代互斥：不同 group / 空 group **必须互不影响**。

⚠️ **`closeAll` 在本仓已不再用于退后台**（第九节"退后台不要主动关弹窗"的连带后果）：
旧设计是 `AppSheet` 监听 `appBackgrounded` 统一 `close()`，真机实测 ⇒
关闭动画发生在**窗口不可见**的时刻，系统未能完整执行「面板下滑 + 遮罩淡出」这对动作
⇒ 回前台**面板已消失、蒙层残留**。现改为**不动状态**（浮层随窗口隐藏/恢复，状态天然一致）。

### 10.5 宽屏**没有**系统关闭按钮 ⇒ `dialogBody()` 必须自绘等价标题行

窄屏 `bindSheet` 的关闭按钮由**平台渲染**（右上角固定位置，不受 `title` 影响）；
宽屏 `openCustomDialog` **没有该能力** ⇒ 宽屏链路必须**自绘标题行**（同左缘 / 同字号 / 同返回按钮规格）。

⚠️ 因此"标题与关闭按钮**同心**"这条在宽屏**退化为"与标题文字同行居中"**
（同一行 `alignItems(VerticalAlign.Center)` 即满足）——
**宽屏不加** `SHEET_TITLE_ROW_DROP_VP` 下沉（那 6vp 是专为对齐**系统关闭按钮**而测出来的）。

⚠️ 宽屏 `dialogBody` 的返回按钮**必须复用窄屏同一组常量 + 同款形态**
（`SHEET_BACK_BTN_SIZE` 圆形命中块 + 光感底盘 + 同字号图标 + `SHEET_BACK_TITLE_GAP`）——
曾出现过"窄屏 40×64 扁块、宽屏 40×40 方块、行左 padding 两套口径"⇒ 同一按钮在手机/平板**观感分叉**。

### 10.6 宿主一览（本仓六类，改造其它项目时按此分类）

| 宿主 | 挂载位置 | 驱动方式 |
|---|---|---|
| `MediaSheetHost` | **每页一个**（页面 build 顶层） | `MediaSheetManager.open()` → **栈顶**宿主 |
| `ImportSheetHost` | Index 根（全局唯一） | `ImportSheetManager` 两个计数器信号 |
| `ChangelogSheetHost` | Index 根 | `@StorageLink('changelogSheetShow')` —— 启动自动弹 与 关于页入口**共用同一实例**（不重复挂载） |
| `PlayMediaSheetHost` / `PlayOutputSheetHost` | 播放页 | `@Link show`（Index 控制）；**各自只挂 1 个** bindSheet |
| `RedeemCodeSheetHost` | — | 单 bindSheet |

## 十一、调用清单（改造一个项目的弹窗要动的地方）

1. **识别全部宿主链路** —— 常见有三条：① 通用 `AppSheet`（bindSheet）② 项目特有单宿主多面板（如 `ReaderSheetHost`）③ **历史遗留的手写 `bindSheet` 调用点**。第三条会因"标题上移到宿主浮层"而**丢标题** ⇒ 必须并入 `AppSheet`。
2. **历史遗留的「手写 overlay 面板」也要一并迁** —— `if (showXxx) { Column(){ #40000000 + justifyContent(End) } }` 这种不仅**无过场动画**，且标题原由 `SheetContainer` 画 ⇒ 去卡片化后**必然丢标题**。迁到宿主后进出场动画从"一帧硬切"变成系统半模态升降（**这是一个观感变更点，交付时要向用户说明**）。
3. **接口改造**：`SheetContainer({ title: ... })` → `SheetContainer()`；标题改由宿主 `sheetTitle` 传。
4. **原「副标题/扩展标题」（`titleExt`）** → 移到**内容层首行**（放标题行右侧会被系统关闭按钮遮挡）。
5. **批量清零行内横向 padding**（卡片时代为在卡片内缩加的）；保留 `TextInput` 自身内距与划选条/菜单栏等非弹窗 padding。
6. **底栏间距对齐**（`FOOTER_PADDING_TOP/BOTTOM`）—— 若两端项目历史值不同，这是**需要向用户确认的观感变更点**。
7. **宿主架构三件事**（第十节，弹窗数量 > 5 时必须做）：
   ① 查有没有"**每行内联 AppSheet**"——有就收敛成**每页一个宿主 + 请求分发**；
   ② 一组件挂多个 `bindSheet` 的拆成一组件一 bindSheet；
   ③ 同页多弹窗的接 `SheetManager` + `group` 互斥。
8. ⚠️ **菜单 vs 弹窗的边界**要按用户口径判：**"只做选项/入口的用 menu，复杂内容才用弹窗"** ——
   别把本该是 menu 的东西继续做成弹窗。

## 十二、坑位清单

| 坑 | 现象 | 解法 |
|---|---|---|
| 用 `SheetOptions.title` | 内容**穿不进**标题带、无法被模糊 | 改自绘浮层（结论 1） |
| 用 Hds `titleBar` | 标题与系统关闭按钮**不齐**；自带白底与面板灰底冲突 | 同上 |
| 用 `backdropBlur` 做标题带 | 「边缘明显能看出来**硬切割**」 | 改 `linearGradientBlur`（渐变模糊） |
| `linearGradientBlur` 半径按 vp 给（如 20） | 「**只是一个渐变的遮罩 没有模糊效果**」 | 半径是 **px**，给 64+ |
| 面板层留上 padding | 模糊「**无法完全到弹窗的顶部边缘**」 | 上留白下放到内容层 ⇒ 视口顶 = 面板顶 |
| 只下放留白、不给 `contentEndOffset` | 内容「**还是无法到达弹窗的顶部最边缘 明显差了一点距离**」（顶部那 76vp 恒空） | 终点偏移补足滚动行程（第三节） |
| 浮层底色取 `opaqueBackground`（纯黑） | 深色下「**我怎么感觉你是加了一个纯黑的渐变？弹窗不是这个颜色啊**」 | 取 `colors.surface`（材质生效时），不可用才回退（第五节） |
| 内容自带滚动器却仍让容器垫顶白 | 两层留白叠加 + 外层 Scroll 又吃掉一段行程 ⇒ 列表滚不到标题下 | 容器 `contentTopPad=false`，留白做进列表首个 spacer item（第三节） |
| 模糊带长 = 标题行高 | 「**范围也不够大**」 | 带长独立（96vp），与浮层带长解耦 |
| 模糊档位与底色档位不同组 | 硬切割**回归** | 两者用同一组位置档，带尾同时归零 |
| 底色透明档换 RGB | 混色"变实"、压掉模糊感 | 透明档只降 alpha、**保持同一 RGB** |
| 浮层加了 `backgroundBlurStyle` | 透明处叠灰度 ⇒「**自带了白色**」 | 绝不加 |
| 浮层没 `hitTestBehavior(None)` | 标题带**吃掉滚动** | `HitTestMode.None`（语义见第二节） |
| `Stack` 没 `.clip(true)` | 渐变底延伸到圆角外 ⇒ 四角"**方角透出**" | `.clip(true)` |
| 竖屏用 `height('100%')` | 矮弹窗被撑到 **440vp** | 竖屏 `'auto'`、横屏 `'100%'` |
| 用 `Blank()` 垫首部留白 | 矮内容被 `flexGrow` **撑到视口高** | 用 `padding` |
| 内缩卡片写法（`100%` + `margin`） | **溢出父级**、内缩全部失效 | 留白走 padding |
| 留下卡片时代的行内 padding | 与内容层 16 叠成 **32vp** | 批量清零 |
| 用 `display.width` 判宽屏 | 手机**横屏被误判成平板** | 按**窗口短边**（结论 6） |
| 宽屏 dialog `backgroundColor` 透明 | 「**白面板 + 黑卡片**」 | 改 `opaqueBackground` |
| 用 `shouldDismiss` | **拿不到关闭原因**，返回键分不出来 | 改 `onWillDismiss` |
| 返回按钮用 `.padding()` 撑命中区 | 被**推出**标题行 | 用 `width/height` 撑 |
| 返回按钮只放一个裸 chevron | 「**没有和关闭按钮垂直居中** 和**做光感按钮效果** **大小尺寸也注意对齐**」——与带圆形背板的关闭按钮**不像一套** | 做成圆形 + 光感按钮（结论 6.5、第八节） |
| 光感承载层外层没 `.clip(true)` | 底盘圆角外露出**方角** | `.clip(true)` |
| 光感承接层开了却在上面叠不透明底/模糊 | 材质被盖死 / 发灰 | 材质接管时底色透明、不叠 `backgroundBlurStyle` |
| 窄屏与宽屏各写一套返回按钮尺寸 | 同一按钮在手机/平板**观感分叉** | 尺寸导出成常量、两边共用 |
| 只把返回按钮下移、不动标题 | 按钮与标题**错开**（两者原本同一条中线） | **整行一起下沉** `SHEET_TITLE_ROW_DROP_VP`（浮层 `Column.padding.top`） |
| 返回按钮/标题与关闭按钮差 6vp | 「稍微下来 6vp」—— 行心 +32 vs 关闭按钮圆心 +38 | 同上；⚠️ 用 `padding.top` 不用 `offset`/负 margin（带高不变、档位零连锁） |
| 用 `margin.left` 让标题"右移" | 标题是 `layoutWeight(1)` ⇒ 文字在剩余宽度里偏移、长标题省略号提前出现 | 调**按钮右缘→标题左缘**间距 `SHEET_BACK_TITLE_GAP` |
| `showBack` 但没标题 | 有层级的弹窗**丢掉返回按钮** | 画浮层条件写 `title || showBack` |
| 退后台主动 `close()` | 回前台**面板没了蒙层还在** | 只记录、不动状态 |
| `EdgeEffect.None` | 内容不足一屏时**完全不动**，用户读作"不能滚动" | `EdgeEffect.Spring` |
| 一个组件链式挂多个 `bindSheet` | 弹出动画被对方 `onDisappear` 重置 ⇒ **闪烁** | 一组件一 bindSheet；多面板改由**同一** bindSheet 内切换 `@BuilderParam` |
| 列表**每行内联** `AppSheet` | 20 行 = **20 个宿主**，`@StorageLink` + 注册 + 同步屏宽 IPC 全压在页面首建帧（实测 `appsheet.init n=29`）| 收敛为**每页一个**宿主 + 请求分发（`MediaSheetManager`） |
| 把宿主提到 `NavDestination` 之外"全局只挂一个" | 半模态 `bindSheet` **弹不出来**（只能挂当前页面组件树内）| 宿主**随页面走**，多宿主用**栈**决定谁响应 |
| 页面树整体重建时用 `pop()` 出栈宿主 | 「新宿主 appear 早于旧宿主 disappear」⇒ 出栈错位 | 按**引用**删除（`unbind(fn)`），与顺序无关 |
| 同页多弹窗叠加 | **两层蒙层叠压**（画面变暗、点蒙层要关两次）| 全局注册表按 `group` 互斥（`SheetManager`） |
| 互斥时"关掉所有弹窗" | 把导入进度（`dismissible=false`）也一起关了 | `closeGroup` **只关** `dismissible=true` 的 |
| 同一入口两个来源共用一个信号键 | **来源串台**（AppStorage 写入与 `@Watch` 消费不在同一帧）| 用**两个独立计数器键** |
| 系统选择器关闭后宽屏 dialog 没重建 | dialog 被系统顶掉 / 残留（`importing` 值未变不触发重建）| 另发 `importReopen` +1，收到后**先关再开**（`setTimeout 120ms`）|
| 宽屏 `dialogBody` 套用窄屏的整行下沉 6vp | 宽屏**没有**系统关闭按钮 ⇒ 白偏 6vp | 宽屏**不加** `SHEET_TITLE_ROW_DROP_VP` |
| 宽屏与窄屏各写一套返回按钮尺寸/占位 | 同一按钮在手机/平板**观感分叉**（40×64 扁块 vs 40×40 方块）| 复用同一组导出常量 + 同款圆形光感形态 |
| 把「只做选项/入口」的东西做成弹窗 | 与用户口径不符（"入口一律用 menu，复杂内容才用弹窗"）| 退回 menu；弹窗只留需要内容承载的场景 |

## 十三、验收清单（真机必须逐条过）

1. 内容能滚进标题带下方，并且**被糊着看到**（不是被一块实色盖住）。
2. 标题带**上下缘都看不出硬边/分割线**（放大看边界处无强度台阶）。
3. 弹窗刚打开、**未滚动**时，首行内容**清晰可读**（没被模糊带糊住）。
4. **把内容一路滚到顶**：首行能真正到达面板顶边、在标题带下被明显糊掉（不是"差一点到"）。
5. 标题文字左缘与内容左缘对齐、垂直位置与系统关闭按钮**圆心**同线（自绘侧需整行下沉 6vp，见第二节）。
6. **内容矮的弹窗**紧凑（不撑满屏）；**内容高的弹窗**封顶后内部滚动且底栏不被顶出屏幕。
7. **深色模式**下标题带底色与弹窗本体**同色**（不是"贴了一条纯黑渐变"）。
8. **横屏**下弹窗仍是**底部半模态**，不是屏幕正中悬浮卡片。
9. **横屏**下弹窗底色正常（无"白面板黑卡片"）。
10. **手机横屏旋转**前后，弹窗形态一致（不因旋转切换成 dialog）。
11. 标题带区域**可以拖动/滚动**（手势穿透正常），返回按钮**可点**。
11.5. 有层级的弹窗：返回按钮是**圆形（带光感背板）**的；**标题与返回按钮在同一条中线**上（整体下沉后这条中线与右上角关闭按钮**圆心对齐**）；尺寸相称（不是一个裸箭头）。
12. 有层级时：**返回键 / 返回手势 / ESC** 都是"退上一级视图"，退到根视图才关弹窗。
13. 点蒙层 / 下滑 / 关闭按钮 **正常关闭**。
14. 快速连续开关**不闪**、不会"短时间再次点击就自动关闭"。
15. 退后台再回前台，**弹窗与蒙层状态一致**（不会面板没了蒙层还在）。
16. 滚动长列表**不掉帧**（GPU 模糊每帧重采样；掉帧则调小半径/缩短带长）。
17. 深浅色两种主题下标题带渐隐都正常（透明档不"变实"）。
18. 同页先后打开两个**同 `group`** 弹窗：**只有一个可见**（无两层蒙层叠压）。
19. **嵌套弹窗**（ConfirmSheet 嵌在 MediaActionSheet 内）：外层**不会**把内层误关。
20. 系统**文件选择器**关闭后回到 App：宽屏 dialog**正常重建**（不残留、不错位）。
21. **列表页（20+ 行）**：滚动与首建**不掉帧**（宿主数已收敛为 1，不是每行一个）。
22. 需要"保留弹窗"的场景（如从弹窗跳设置再返回）：回来弹窗**还在**。

## 十四、样板

- **Icey-Player-Harmony**（十六轮迭代定稿，最完整参考）：
  `components/SheetContainer/SheetContainer.ets`（内容滚动 + 四周留白 + `linearGradientBlur` + `contentEndOffset` 行程补偿）+ `components/AppSheet/AppSheet.ets`（自绘浮层标题带 + `sheetSurfaceColor` 基色 + `onWillDismiss` + 窗口短边判定 + 宽屏 dialog）。
  相关提交：`2c91f23` 去卡片化 → `6d35e01` 标题改自绘浮层 → `4f705b9` 去硬切割（backdropBlur→linearGradientBlur）→ `1776ab8` 模糊到顶 + 带长解耦 + 删分割线 → `2e2db77` 视图层级返回按钮 → `7b643c1` 横屏「白底黑卡片」+ 短边判定 → `ad37d1d` 底色带收窄至内容静止起点 → `a49e7f4` 第十四轮：滚动行程补偿 + 深色标题带同色 → `af913a8` 第十六轮：返回按钮改**圆形光感**（`Stack{MaterialLayer; SymbolGlyph}`）+ 规格常量导出、宽屏复用；全仓删 18 处 `.menuItemDivider()` → `79186e6` 第十七轮：**标题行整行下沉 6vp**（`SHEET_TITLE_ROW_DROP_VP`，对齐系统关闭按钮圆心）+ 有返回按钮时标题让距（`SHEET_BACK_TITLE_GAP`）。

  **弹窗管理链路**（第十节）：
  `services/SheetManager.ets`（全局注册表 + `group` 互斥）、
  `services/MediaSheetManager.ets`（每页一宿主的**请求分发**，宿主按引用入栈/出栈）、
  `components/ImportSheetManager/ImportSheetManager.ets`（全局**计数器信号**触发）、
  六类宿主：`MediaSheetHost` / `ImportSheetHost` / `ChangelogSheetHost` /
  `PlayMediaSheetHost` / `PlayOutputSheetHost` / `RedeemCodeSheetHost`。
- **Icey-Reader**（同类移植，含「单宿主多面板」变体）：
  `components/SheetContainer/SheetContainer.ets` + `components/AppSheet/AppSheet.ets` + `components/ReaderSheetHost/ReaderSheetHost.ets`（一个宿主承载多个面板 + 自绘浮层标题带，无返回按钮）。