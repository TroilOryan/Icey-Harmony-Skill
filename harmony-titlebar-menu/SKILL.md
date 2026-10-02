---
name: harmony-titlebar-menu
agent_created: true
description: HarmonyOS/ArkTS 标题栏按钮弹出下拉菜单的完整实现方案（Hds 标题栏 menu icon + PromptAction.openMenu 命令式弹出）。当需要在 HarmonyOS 应用标题栏/导航栏右上角按钮点击弹出 Menu 下拉菜单、bindMenu 受控锚点弹不出来、openMenu/ComponentContent/wrapBuilder 用法问题时使用。Icey-Player-Harmony 项目验证（API 26 真机）。
---

# Harmony 标题栏菜单（openMenu 命令式方案）

## 结论（先读）

- **不要用受控 bindMenu（@State + 隐形锚点）做标题栏菜单**——真机弹不出来（VipPage 两轮实证）。
- **正解：`UIContext.getPromptAction().openMenu(ComponentContent, TargetInfo, MenuOptions)`**（API 18+），action 回调里命令式弹出，不依赖响应式触发。
- 锚定按钮本体用 `HdsNavigationIconOptions.componentId`（API 20+），不要自画 0×0 锚点手工算坐标（会弹到错误位置）。
- **菜单项默认不带图标**（`.contentFontColor` + `content` 即可）。用户定案（Icey 2026-09-11）：*"menu这些都别加图标了 浪费资源"*——每个 `symbolStartIcon` 都要 new 一个 `SymbolGlyphModifier`、多一次资源解析。**例外：VIP/会员功能菜单**（图标是会员标识，保留）。

## 完整实现步骤（以 VipPage 为样板）

### 1. 标题栏 menu icon 配置

Hds 标题栏（`HdsNavigationTitleBarOptions.content.menu.value`）的 icon 配置：

```ets
private buildMenuItems(): HdsNavigationMenuItemOptions[] {
  return [{
    content: {
      icon: $r('sys.symbol.dot_grid_2x2'),   // 更多操作图标（鸿蒙竖向点）
      componentId: 'vip_menu_icon',           // API 20+：Hds 把该 id 设到 icon 节点上
      action: () => { this.openTitleBarMenu(); },
    },
  }];
}
```

### 2. 命令式弹出

```ets
private menuContent: ComponentContent<Object> | null = null;

private openTitleBarMenu(): void {
  // 防重复：openMenu 对同 content 二次调用报 103302
  if (this.menuContent !== null) {
    this.getUIContext().getPromptAction().closeMenu(this.menuContent).catch(() => {});
    this.menuContent = null;
    return;
  }
  this.menuContent = new ComponentContent(this.getUIContext(),
    wrapBuilder(vipTitleBarMenuBuilder), new MenuParam(this, /* 条件项状态快照 */));
  this.getUIContext().getPromptAction()
    .openMenu(this.menuContent, { id: 'vip_menu_icon' }, {
      placement: Placement.BottomRight,
      aboutToDisappear: () => { this.menuContent = null; },
    })
    .catch((e: BusinessError) => {
      AppLogger.error(TAG, `openMenu failed code=${e.code} msg=${e.message}`);
    });
}
```

页面 `aboutToDisappear()` 里 closeMenu 清理（句柄悬挂防护）。

### 3. 菜单内容：文件级 @Builder function + wrapBuilder（硬约束）

- `@Builder` **struct 方法进不了 ComponentContent 构造**——必须文件级 `@Builder function`。
- 全局 builder 拿不到 `this` → 参数类打包 page 实例 + 条件项状态，点击回调转发回公开方法：

```ets
class MenuParam {
  page: MyPage;
  showDebug: boolean;
  constructor(page: MyPage, showDebug: boolean) { this.page = page; this.showDebug = showDebug; }
}

@Builder
function myMenuBuilder(param: MenuParam) {
  Menu() {
    MenuItem({ content: '个人信息' })
      .onClick(() => { param.page.menuProfileTap(); })
    if (param.showDebug) {
      MenuItem({ content: '清除数据' }).onClick(() => { param.page.menuClearTap(); })
    }
  }
}
```

条件项（if 分支）的可见性在 openMenu 时通过参数快照传入——重开菜单即刷新，无需响应式。

