> **分册：`harmony-reader-kit-integration`** ｜ 原独立技能 `harmony-reader-kit-integration`，2026-10-03 合并进 `harmony-dev`。
> 触发场景见入口 `SKILL.md` 的路由表。

# 接入 Reader Kit 阅读内核

## 触发场景
- 用 `readerCore.ReadPageComponent` 做正文渲染，出现**白屏** / 配置不生效 / 动画异常
- 决定「走系统 Reader Kit 还是自绘阅读内核」，需要判定实际走了哪条路
- 阅读页的**沉浸/安全区/翻页动画**取舍（padding vs 隐藏系统栏）
- 阅读页**单击唤菜单**不生效
- 改了阅读主题色 / 字号默认值，真机上**毫无变化**
- 书文件要先进沙箱才能被 `bookParser` 读

---

## 1. 白屏头号根因：必须在「真·路由页」里用组件

`ReadPageComponent` **只在 `router.pushUrl` 进入的 `@Entry` 页里**才建立内部 `readKitViewController`。
放进 `NavDestination`（哪怕正常渲染、无报错）**恒白屏**，日志里是 `1016910002`。

**做法**：
- `main_pages.json` 的 `src` 里注册一个外壳页，如 `pages/subPages/ReaderKitHost`
- 外壳页里读 `this.getUIContext().getRouter().getParams()` 取参 → 回填到应用的「最近一次参数」容器
  （复用内部已有的 `AppRouter.getLastParam()` 口径，子组件一行都不用改）
- 入口用 `router.pushUrl({ url, params })`
- ⚠️ **外壳页必须显式写 `pageTransition()`，否则走系统默认转场** —— 默认转场含
  **不可控的整页位移 + 淡入**（官方明文「时长与物理曲线参数有关、不同设备不同」），
  观感就是「进入阅读页时内容/自绘标题栏往上移一段」。**这是路由页形态独有的坑**：
  它不在 `NavPathStack` 上，所以 `SubPageScaffold` 那套 `HdsNavDestination.customTransition`
  **完全盖不到它**（`customTransition` 只对 NavDestination 生效）。
  - 正确写法（`pageTransition` 是自定义组件的**成员方法**，无参数；`common.d.ts` 的 `onBackPress` 隔壁）：
    ```ts
    pageTransition() {
      PageTransitionEnter({ type: RouteType.Push, duration: 300, curve: Curve.Friction })
        .translate({ x: '30%', y: 0 })
      PageTransitionEnter({ type: RouteType.Pop, duration: 300, curve: Curve.Friction })
        .translate({ x: '-30%', y: 0 })
      PageTransitionExit({ type: RouteType.Push, duration: 300, curve: Curve.Friction })
        .translate({ x: '-20%', y: 0 })
      PageTransitionExit({ type: RouteType.Pop, duration: 300, curve: Curve.Friction })
        .translate({ x: '20%', y: 0 })
    }
    ```
  - ❌ **不要写 `pageTransition({ duration: 0 })`**：该成员方法**不接受参数**
    （声明为 `pageTransition?(): void`），传对象是无效写法。
  - ❌ **不要叠淡入**：整页淡入会让页面与底层背景混色，读作「背景色渐变过去」
    （`Icey-Player-Harmony/DetailScaffold` 2026-09-22 同因去掉淡入）。只保留横向滑入。
  - `SubPageRouterHost`（阅读页之上的子页外壳）**同样要写**，否则进书内搜索/书签页也会位移。
- 应用内部的 `NavPathStack`（HdsNavigation）**不要**参与阅读页 —— 阅读页不在这个栈上

**连带后果（必须一起处理）**：阅读页是路由页 → 它把应用主页面**完全盖住**。
此后「在阅读页之上」打开的普通子页（书内搜索 / 书签）若仍 push 到主栈，
会渲染到**已被盖住的主页面里** = 用户看不见。
解法：再加一个 `SubPageRouterHost` 路由页（自带一套 Navigation），把这类 push 重定向过去；
`pop()` 在「阅读页存活 + 主栈为空」时改走 `router.back()`。
判据用标志位（如 `readerHostActive`），**不要**用「栈里能不能查到阅读页的名字」——
阅读页是路由页根内容，不在任何 NavPathStack 上。

---

## 2. 文件前提：Reader Kit 只吃 hap 沙箱路径

`bookParser.getDefaultHandler(path)` 的 SDK 注释原文是
**"only support current hap sandbox path"** —— 外部 URI（fileShare 授权的 `file://...`）读不了。

