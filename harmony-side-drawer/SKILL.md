---
name: harmony-side-drawer
description: HarmonyOS/ArkTS 手机端自研侧滑抽屉（Drawer）完整方案。当需要实现侧边抽屉/侧滑菜单/左侧导航；或 bindSheet 的 SheetType.SIDE 在手机上不生效；或抽屉弹出/收起动画不播放、跟手黏手；或**加了抽屉后整个页面点不动/列表滚不动**（全屏覆盖层命中测试阻塞）时使用。含"唤出入口千万别用边缘手势"与"关闭态必须整树惰性"两条真机否决结论。
agent_created: true
---

# 手机端自研侧滑抽屉（HarmonyOS / ArkTS）

## 生命周期四阶段（2026-09-16 起实测结论，先读）

自研抽屉的正常生命周期 = **四阶段**：`visible → 退场(onClose/HandleDragEnd) → gone → exit`。
任何一次打开 / 收起 / 关闭，结束时都**必须落回 gone（或 exit）**，否则下一次打开就会被生命周期状态卡住。

| 打开 | 收起 | 关闭（用户按 X / 外部广播 `playlistDrawerOpen=false`） | 永久移除（页面 `onDisappear` / onDestroy） |
|---|---|---|---|
| `visible` | `.animation`（弹簧）→ `gone`（挂载 = false），**手势 / 键盘 / AppStorage 广播全部复位** | `gone` 之后还要继续走 340ms 退场动画 → 另设一个 `exit` 状态（**不能再回到 `gone` 再打开**：`show` 为 false 时打开会被 onShowChange 拒绝） | 必须在根状态机里清除 `exit`，否则父级重建后显隐状态卡死 |

三个陷阱（都踩过）：
- **退场动画期间 newSegment 手势再被调用** → 卡在"看不到页面"（面板在大屏上 `tabContainer` 里渲染过，`mounted=false` 不移除）。期间事件要**落空**（不重启动画、不记录）。
- **弹出时再次点弹出按钮** → 先收动画（`isAnimating=true` 期间忽略开启请求，按钮只播动画不复用）。
- **onClose（用户触发收起）里的旧逻辑**在布局改动后失效（例如 drawer 由键盘事件收起，而布局不再触发 onClose），导致 recursion 死循环 —— 消除回归后，之前可用的相关代码要从根状态机里完全移除，不要只藏不删。

## 第 0 步：先确认走哪条路（三条路手机端只有一条能走）

| 方案 | 手机竖屏 | 平板/折叠展开 | 可定制程度 |
|---|---|---|---|
| `bindSheet` + `preferType: SheetType.SIDE` | ❌ **不可用** | ✅ | 低 |
| `SideBarContainer(Overlay)` | ✅ | ✅（可 Embed 常驻） | 中 |
| 自研 `Stack + translate + PanGesture` | ✅ | ✅ | 完全 |

- **`SheetType.SIDE` 是 API 20+，但官方明确要求「窗口宽度 > 600vp」**——手机竖屏（约 400vp）直接用不了，别在这条路上浪费时间。查证位置：`ts-universal-attributes-sheet-transition` 的 `preferType` 说明第 4 条。
- `SideBarContainer(Overlay)` 能跑，但**直角边缘、半圆 `controlButton`、蒙层强度全都不可定制**，蒙层/曲线不可调。只在"能跑就行、不挑观感"时用；要用得干净至少得 `showControlButton(false)`。
- 要贴合自家设计语言（圆角/弹簧/遮罩强度可控）→ **自研**。

## 第 1 步：唤出入口 —— ⛔ 千万不要用「边缘右滑」