### 4. import 来源

```ets
import { promptAction, SymbolGlyphModifier, ComponentContent } from '@kit.ArkUI';
```

`ComponentContent` 从 `@kit.ArkUI`，不是 `component/common.d.ts`。

## 坑位清单（全部真机/编译实证）

| 坑 | 事实 |
|---|---|
| 受控 bindMenu 不弹 | @State + 0×0 隐形锚点 + bindMenu(isShow 三元) 对 Hds 标题栏按钮场景**真机弹不出来**；uitest 注入点击也打不响 Hds menu icon action（自动化验证此路不通，需真机手测） |
| 0×0 锚点位置错 | 即使弹出来，自画锚点手工坐标和标题栏按钮真实位置对不上（Hds 标题栏内容区有自己的偏移）→ 菜单弹到标题位置。用 componentId 锚定按钮本体 |
| MenuOptions.title 无效 | openMenu 注释明确 "title property is not effective"；要标题在 Menu 里自绘一行 |
| MenuItem 字段 | `symbolStartIcon` + `content`（无 startSymbol/label）；Placement 无 BottomEnd，用 BottomRight |
| symbol 资源名 | id_defined.json 有名 ≠ `sys.symbol.xxx` 可用：`ticket`、`general_refresh` 编译报 Unknown；实际可用 `train_ticket`、`arrow_clockwise`。**判据只有编译成功** |
| 重复 open 报 103302 | 同一 ComponentContent 二次 openMenu 前必须先 closeMenu |
| 条件项刷新 | builder 参数是快照——页面状态变化后需重开菜单（openTitleBarMenu 再调一次即可） |
| `$r()` 必须字面量 | `$r(cond ? 'sys.symbol.a' : 'sys.symbol.b')` 编译不过——条件文案/图标要拆成两个分支各写一条 MenuItem（**无图标后此坑主要影响 `content` 的条件写法**） |
| 菜单项加图标 | 每个 `symbolStartIcon` 都要 `new SymbolGlyphModifier` + 解析 symbol 资源 → 用户定案"别加图标，浪费资源"。**VIP 功能菜单例外** |
| 同构页面漏改 | 同一个业务实体可能有多条入口 → 多个页面（Icey：「我喜欢的」= 媒体库入口 `FavoritesPage` **和** 歌单卡片入口 `PlaylistDetailPage`，两页代码不共享）。改造一个"歌单类"页面时必须 grep 另一页同步改，否则用户点另一个入口就"没有菜单" |
| 禁用项假禁用 | `.enabled(false)` 只挡点击，若底层方法对某类型是**静默 return**（如 `renamePlaylist(FAVORITES_ID)`），不走置灰就会出现"点了没反应"的伪 bug → 禁用语义要与底层约束对齐（rename/delete 对特殊歌单都要置灰） |
| 弹窗改菜单 | 把底部 `AppSheet` 面板整体搬进下拉菜单时：菜单项**点击后自动关闭**，不需要手动 `closeMenu`；但「打开子页面/打开另一位面的浮层」要**先关菜单再触发**，否则两层蒙层叠加 |
| 跨页触发浮层 | 菜单在 A 页（如 Index 标题栏），要操作的浮层组件挂在 B 页 → 用 `AppStorage.setOrCreate('drawerOpen', true)` + B 页 `@StorageLink` 双向绑定，**不要**去捞组件实例引用。⚠️ 若该浮层是「全屏覆盖」形态（抽屉/遮罩），**优先直接挂到根层**（跨树浮层 zIndex 不可比，挂业务页会被 Hds 标题栏/miniBar 压住，见技能 `harmony-side-drawer`）；此时回传上下文改用**时间戳广播** `AppStorage.setOrCreate('xxxRequest', Date.now())`，别用 boolean（`@Watch` 只在值变化时触发） |
| 菜单项超长 | 9 档排序这类选择型内容**不要平铺**（菜单会超屏）→ 做成二级菜单，见上文「多级菜单」 |
| 分割线不统一 | **`MenuItem.divider` 不设置时系统本就不画分割线**（`menu.d.ts` 原文："If this attribute is not set, the divider will not be displayed."）——所以"有的菜单有、有的没有"永远是自己手写 `.menuItemDivider({...})` 造成的分叉。用户定案（Icey 2026-10-02）：*"要么就全部不要"* → **全仓删掉 `.menuItemDivider()`，一律用系统默认（无分割线）**。⚠️ domain 无 `MenuAttribute.divider`，唯一控制点就是它；删完记得清掉随之无用的 `import { LengthMetrics } from '@kit.ArkUI'`（否则 lint 报未使用） |