所以开书入口必须先判：
1. Book 已有沙箱路径（`filePath`）→ 直接进 Kit
2. 无 `filePath` 且后缀受支持（txt/epub/mobi/azw/azw3）→ 拷进 `<filesDir>/books/import/import_<uuid>/`
   + 回填 `filePath` → 进 Kit
3. 拷贝失败 / 格式不受支持 → **回退自绘内核**并提示（绝不白屏、绝不静默）

**排查「到底走了哪条内核」**：查应用数据库里该书的 `filePath` 是否非空。
非空 + 格式受支持 ⇒ 一定走 Kit；此时若观感不对，问题在配置或页面层，**不是内核选错**。
（这一条能省掉大量误判：用户常以为「肯定是又退化成自绘了」。）

---

## 3. 启动时序：四步 + 有界重试

```
init 控制器 ∥ 建解析器  →  registerBookParser  →  setPageConfig  →  startPlay
```

**必须重试**：SDK 内部 `readKitViewController` 在**组件挂载后若干帧**才建立。
建立之前下发 `setPageConfig` → SDK 日志 `setFlipMode ... readKitViewController is empty,
The setup is not completed, return`（配置被**静默丢弃**）；紧接着 `startPlay` 抛 `1016910002`。

官方示例侥幸不踩：它的 `getDefaultHandler()` 每次真解析一本书（数百 ms），这段时间足够组件完成布局。
若你的书信息已缓存（解析瞬时返回）→ **抢跑**，四步在 1ms 内跑完 → 必然踩坑。

故对「就绪类失败」（`1016910002`）做**有界重试**（重下发配置 + 重试 startPlay）；
非该错误码**立即上抛**，不要吞掉真数据错误。

**控制器回接**：官方 `readerCallback` 会把返回的控制器**赋值回本地字段**。
不回接的后果是继续往「组件已不再使用的实例」下发 `setPageConfig`/`startPlay`
→ 设置与跳转**静默失效**（不报错，只是没反应）。回调在组件挂载时触发，
而 `startPlay` 内部 `await Promise.all([...])` 之后才注册 ⇒ 注册永远落在回调之后的实例上，直接赋值即安全。

---

## 4. 视口尺寸：不要用 padding 做安全区避让

**铁律：`viewPortWidth/Height` 的语义是「视口」，少报等于骗 SDK。**
限宽的正确做法是「约束组件本身宽度 + 上报同一个窄值」，不是少报视口宽。

**不要给 `ReadPageComponent` 加 padding**：SDK 的仿真翻页动画在**组件边界内**合成，
padding 区会变成硬裁切线 → 真机表现是「翻页时顶部/底部被切掉一截」。

官方做法是**把系统栏整个隐藏**：

```typescript
// 进页面
win.setWindowSystemBarEnable([]);          // [] = 状态栏 + 导航条全隐藏
// 离开页面恢复
win.setWindowSystemBarEnable(['status', 'navigation']);
```

注意与「只隐藏状态栏」的方法区分开——后者（`['navigation']`）语义不同，
是给普通页面做状态栏避让用的，**不能复用**。阅读页要单独封装一个「全隐藏」入口，
挂进 `aboutToAppear` / `aboutToDisappear`（退出必须恢复，否则回书架后状态栏消失）。

隐藏系统栏后，上报的高度就是**整窗口高度**，不要再扣 `safeTop/safeBottom`。

`viewPort = 0` 时 SDK 必抛 401 → 静默白屏。务必门控到「尺寸 > 0」才 `startPlay`，
并把视口测量挂在**全尺寸根容器**上（量被限宽的组件只会得到限宽后的宽度，窗口变宽永远涨不回去）。

---

## 5. 单击唤菜单：zIndex 必须显式给 + 根容器只开不切

**这是「单击正文不出工具栏」的头号根因**：`ReadPageComponent` 显式设了 `.zIndex(1)`，
而菜单层若**没设 zIndex**（Stack 子节点默认 0）→ 菜单被正文压住，看不见。

官方层级口径（照抄即可）：

| 层 | zIndex |
|---|---|
| 正文 `ReadPageComponent` | 1 |
| 菜单（顶栏 + 底栏） | 2 |
| 加载 / 错误态 | 3 |

根容器挂 `.onClick(() => this.showMenu = true)` 唤菜单，**不要**盖常驻拦截层 —— SDK 自己处理翻页手势。

### ⚠️ 根容器**只负责开**，绝不用 `showMenu = !showMenu` 切换

这是「**菜单出现一次后，再点屏就唤不出来**」的根因（真机实证）：