> **真机否决结论（2026-09-11）**：曾按"左边缘右滑唤出"实现（`window.setGestureBackEnabled(false)` 让出系统返回手势热区 + 宿主根容器挂 `PanGesture`），真机反馈两条都中：
> **「会跟滑动切换 tab 冲突，并且导致列表页滚不动了」**。
>
> 根因：宿主页根容器上已经同时存在**至少三套手势**在抢——① Tabs 左右滑动切页；② 列表纵向滚动 + 横向 List 滚动；③ 系统返回手势。再挂一个根级 `PanGesture` 必然互抢；而 `setGestureBackEnabled(false)` 是**应用级**开关，让出热区后系统侧的滚动/返回判定也被牵连。方案已整套拆除。

**正确做法：入口放菜单/按钮，抽屉只负责渲染 + 收起；抽屉组件挂「根 Stack」。**

```ts
// 发起方（如标题栏「更多操作」下拉菜单的「歌单」项）
AppStorage.setOrCreate('playlistDrawerOpen', true);

// 抽屉挂载处——@StorageLink 双向绑定，抽屉收起时自动写回 false
@StorageLink('playlistDrawerOpen') playlistDrawerOpen: boolean = false;
// build: PlaylistDrawer({ show: $playlistDrawerOpen, topOffset: SafeArea.top + 12 })
//          .zIndex(Index.DRAWER_Z /* 5，高于播放页覆盖层 */)
```

好处：零手势冲突；发起方可以在任意层级（Index 的标题栏菜单 → 广播 → 根层抽屉）。
配套：**切 tab 时收起抽屉**（抽屉在根层、不随 tab 卸载，不清会残留"切回来还开着"）→ 在 Tabs 的 `onChange` 里 `playlistDrawerOpen = false`。

> 如果偏要保留手势唤出，唯一相对安全的形态是**不做全局手势**，而是页面内某个固定热区组件上挂 `PanGesture`（组件边界 = 事件边界）。即便如此，仍要接受与 Tabs 滑动/recycler 滚动的竞争，**上线前必须真机验证三项：切 tab 滑动是否正常、列表能否滚动、子页侧滑返回是否正常**。

### ⛔ 第二条铁律：全屏覆盖类浮层**只能挂根 Stack**

> **真机反馈（2026-09-11）**：抽屉原挂在业务页（`MediaLibrary`）的 Stack 内、`zIndex(30)`，实测**被标题栏和底部播放条"压在下面"**（面板顶部标题与底部列表被遮）。
>
> 根因：**Hds 标题栏与 HdsTabs miniBar 都是跨组件树的浮层**（标题栏 `ignoreLayoutSafeArea`、miniBar 走 `barOverlap(true)`），它们与业务页**不是同一个 Stack 的兄弟节点**——**跨树 zIndex 不可比**，后渲染的浮层天然在上。页内 zIndex 调到 30 甚至 1000 都没用。
>
> 另外，跨树浮层**不会**被页内祖先的 `.clip()` / 遮罩裁剪，视觉必然割裂（内容区变暗、标题栏与播放条亮着）。

→ 抽屉（以及任何"全屏遮罩 + 面板"形态的浮层）**挂主页面根 Stack 最末**，`zIndex` 只需高于同层的其他覆盖层。迁移后：
- `topOffset` **不再避让标题栏**（标题栏已被面板压住），只避状态栏 → `SafeArea.top + 12`；
- 面板内底部 padding 加 `SafeArea.bottom`（列表滚到底不被手势条压住）。

### ⛔ 第三条铁律：挂根层 ⇒ **关闭态必须整树惰性**（否则整页点不动、滚不动）

> **真机事故（2026-09-11）**：把抽屉从业务页迁到根 Stack 之后，**整个页面对点击和滚动完全无响应**（不只是抽屉）。
>
> 根因：抽屉根节点是 `Stack().width('100%').height('100%')` —— 一个**全屏热区节点**。挂到根层后它就是**全局最上层节点**，
> 而 ArkUI 命中测试对重叠节点**默认只测最上层那个**，`HitTestMode.Default`（不配就是它）**命中后阻塞兄弟节点**
> → 即使抽屉关着（`if (mounted)` 不渲染任何内容），这个空节点依旧吃下全部触摸。
> **要点：挡住的不是"里面有东西"，而是"节点本身存在且占满全屏"**。
>
> ⚠️ 这也是它挂在业务页内时没暴露的原因之一——同层还有页面内容、命中路径不同，**迁移到根层会把这个隐患放大成全局故障**。