## 接进现有脚手架（componentId 透传链）

详情页/子页标题栏由 helper + scaffold 封装，按钮 id 必须**一路透传**才能被 openMenu 锚定：

| 层 | 文件 | 改动 |
|---|---|---|
| helper | `model/TitleBarStyles.ets` | `buildDetailTitleBar(icon, onAction, backColor, backColorTop?, actionComponentId?)` → menu icon 的 `content.componentId`；`buildSubPageTitleBar(..., menuItems?)` 直接透传 menu 数组 |
| scaffold | `components/DetailScaffold` | 加 `@Prop actionComponentId: string = ''`，**非空才透传**（空传 undefined，避免影响未改造的调用方） |
| 页面 | e.g. `PlaylistDetailPage` | `actionComponentId: '<page>_menu_icon'` + `onAction: () => this.openTitleBarMenu()` |

样板：`VipPage`（SubPageScaffold + menuItems）、`PlaylistDetailPage`（DetailScaffold + actionComponentId；2026-09-11 由 AppSheet 改造，菜单项含条件禁用 `.enabled(false)`）、`FavoritesPage`（同一套，仅 2 项：多选 / 添加媒体）、`Index`（tab 页：封面墙按钮 + **三个 tab 统一**的「更多操作」菜单——媒体库含 6 项 + **排序**与**导入来源**两个二级页；艺术家/专辑仅展示形式切换）。

### tab 页标题栏（无 scaffold，直接写 menu 数组）

主页面自己声明 HdsNavigation 时，componentId 直接写进 `titleBar.content.menu.value[].content`：

```ets
menu: {
  value: cond ? [
    { content: { icon: $r('sys.symbol.shuffle'), action: () => this.onShufflePlay() } },
    { content: { icon: $r('sys.symbol.dot_grid_2x2'), componentId: 'tab_more_icon',
                 action: () => this.onMoreActions() } },
  ] : [ /* 其它 tab */ ],
}
```

- tab 页 titleBar 是 **Navigation 单实例**（不在 Tabs 内）→ 即使 `HdsTabs.cachedMaxCount(4)` 缓存多页，也不会出现多个同名 componentId 的锚定冲突。子页 scaffold 场景则每页一个实例，需给每个页面不同的 id。
- **菜单项写法**：用「单条交替项」（`内容 = 状态 ? '退出X' : '进入X'`）替代分段按钮/长列表，比二级面板更省交互。
- ⚠️ **不要把互不相干的功能合并进同一个按钮的菜单**。标题栏**每个按钮 = 一个功能域**，各自有自己的 `openMenu`（Icey 2026-09-11 用户当场否决我"把封面墙收进更多操作省一个图标位"的做法：*"更多操作是更多操作，不是合并为一个按钮"*）。合并会破坏用户既有肌肉记忆；"少一个按钮"不是优化目标。

### 多级菜单（一级 → 二级「选择型」项）

菜单里遇到**选择型**内容（如 9 档排序、多选值），不要平铺成超长菜单，也不要为它保留旧底部弹窗——做成二级菜单，锚点复用同一个 `componentId`：

```ets
private openMenu(view: number): void {
  // 一级 ↔ 二级互切：先收掉当前这层（同一时刻只允许一个菜单，否则 103302）
  if (this.menuContent !== null) {
    this.getUIContext().getPromptAction().closeMenu(this.menuContent).catch(() => {});
    this.menuContent = null;
  }
  const param = new MenuParam(this, /* …, */ view);
  this.menuContent = new ComponentContent(this.getUIContext(), wrapBuilder(menuBuilder), param);
  this.getUIContext().getPromptAction()
    .openMenu(this.menuContent, { id: MORE_ICON_ID }, { placement: Placement.BottomRight,
      aboutToDisappear: () => { this.menuContent = null; } })
    .catch((e: BusinessError) => { this.menuContent = null; });
}

/// 一级项 → 二级：closeMenu 有退场动画，立刻 open 会撞 103302，等一拍（≈220ms）。
/// 抽成**通用切换方法**（参数 = 目标 view）：多个二级页共用一个，免得每加一个二级页
/// 就复制一遍 closeMenu + setTimeout。
private switchMenu(view: number): void {
  const cur = this.menuContent;
  if (cur !== null) { this.getUIContext().getPromptAction().closeMenu(cur).catch(() => {}); this.menuContent = null; }
  setTimeout(() => { this.openMenu(view); }, MENU_SWITCH_MS /* 220 */);
}
```