菜单层的「点空白收菜单」是**子节点**的 onClick。ArkUI 里子节点命中即**消费**该次点击、
**不再冒泡**到根 Stack ⇒ 根 Stack 的 onClick 那次「关」的切换根本收不到。
于是 `showMenu` 已被菜单层置 false，根 Stack 却仍以为自己是"开"的状态；
更糟的是菜单层是 `if (this.showMenu)` **条件渲染**，它在同一次手势里被销毁 →
首帧重建与本次点击的命中测试竞争 → 真机表现就是「点了没反应」。

**修法（与官方 `Reader.ets` 逐行一致）**：
- 根 Stack：`.onClick(() => { if (面板都关着) this.showMenu = true; })` —— **只开**
- 全屏菜单层：`.onClick(() => { this.showMenu = false; })` —— **只关**
- 官方对应 `showModal()` / `closeModal()` 两个独立方法，从不做 `!` 取反

### 面板打开前必须先收菜单（透明层拦截）

若「目录 / 主题 / 亮度」等面板是**全屏 overlay 且 zIndex 与菜单层相同或更低**，
菜单层会以透明层盖在面板之上并**拦截面板点击**（表现为：点目录项不跳章，只是把菜单关了）。
修法：**每个入口回调里先 `this.showMenu = false`，再开面板**，让面板独占一层。

**菜单中段别用 `Blank()`**：Blank 只占位、**不参与命中测试**，点击会穿透到下层正文被 SDK
当成翻页手势消费 ⇒ 菜单开着时点正文关不掉。换成可点击的 `Column().layoutWeight(1).onClick(...)`
显式消费这次点击。

---

## 6. 「改了默认值却毫无变化」= 落盘旧值覆盖新默认

配置类（主题色 / 字号 / 行距）通常有 `init()` 逐字段回填 `loaded.*` 的逻辑。
若用户从没改过该项，旧版本的**出厂默认值已被落盘**，每次启动又覆盖回内存
→ 只改代码里的默认值**永远不生效**。

**做法：在 `init()` 里加一次性迁移**，只在「旧出厂值原封未动」时改写为新默认
（用户改过就尊重其选择），并**立即 `save()` 落盘**，避免每次启动重跑迁移判断。

示例（米黄 → 白底 / 20+1.4 → 18+1.9）：

```typescript
let migrated = false;
if (cfg.dayTheme.bgColor === '#EEE8D5') { cfg.dayTheme.bgColor = def.dayTheme.bgColor; migrated = true; }
if (cfg.fontSize === 20 && cfg.lineSpacing === 1.4) {
  cfg.fontSize = def.fontSize; cfg.lineSpacing = def.lineSpacing; migrated = true;
}
if (migrated) await save();
```

---

## 7. 官方示例基准值（照抄这套，观感最稳）

官方 `readerkit_samplecode_arkts` 的 `ReaderSetting` 默认：

| 字段 | 值 | 说明 |
|---|---|---|
| `themeColor` | `#FFFFFF`（日间）/ `#202224`（夜间） | 日间就是**纯白底**，不是米黄护眼底 |
| `fontColor` | `#000000` / `#ffffff` | |
| `fontSize` | `18` | legado 风的 20 在 Kit 内核下明显偏大 |
| `lineHeight` | `1.9` | 官方观感的核心参数之一（legado 风 1.4 太挤） |
| `flipMode` | `'0'` | `'0'` 仿真翻页 / `'1'` 横滑 |
| `scaledDensity` | `display.getDefaultDisplaySync().scaledDensity`（兜底 1） | |
| `fontPath` | `''` | 空 = 系统字体；`fontName` 是**别名**不是字体族名 |
| `nightMode` | boolean | 阅读页独立于 App 主题 |

**别用 `rgba(248, 249, 250, 1)` 之类的浅灰当「白底」** —— 官方 `themeColor` 就有这个值，
但用户认可的基准是 `#FFFFFF`。

---

## 8. SDK 能力边界（设计前先确认，避免做无用功）

`readerCore.ReaderComponentController` 只有：
`init / startPlay / flipPage / setPageConfig / releaseBook / registerBookParser / on / off`
+ `pageShow` / `resourceRequest` 事件。

`PageDataInfo` 有 `startDomPos / endDomPos / resourceIndex / pageOffset / state /
pageHeaderContent / pageFooterContent` —— **没有「坐标 → 字符偏移」的 API**。

`bookParser` 有 `getBookInfo / getCatalogList / getSpineList / getSpineItemContent(spineIndex) /
getResourceContent / getDomPosByCatalogHref / getAbsoluteResourcePath`。