```ts
// ✅ 关闭态整树惰性（写在抽屉根 Stack 的属性链尾部）
Stack({ alignContent: Alignment.TopStart }) { /* 遮罩 + 面板 */ }
  .width('100%').height('100%')
  .visibility(this.mounted ? Visibility.Visible : Visibility.None)          // 不布局/不绘制/不响应触摸
  .hitTestBehavior((this.mounted && this.progress > 0.01)
    ? HitTestMode.Default : HitTestMode.None)                              // 双保险 + 覆盖退场动画期

// ✅ 遮罩同理：退场 340ms 里它已全透明却仍是全屏热区，会白挡点击
Column().width('100%').height('100%').opacity(MASK_MAX * this.progress)
  .onClick(() => this.close())
  .hitTestBehavior(this.progress > 0.01 ? HitTestMode.Default : HitTestMode.None)
```

文档口径（可直接引用）：**触摸热区为 0 时事件直接回传给父节点**；`HitTestMode.None` = 自身不响应且**不阻塞兄弟与子节点**；
`Visibility.None` = 不参与布局/绘制/命中。三者叠加即"整树惰性"。

### 另一条路：不用覆盖层（华为官方示例 `bottom-drawer-slide-case` 的做法）

官方示例「实现底部抽屉滑动效果」把抽屉做成**页面流内的高度动画 List**：`RelativeContainer` 底部锚定 +
`height` / `offset({ y })` 状态 + `onTouch` 手写位移 + `animation(500ms, Friction)`，松手按高度区间**分阶吸附**。
**全程没有任何覆盖层节点** → 天然不会踩上面第三条铁律。

- 适合：不需要遮罩、不需要横滑收起、和页面内容并排共存的"底部面板"（如地图 + 底部列表）。
- 不适合：需要遮罩压暗 + 自定义圆角/弹簧 + 跟手横滑收起（本项目的左滑歌单抽屉）。
- 可借鉴的两点：① `enableScrollInteraction(false/true)` —— 跟手阶段**关掉面板内 List 的滚动**，松手再开，避免拖动被列表滚动抢走；
  ② 分阶吸附（吸附目标写死在状态机里，而不是只按位移阈值二分）。
- 不建议借鉴：手写 `onTouch` 算 `yStart/yEnd`（`PanGesture` 更现代、自带速度 `velocityX/Y` 可直接做 fling 判定）；
  以及用一堆 `@State` 布尔量互相判断状态（容易出非法组合，本项目的 `mounted/progress/dragging` 三态更干净）。

## 第 2 步：组件骨架

宿主受控显隐（`@Link show`）+ 四个内部状态：

- `mounted`：是否挂在树上
- `progress`：0 = 收起 → 1 = 展开（同时驱动 `translate` 与遮罩 `opacity`）
- `dragging`：拖拽中（用来把动画时长压 0）
- `animToken`：**动画时序令牌**（每次显隐切换 +1，延迟回调执行前校验）

```ts
@Watch('onShowChange') @Link show: boolean;
private animToken: number = 0;

onShowChange(): void {
  this.animToken++;
  const token = this.animToken;               // 闭包快照：过期回调直接丢弃
  if (this.show) {
    this.mounted = true;
    setTimeout(() => {
      if (token !== this.animToken) return;   // 等待期内被反转 → 作废
      this.dragging = false;
      this.progress = 1;
    }, MOUNT_FRAME_MS);                       // 16ms：同帧挂载+到位不播过渡
  } else {
    this.progress = 0;
    this.dragging = false;
    setTimeout(() => {
      if (token !== this.animToken) return;   // ← 缺这句就会"闪一下"
      this.mounted = false;
    }, EXIT_MS);
  }
}
```