**设计原则（Icey 用户定案 2026-09-11）**：*「只做选项、入口的都用 menu，复杂的内容继续用弹窗」*。
反例是"点菜单项 → 弹一个只有两三个选项的底部弹窗"——应直接改成二级菜单项。
正例：导入入口一级项「导入音频」→ 二级「选取文件 / 从下载文件夹导入」；
只有"从下载文件夹导入"之后的多选确认列表（内容复杂）才保留弹窗。
新增入口前先问一句：这步只是让用户挑一个分支吗？是 → 菜单；要展示/编辑一堆内容吗？→ 弹窗。
改造时记得把废弃的选项弹窗组件**连同文件一起删掉**（别留孤儿组件），并检查它的全部调用点
（Icey 那次有 3 处：标题栏菜单 / 媒体库空状态按钮 / 设置子页按钮）。

二级页的单条选项：**当前项目定案 = 不带图标**，当前档只用**主题色文字**标识（`.contentFontColor(current ? accent : textPrimary)`）——无图标就不会有"文字左移跳动"问题。

```ets
@Builder
function sortItem(param: MenuParam, label: string, mode: number) {
  MenuItem({ content: label })
    .contentFontColor(param.sortMode === mode ? ThemeManager.colors.accent : ThemeManager.colors.textPrimary)
    .onClick(() => { param.page.onSortPicked(mode); })
}
```

> 如果产品要求保留勾选图标：**不要只给当前项加图标**（其余项文字会左移跳动）——用同位置**透明色**（`'#00000000'`）的同一个勾保持对齐。Icey 项目已改为无图标方案。

**一级项文案直接写当前档**：`按${MENU_SORT_NAMES[param.sortMode]}排序`（→「按标题排序」「按添加时间（新到旧）排序」），不要写「排序方式 · 按标题」这种前缀式（用户明确否决前缀）。短名常量数组与档位下标一一对应，改档位顺序必须同步改。

### 选项集**无上限** → 菜单内翻页（2026-09-16 Icey-Days 实证）

「9 档排序」那种**有限**选择型内容 → 二级菜单平铺。但如果选项集**无上限**（年份、月份、
任意数值…），二级平铺同样会超屏 —— 这时不要在菜单里塞 `Scroll`（Menu 内滚动行为不可控），
用**同层翻页**：

- 菜单内容 = `[更早的 X] + 当前页 N 项 + [更晚的 X]`，页首**每页移动 N**，页数不受限 ⇒
  菜单长度恒定、任意值可达。`N=9` 时约 440vp，仍在"一屏读完"范围内（MenuItem 高约 40vp）。
- 翻页项用**次级文字色**与选择项区分；选择项**不带图标**，当前档用 `accent` 文字。
- 翻页 = 主动 `closeMenu` 当前句柄 → `setTimeout(220)` → 用新页首重开（同一 `componentId` 锚点）。
  菜单项点击本身也会自动关闭，所以重开前必须先把句柄置 null（`aboutToDisappear` 也会置 null），
  否则同 content 二次 open 报 103302。
- 页首**必须夹在数据边界内**（如 `[最早事件年, max(今年, 最晚事件年)]`），别让用户翻进空白区间。
- 每次从标题栏按钮打开时**重置页首**（按当前选中值重新居中），只有翻页动作保留页偏移 ——
  这样"打开就能看到当前值附近"，而翻页仍能一路翻出去。
- 页首偏移 / 菜单句柄放页面的普通字段（非 `@State`）：菜单每次 open 都用参数快照重建，
  不需要响应式；但**别**把它做成 `@StorageLink`，否则每次翻页都会重渲染整个页面外壳。