**实际影响**：
- 「长按划选 / 精确位置书签」无法从 SDK 拿到字符位置 ⇒ 只能退到**章首级**定位
- 实测 txt 与 epub 的 `durDomPos` **都为空**（SDK 不产生 DOM 位置）⇒ 连「恢复上次阅读位置」
  在 Kit 内核下也只能靠目录索引 + `pageOffset`
- 不要设计依赖「坐标↔字符」的功能，SDK 给不了

### ⚠️ 章节进度条：坐标量纲必须全用 `spine` 序，绝不能用目录序（2026-10-01 实证）
`PageDataInfo.resourceIndex` 是 **spine 序**，而书内**目录项**是另一套坐标（`getCatalogList`）——
**两者数量不等**（目录可含嵌套/卷/锚点项，也可能缺项）。混用会得到「**滑了没反应**」：

| 参数 | 错误写法 | 后果 |
|---|---|---|
| `Slider.value` | `resourceIndex`（spine 序） | — |
| `Slider.max` | `catalog.length`（**目录项数**） | 两套坐标错位 |
| `onSeek` 回调 | 拿返回值去目录里**反查** | 目录缺项时反查落空 → 静默无操作 |

正解：**统一到 spine 序** —— `max = getSpineList().length - 1`，
`onSeek(spine)` 直接按 spine 跳（不经目录）。
（`getSpineList()` 是 SDK 原生 API，`spineCount()` 只是它的 `.length` 包装。）

### ⚠️ 菜单/工具栏进出场动画：`TransitionEffect` 不需要 `animateTo`（2026-10-01 查 SDK 声明定论）
社区与 FAQ 常说「`transition` 必须配合 `animateTo`」——**那只对 `TransitionOptions` 类型成立**
（旧 API，已 `@deprecated since 10`）。`common.d.ts` 原文：*"When set to a value of the
**TransitionOptions** type, the **transition** attribute must work with animateTo"*。
而 `TransitionEffect` 自带完整动画参数（`TransitionEffect.opacity(0).combine(...)
.animation({ duration, curve })`），**直接条件渲染即可生效**。
⇒ 别为了「让 transition 生效」去套 `animateTo`（会破坏「纯属性动画不与 animateTo 同用」的项目铁律）。

`bindSheet` 承载面板自带系统升降/蒙层渐隐动画 —— 手写 overlay（`backgroundColor('#40000000')`
+ `justifyContent(FlexAlign.End)`）是纯条件渲染，**出现/消失只有一帧硬切**，没有任何过场。

---

## 9. 排查顺序（照这个走，别跳）

1. **白屏？** → 确认阅读页是不是 `@Entry` 路由页形态（`NavDestination` 里必白屏）
2. **配置/观感不对？** → 查数据库该书的 `filePath` 是否非空 ⇒ 判定实际内核
   - 非空（走 Kit）→ 查落盘配置是否覆盖了默认值（第 6 节）
   - 空（走自绘）→ 查开书链路的沙箱拷贝为何失败
3. **`setPageConfig` 不生效 / `1016910002`？** → 抢跑，加重试（第 3 节）
4. **翻页动画被裁？** → 有没有给组件加 padding（第 4 节）
5. **单击不出菜单？** → 菜单层 zIndex 是不是 0（第 5 节）
6. **菜单开着关不掉？** → 中段是不是 `Blank()`（第 5 节）
7. **菜单出现一次后再点屏唤不出？** → 根容器是不是写了 `showMenu = !showMenu`（第 5 节）
8. **面板点不动（点目录不跳章）？** → 开面板前有没有先收菜单（第 5 节）
9. **阅读页工具栏/标题栏想用 Hds 组件？** → 用不了：Hds 标题栏只能挂 `HdsNavigation` /
   `HdsNavDestination`，而阅读页必须是 `@Entry` 路由页（套 Navigation 就白屏）。
10. **进入阅读页/其子页时内容「往上移一段」？** → 外壳页漏写 `pageTransition()`（第 1 节）。
    ⚠️ 路由页的转场**不归 `HdsNavDestination.customTransition` 管**，两条机制互不影响，
    改了一条另一条照样位移。凡是 `router.pushUrl` 进的 `@Entry` 页都要自己写。
11. **进度条拖了不跳章？** → 量纲混用（第 8 节），检查 `max` 传的是不是目录项数。
   只能**自绘 Hds 同款**（标题栏 + 悬浮工具条），前景/背景色必须跟随 `ReadConfig.isNight`
   而非应用主题，否则浅底正文上是白字白底 = 隐形。