```
Stack({ alignContent: Alignment.TopStart }) {
  if (mounted) {
    // 遮罩：opacity = MASK_MAX * progress，onClick 关闭
    //       .hitTestBehavior(progress > 0.01 ? HitTestMode.Default : HitTestMode.None)
    // 面板：.translate({ x: -panelW * (1 - progress) })
    //       .animation({ duration: dragging ? 0 : ENTER_MS, curve: curves.interpolatingSpring(0, 1, 328, 34) })
    //       .gesture(PanGesture({ direction: PanDirection.Horizontal, distance: 8 })
    //         .onActionStart(() => dragging = true)
    //         .onActionUpdate(e => progress = clamp(1 + e.offsetX / panelW, 0, 1))
    //         .onActionEnd(e => { dragging = false; close = progress < 0.65 || e.velocityX < -300 }))
  }
}
.width('100%').height('100%')
// ⚠️ 挂根层必备：关闭态整树惰性，否则整页点不动（见第三条铁律）
.visibility(mounted ? Visibility.Visible : Visibility.None)
.hitTestBehavior((mounted && progress > 0.01) ? HitTestMode.Default : HitTestMode.None)
```

面板内的收起手势是**组件边界内**的（面板自己就是事件边界），这不冲突；与外层抢的只有"宿主根容器上的唤出手势"。

## 面板视觉：毛玻璃（高斯模糊）配方

> 用户要求（2026-09-11）：「抽屉背景能不能高斯模糊」。

```ts
// 面板节点
.backgroundColor(ThemeManager.isDark ? '#B3000000' : '#B3FFFFFF')   // 70% 半透明"垫底"
.backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR, {
  colorMode: ThemeManager.isDark ? ThemeColorMode.DARK : ThemeColorMode.LIGHT,
} as BackgroundBlurStyleOptions)
```

三条要点：

1. **只把 `backgroundColor` 改成半透明 ≠ 毛玻璃**（实测"看起来就是个透明层"）——必须配 `backgroundBlurStyle` 才会真采样背后内容做模糊。
2. **`colorMode` 必须显式跟「应用内」深浅**，别用 `ThemeColorMode.SYSTEM`：应用可以强制浅色而系统是深色 → 材质色与应用主题相反（浅色抽屉拿到深色材质 = 面板发灰）。
3. **70% 透明度是"文字可读"与"看得出毛玻璃"的折中**；档位用 `COMPONENT_REGULAR`（`THICK` 类材质自带底色重，会把模糊盖掉）。

⚠️ **主题响应**：`ThemeManager.isDark` 这种 static 非响应式值要配 `@StorageLink('themeIsDark')` 订阅，否则应用内切深浅后抽屉仍留在旧配色。

⚠️ **性能**：`backgroundBlurStyle` 在每个平移/尺寸变化的帧都要重算 backdrop 模糊（成本随面板面积走）；抽屉开合有 320ms 动画 + 跟手拖拽 → 大面积抽屉可能掉帧。退路（按顺序试）：① 动画期用纯半透明底、`progress` 到位后再挂 `backgroundBlurStyle`；② 降档位；③ 模糊层与内容层分离。

⚠️ **遮罩与模糊同层**：遮罩若在面板之前绘制 → 模糊采样包含那层暗色，面板比"纯毛玻璃"暗一档（通常可接受；想避免就让遮罩位于独立更下层容器）。

## 面板内容：优先复用业务页的卡片组件

> 用户要求（2026-09-11）：「歌单抽屉能不能还是按照列表里面那样渲染？就是大卡片 总之样式完全一致 新建歌单也是」。

抽屉里**不要为抽屉另写一套条目样式**。业务页已有卡片组件（本项目 `components/PlaylistCard`：封面铺满 + 底部模糊渐变 + 白字）就直接拿来排网格：