同一形状的实例：Icey-Days 时间轴「看哪一年」（`Index.openYearMenu` / `yearMenuPage` /
`showYearMenu` + 文件级 `timelineYearMenuBuilder`），选中值只写 `AppStorage('timelineYear')`，
由页面的 `@StorageLink @Watch` 去重建内容。

## 普通组件上的下拉菜单：`bindMenu` 直挂

⚠️ **前置判据（2026-10-02 Icey 实证，先看这条）**：普通组件（非标题栏）**只有"菜单内容静态不变"时**才用
`bindMenu` 直挂。**一旦需要二级菜单 / 需要"按当前状态重算并重弹"（如一级项显示当前档位），`bindMenu`
不够用 —— 静态 `@Builder` 没有"状态变化重算重弹"的周期**，改命令式 `openMenu`，锚点用该组件的
`.id(常量)`（`TargetInfo.id` 指向任意 `.id()` 组件，零手工坐标）。

- 实例：Icey 歌词版「更多」按钮（普通 `Stack`）——原 `bindMenu` + `Placement.BottomRight`，用户反馈
  「弹出位置没和按钮对齐」+「播放模式要照排序模式点进二级」⇒ 必须改 `openMenu`。
- ⚠️ **对齐口径**：`Placement.BottomRight` = 菜单**右缘**对齐锚点右缘（菜单向左展开，与窄按钮只"右下角相切"）；
  `Placement.Bottom` = 菜单**左缘**对齐锚点左缘。「和按钮对齐」通常要的是后者。
- 命令式的一级/二级切换、`MENU_SWITCH_MS=240`、103302 防护全部同上文「多级菜单」节（同一套机制，与是不是标题栏无关）。

以下为**无二级**的普通组件直挂写法：

```ets
Text('导入音频')
  .bindMenu(this.importActive ? undefined : this.importSourceMenu(),  // ② 禁用态传 undefined
    { placement: Placement.BottomLeft })                             // ③ 传 systemMaterial 时必须显式 placement
```

1. ⚠️ **`@Builder` 闭包内 `this` 未绑定**——闭包里写 `this.xxx()` 会**闪退**（项目多处实证，
   2026-09-14 封面形状选择器 `bindMenu` 菜单项 onClick 写死 `this.applyShape` → 真机
   `TypeError: applyShape is not callable`，日志是 `MenuItem CLK` 瞬间）。
   → 菜单项内部只做**静态调用**（`ImportSheetManager.openPickFile()` 这类），或把回调当参数传进来；
     需要写设置/联动播控中心时，走**模块级函数**（如 `applyShapeFromMenu(value)`，逻辑同组件内方法）。
     **盖结论：bindMenu 菜单项 onClick 禁止 `this.xxx()`，必须模块级函数或静态方法**。
2. **禁用态传 `undefined`**（= 不绑菜单、点击无反应），比在 `onClick` 里 `return` 更干净。
   `undefined ↔ builder` 切换在一次性渲染的页面上没问题；`LazyForEach` 复用项上会不重挂锚，慎用。
3. 传 `{ systemMaterial: ... }` 会走 system-styled 渲染路径 → **必须显式 `placement`**，
   否则锚定退化为默认位置（API 26 坑，见 `SettingItem` 注释）。
4. **bindMenu 必须挂原生组件**（Row / Text / Column…）；挂在自定义组件外层点击不生效。
5. `placement` 按锚点位置选：底部按钮用 `TopLeft`（朝上弹）、页面中部按钮用 `BottomLeft`（朝下弹）。

## 适用范围

- Hds 标题栏（HdsNavigation/HdsNavDestination）menu icon 弹下拉——本项目场景。
- 普通自定义组件上也可用 openMenu（TargetInfo.id 指向任意 `.id()` 组件）；**需要二级菜单时这是唯一方案**，
  内容静态不变时用 `bindMenu` 直挂更简单，优先直挂。
- 样板代码：`entry/src/main/ets/pages/subPages/VipPage.ets`（buildMenuItems / openTitleBarMenu / vipTitleBarMenuBuilder）；
  普通组件命令式二级菜单样板：`entry/src/main/ets/components/PlayBar/PlayHomePage.ets`（`openLyricMenu` / `goLyricMenu` /
  `LyricMoreMenuParam` / 文件级 `lyricMoreMenuBuilder`）。