```ts
Grid() {
  GridItem() { PlaylistCard({ coverArtUri, name, count, cardWidth: this.cardSize(), cardHeight: this.cardSize(), onTap: ... }) }
  ForEach(this.userPlaylists(), (p: Playlist) => { GridItem() { PlaylistCard({ ... }) } })
  GridItem() { PlaylistNewCard({ cardSize: this.cardSize(), onTap: ... }) }   // 两处共用同一份实现
}
.columnsTemplate('1fr 1fr')
.columnsGap(12).rowsGap(12)
.padding({ left: 16, right: 16 })
.layoutWeight(1)
.scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
```

三个要点：

1. **卡片尺寸必须与 Grid 列宽同算式**：`cardSize() = (panelW − PAD_H×2 − GAP) / 2`。
   `columnsTemplate('1fr 1fr')` 的列宽就是 `(内容宽 − gap) / 2`，同算式 ⇒ 卡片正好填满单元格；**别取整**（差 0.5vp 会让卡片在单元格里偏一点）。
   面板宽度不用为卡片改（本项目 `min(320, 屏宽*0.75)`：屏宽 360 → 面板 270 → 卡 113vp，两列刚好）。
2. **"新建/添加"这类占位卡也抽共享组件**（本项目 `PlaylistNewCard`）。它原先是内联在业务页卡片条里的，抽屉自己抄就抄错了形态（先隐形、后又被改成小球加号）——
   凡"两处必须长得一样"的东西一律抽组件，同 `QualityTag` 的教训。
3. **改完把抽屉里旧的条目 builder 整体删掉**（本项目删了 `drawerRow` 及其配套的隐形修法），别留孤儿样式。

⚠️ **成本**：每张卡 = 1 张清晰图 + N 段模糊条带（本项目 5 段）= **6N 个图片节点 + 5N 个 blur**，叠加面板自身 `backgroundBlurStyle` 每帧重算 backdrop
→ 卡片多时开合/拖拽**有明显掉帧风险**，真机必测；退路是动画期降级（见"面板视觉"节）。

⚠️ **命名坑**：`@Prop size` 撞 `CustomComponent` 基类成员 → `Property 'size' is not assignable to the same property in base type 'CustomComponent'`（10505001）→ 改名 `cardSize`。

## 坑位清单（全部踩过）

| 坑 | 现象 | 解法 |
|---|---|---|
| **宿主根容器挂唤出手势** | **与 Tabs 左滑切页冲突、列表滚不动**（真机否决） | **不做根级手势**，入口改菜单/按钮 + `AppStorage` 广播 |
| **抽屉挂在业务页内** | **被标题栏 / 底部播放条"压在下面"**（真机否决） | 挂**根 Stack**（跨树浮层 zIndex 不可比，见上文铁律） |
| **挂根层后关闭态仍是全屏热区** | **整个页面点不动 + 列表滚不动**（真机事故，最严重） | 关闭态 `Visibility.None` + `hitTestBehavior(None)`；退场动画期（`progress→0`）也要切 None；遮罩同理 |
| **延迟回调无令牌** | 连续开关时**概率性"闪一下/闪没"** | `animToken` 递增令牌，延迟回调执行前校验 |
| 挂载与到位同帧 | 打开时**不播过渡动画**，直接闪现 | 先 `mounted = true`，`setTimeout(..., 16)` 下一帧再 `progress = 1` |
| 收起后不卸载 | 透明层留在树上**拦截触摸**，页面点不动 | 收起动画走完（`EXIT_MS` 后）再 `mounted = false`，且**外层再加 `Visibility.None` 兜底** |
| 拖拽期间动画未关 | 跟手**发黏**（每帧再插值一次） | `dragging` 标志把 `.animation` 的 `duration` 压到 0，松手再恢复 |
| 拖拽期间面板内 List 仍可滚 | 跟手被列表滚动抢走（尤其纵向抽屉/纵向面板） | `dragging` 期间 `.enableScrollInteraction(false)`，松手恢复 |
| 面板内手势方向未限定 | 与面板内 `List` 纵向滚动抢手势 | `PanDirection.Horizontal`（纵向滚动天然不冲突） |
| 面板宽度写死 | 平板/横屏抽屉过宽 | `min(320, 屏宽 * 0.75)` |
| 面板底部无安全区 | 列表最后一项被手势条压住 | 面板内 `.padding({ bottom: SafeArea.bottom + 12 })` |
| Tabs 缓存残留 | 切走再切回来抽屉还是展开态 | Tabs `onChange` → `playlistDrawerOpen = false`（抽屉在根层，不随 tab 卸载） |
| **毛玻璃只改了半透明底色** | 看着"就是个透明层"，没有模糊 | 必须同时 `backgroundBlurStyle`，且 `colorMode` 跟**应用内**深浅 |
| **浅色毛玻璃/白底上给「小元件」用 30% 白玻璃态** | 小图标/小占位块**完全隐形**（用户原话："白色的抽屉，结果按钮图标是白色，看不清楚"） | **小元件**（图标、小方块、细描边）必须实底：`ThemeManager.colors.placeholderBg` 或 `accent`。⚠️ **大块卡片例外**——面积够大时 `#4DFFFFFF` + 细描边的边界仍可见，且若业务页已有同款卡片组件，就**照抄它、不要为抽屉另调一版**（见下节"面板内容"） |
| 抽屉里手写一套"行式"条目 | 与业务页的卡片列表**视觉割裂**，且自己抄的样式反复出错（隐形图标、加号形态跑偏） | **复用业务页的卡片组件**（本项目 `PlaylistCard` / `PlaylistNewCard`），抽屉只负责网格排布 |

## 验收清单（真机必须逐条过）

1. **抽屉关闭态下：整页可点、可滚**（最优先——这是全屏覆盖层最容易炸的一条）。
2. 菜单/按钮入口能否稳定唤出（连点两次不异常、**快速连续开关不闪**）。
3. 滑出/收起的弹簧手感与遮罩观感。
4. **遮罩是否盖住标题栏与底部播放条**（挂根层的判据）、面板顶部/底部内容不被遮挡。
5. **切 tab 滑动是否正常、列表能否正常滚动**（这是边缘手势方案翻车的地方，务必回归）。
6. **收起动画进行中的那 300ms 内**页面能否点（遮罩已透明但热区还在的话会白挡）。
7. 抽屉内列表滚动与面板自身的收起手势不冲突。
8. 切走 tab 再切回来，抽屉是收起态。
9. 子页侧滑返回正常（若曾用过 `setGestureBackEnabled(false)`，确认已还原）。
10. 若做了毛玻璃：浅色 + 深色两种主题下都正常（面色不发灰），开合/拖拽**不卡顿**。
11. 抽屉内条目与业务页**同款**（卡片化的就逐张对一眼：封面/数量/圆角是否一致），"新建"入口与业务页那块长得一样。
12. 若面板内是卡片网格：卡片多时开合 / 拖拽**是否掉帧**（`6N` 图片节点 + 面板 backdrop blur）。

## 抽屉需要宿主页的状态时：用 AppStorage 广播，别硬塞 props

抽屉挂到根层后，与业务页（此前的挂载宿主）不再有父子关系，业务页里的弹窗/状态拿不到了。
→ 在根层用 `AppStorage` 广播**时间戳**，业务页 `@StorageLink + @Watch` 接：

```ts
// 根层（抽屉回调）
AppStorage.setOrCreate('createPlaylistRequest', Date.now());  // 用时间戳/计数器，别用 boolean
// 业务页
@StorageLink('createPlaylistRequest') @Watch('onCreatePlaylistRequest') req: number = 0;
onCreatePlaylistRequest(): void { this.showCreate = true; }
```

（`@Watch` 只在**值变化**时触发，连续两次请求若用 boolean 第二次不响应。）

## 样板

本项目（**2026-09-16 起歌单抽屉已整体改弹窗**）：`components/PlaylistDrawer/PlaylistDrawer.ets`（**现已删除**，改由 `components/PlaylistSheet/PlaylistSheet.ets` = `AppSheet`（手机 bindSheet / 宽屏窗口级 dialog）承载，见下方「弹窗替代」）——历史参考：全高覆盖式，右缘圆角 16、遮罩 0.26、面板毛玻璃、
内容 = **两列 `PlaylistCard` 网格**（`cardSize()` 与 Grid 列宽同算式）+ `PlaylistNewCard` 新建卡，
`animToken` 时序令牌，**关闭态 `Visibility.None` + `hitTestBehavior(None)` 整树惰性**）+
**挂载方 `layout/Index.ets`**（根 Stack 最末、`.zIndex(5)`、`topOffset: SafeArea.top + 12`、Tabs `onChange` 收抽屉、
`onNewPlaylist` → `AppStorage('createPlaylistRequest', Date.now())` 广播）+
发起方 `layout/Index.ets` 标题栏「更多操作」菜单的「歌单」项（`AppStorage('playlistDrawerOpen', true)`）+
新建歌单弹窗仍在 `pages/MediaLibrary.ets`（`@StorageLink + @Watch` 接广播）。

## 弹窗替代（2026-09-16：自研抽屉 → AppSheet 弹窗）

**结论：优先用系统弹窗，别再自研抽屉。** 用户对自研侧滑抽屉的反馈是"改弹窗更好看"，且系统弹窗（`AppSheet`）
天然解决自研抽屉最痛的三个问题：全屏覆盖层的命中阻塞（关闭态不必再写 `Visibility.None + hitTestBehavior(None)`）、
动画时序令牌、`mounted` 生命周期状态机。

- **渲染层级**：`AppSheet` 走 `bindSheet`（手机）/ 窗口级 `dialog`（宽屏），渲染在**窗口层**，天然盖住 Hds 标题栏与
  miniBar 这两个跨树浮层——**不再需要**自研抽屉时代的 `zIndex(5)` 常数与"挂根 Stack 最末"的搬移。
- **AppStorage 键沿用历史名** `playlistDrawerOpen` / `playlistDrawerCloseRequest`（改名会牵动 `App.onBackPress`
  返回手势链路，收益低）；返回手势"先关弹窗、关好再按才最小化"的语义照旧由 `App.onBackPress` 广播实现。
- **切 tab 收起弹窗**照旧：弹窗是根层浮层，不随 tab 卸载，Tabs `onChange` 里 `playlistDrawerOpen = false`。
- **弹窗内卡片网格**（手机三列 / 宽屏两列）:
  - 尺寸算式（**改样式必须同步**）：`contentWidth = (宽屏?420:窗口宽) − 56`（`SheetContainer` 卡片左右外边距 24×2 + 卡片内边距 4×2）；`cardSize = (contentWidth − GRID_PAD×2 − GAP×(COLUMNS−1)) / COLUMNS`；**Scroll 内的 Grid 必须显式给高** `gridHeight = rows×cardSize + (rows−1)×GAP + 24`，否则塌陷。
  - 宽屏判定与 `AppSheet` 同源（deviceType tablet/2in1 或屏宽 ≥600，模块级缓存）；dialog 宽 420。
  - **共享卡片组件的小卡适配 = 带默认值的可覆盖 prop**（默认值＝大卡历史口径 ⇒ 卡片条零影响）：
    `PlaylistCard` 加 `nameFontSize`(默认 13) + `labelOffset`(默认 30，≈卡片高 21%)；`PlaylistNewCard` 加 `plusFontSize`(默认 40)。
    弹窗传小卡档：`nameFontSize 11 / labelOffset 18 / plusFontSize 26`。
- **返回手势**：`bindSheet` 自行消费；未消费场景由 `App.onBackPress` 广播 `playlistDrawerCloseRequest` 关弹窗（时序逻辑已在 Index 的 `@Watch` 内）。
