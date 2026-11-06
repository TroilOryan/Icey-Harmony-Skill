> **分册：`harmony-reader-kit-integration`** ｜ 原独立技能 `harmony-reader-kit-integration`，2026-10-03 合并进 `harmony-dev`。
> 触发场景见入口 `SKILL.md` 的路由表。

# 接入 Reader Kit 阅读内核

## 触发场景
- 用 `readerCore.ReadPageComponent` 做正文渲染，出现**白屏** / 配置不生效 / 动画异常
- 决定「走系统 Reader Kit 还是自绘阅读内核」，需要判定实际走了哪条路
- 阅读页的**系统栏/安全区/翻页动画**取舍（padding vs 隐藏系统栏）
- 阅读页**单击唤菜单**不生效
- 改了阅读主题色 / 字号默认值，真机上**毫无变化**
- 书文件要先进沙箱才能被 `bookParser` 读
- **点「继续阅读」/ 目录项进阅读页白屏或没反应**（= 有人绕过了统一开书入口）
- 要让阅读页**直接落到指定章**（目录跳章 / 书签 / 搜索跳转），或两条内核跳章行为不一致

---

## 0. 开书入口必须唯一（两条内核并存时的第一条纪律）

两条内核的**文件前提 / 进入方式**都不同（见下节），所以「点一本书」这件事**只能有一个决策点**：

| 内核 | 文件前提 | 进入方式 |
|---|---|---|
| 自绘 | `bookUrl` 原始 URI（靠 fileShare 持久授权，**不拷贝**） | `AppRouter.push(ROUTE_READER)`（普通 NavDestination） |
| Reader Kit | **hap 沙箱路径**（`getDefaultHandler` 只吃沙箱路径） | `router.pushUrl(真·路由页)` |

决策点 = 一个 `openReaderFlow(bookUrl, targetChapter?)` 纯函数：① 有 `filePath` → Kit；
② 无 `filePath` 且格式受支持 → 拷进沙箱 + 回填 → Kit；③ 失败 / 格式不吃 / 无 context → **回退自绘**（绝不白屏）。
**任何页面直接 push 阅读页都是 bug**，详见第 2 节红字。

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

### ⚠️⚠️ 开书入口**必须唯一**：任何绕过入口的 `push(阅读页)` 都是一颗定时白屏（2026-10-03 实证）

**症状**：详情页点「继续阅读」→ **进去啥也没有，白屏**（点目录项同理）。

**根因**：详情页有**三处**直接 `AppRouter.push(ROUTE_READER, bookUrl)`（继续阅读 / 从头开始 /
目录项），绕过了统一入口。而 **`filePath` 非空的书恰恰是"已经迁进沙箱"的那批** ——
它们的**原始 URI 访问授权早已失效**，被塞进自绘内核读原始 URI ⇒ 打开即失败 ⇒ 白屏。
再叠加 `AppRouter.checkDuplicate`（同名 + 同参 → 静默 toast「页面已打开」并 return）⇒
「栈里已有同书阅读页」时**点了完全没反应**。

**正解**：入口函数**只此一个**，全部调用点收口（连"从头开始"这种"只是清个进度"的也要走）：

```ts
/// @param targetChapter -1 = 按已存进度继续；≥0 = 显式目标章（目录跳章 / 书签 / 搜索跳转）
export async function openReaderFlow(bookUrl: string, targetChapter: number = -1): Promise<void> {
  const b = BookRepo.find(bookUrl);
  if (b === null) { /* toast 并返回 */ return; }
  // 目标章统一经 AppStorage 下发（两条内核都必须消费，见下）
  AppStorage.setOrCreate<number>('readerJumpChapter', targetChapter);
  if ((b.filePath ?? '').length > 0) { openReaderKit(bookUrl); return; }   // ① 已有沙箱路径
  if (!BookFileCache.isSupported(b.bookUrl)) { push自绘(); return; }        // ② 格式不吃
  // ③ 首次迁移：拷进沙箱 → 回填 filePath → 进 Kit；失败回退自绘 + 提示
}
```

★ **收口的价值**：`filePath` / 格式 / 拷贝失败 / 回退提示 这套分流逻辑**只能存在一处**，
散落到各页面就一定会漂移 —— 本轮白屏就是"详情页自己判了一次"的结果。

### ⚠️⚠️ 「目标章」信号必须**三通道**：序号给自绘、**href 给 epub、标题给 txt**（2026-10-03 二次重修）

两条内核的**坐标系不可互换**，所以**不能共用一个 number**：

| 坐标系 | 来源 | 口径 |
|---|---|---|
| **应用侧章序号** | `TextFile.parseToc` 的 `toc[i].index = i` / `EpubFile.parse` 的 `ch.index = i` | 逐**应用 spine 数组** |
| **SDK 侧 `resourceIndex` / `catalogId`** | `PageDataInfo` / `CatalogItem`（SDK 解析器给出） | **SDK 自己的 spine / catalog 列表** |

二者对同一本书**不保证逐项相同** —— itemref 过滤策略、txt 长章拆分策略都可能不同
⇒ **跨内核传序号必然偏位**（表现为"点第 5 章进去是第 4 章"，偏差还随书而变）。

#### ⚠️⚠️⚠️ **txt 会让「href 通道」彻底失效**（2026-10-03 实证，推翻"href 统一解决一切"）

| 事实 | 取证 | 后果 |
|---|---|---|
| txt 的 `BookChapter.href` **恒为空串** | 全仓 grep + 真机 dump | `spineIndexOfHref()` 永远匹配不上 ⇒ href 通道**完全无效** |
| txt 全文只有 **1 个 spine** | `handler.getSpineList().length === 1` | 序号通道传任何值都跳不动（相邻章在**同一个 spine** 里） |
| SDK 的 txt 目录**多一条 `preface`** | `.rkprobe/catalog.json` 共 1647 条，第 0 条 `[0,"preface",0,0,false,361,0]`；应用侧 1646 条，逐项前 20 条 **0 不一致** | **SDK catalogId = 应用 index + 1**（恒定偏一章） |

⇒ **txt 的唯一可行通道是「章标题」**：`catalogByTitle(title)` 反查 SDK `CatalogItem`，走它的 `domPos`。

#### 三通道架构（各读各的键，谁适用谁生效）

| 键 | 类型 | 谁消费 | 单位 | 对 txt 有效 |
|---|---|---|---|---|
| `readerJumpChapter` | `number` | `ReaderPage`（自绘） | **章序号**（与自身 `toc` 同源，自洽） | ✅ |
| `readerJumpHref` | `string` | `ReaderKitPage`（Kit） | **epub 资源路径** | ❌（恒空串） |
| `readerJumpTitle` | `string` | `ReaderKitPage`（Kit） | **章标题** | ✅（唯一通道） |

`ReaderKitEngine.start()` 三级降级：**href 命中 → 标题反查 → 保留已存进度**（且**绝不静默跳错**，日志留痕 + 页面 toast）。

`catalogByTitle()` 三级匹配：全等 → 去空白全等 → **双向包含取最短**（末级容忍 SDK 标题带前后缀）。

#### ⚠️ 正解不只是"换算"，更是**让两侧目录逐项对齐**

与其在跳章时做偏移换算（易漂、随书而变），不如**让应用目录补齐 SDK 那条 `preface`**：
- `TextFile.prependPrefaceIfNeeded()` —— 首章标记前有 ≥ 8 个**实质字符**（去空白后）才补「序章」；
- **幂等**：首条本身是序章/楔子/前言类标题则跳过；
- **有门槛**：很多 txt 首行就是「第1章」，前缀只有 BOM/空行 —— 那种书**不该**凭空多出空章。

补完两侧目录**逐项一致** ⇒ index / href / 标题三条通道**同时归零偏差**。

★ **标题用「序章」而不是照抄 SDK 的 `preface`** —— 那是**给读者看的目录项**，不是内部字段名。

#### ⚠️⚠️ **改了目录解析器必须升缓存版本号**

```ts
const TOC_SCHEMA_VERSION = 2;   // 参与 tocPrefKey
tocPrefKey = `toc_v${TOC_SCHEMA_VERSION}_${shortHash(bookUrl)}`
```

**不升版 = 老书的旧目录永远命中缓存、永不重解析** ⇒ 表现为「改了解析逻辑但真机毫无变化」。
凡改动 `TextFile.parseToc` / `EpubFile.parse` 的**结构**（增删条目、改编号口径），必须 `+1`。

**正确架构（原 href 双信号版，仍适用于 epub）：**

| 键 | 类型 | 谁消费 | 单位 |
|---|---|---|---|
| `readerJumpChapter` | `number` | `ReaderPage`（自绘） | **章序号**（与自身 `toc` 同源，**自洽**，不需要换算） |
| `readerJumpHref` | `string` | `ReaderKitPage`（Kit） | **epub 资源路径**（`BookChapter.href`） |

```
BookDetailPage.jumpTo(ch)                        // 传整个 BookChapter，不是 index
  → openReaderFlow(url, ch.index, ch.href, ch.title)
    → AppStorage('readerJumpHref')   = ch.href
      AppStorage('readerJumpTitle')  = ch.title
      → ReaderKitPage.aboutToAppear → pendingChapterHref / pendingChapterTitle
        → ReaderKitEngine.start(..., chapterHref, chapterTitle, ...)
          → spineIndexOfHref(href) 命中 → 重写 spineIndex
            未命中 → catalogByTitle(title) 反查 → 走 CatalogItem.domPos
```

★ **换算必须落在 `ReaderKitEngine.start()` 内部**（`await bookParser.getDefaultHandler()` **之后**）：
只有这里拿得到 `handler.getSpineList()`。页面层拿不到，不要试图在页面里换。

★ **换到 href 时同时清掉 `domPos`**：跳章 = 定位到章首，残留的章内字符偏移会让它跳到章节中段。

★ **`openReaderFlow` 的 `targetHref` 默认空串** ⇒ 书签页 / 搜索页等既有调用点行为**完全不变**，
可以把"扩范围"留作后续候选（见下方进度条小节对 `SearchPage` 的告警）。

★ `normalizeHref` 只做 **`./` 前缀剥除 + `/` 前缀剥除 + 连续 `/` 折叠**，
**刻意不做 `..` 展开与百分号解码** —— 过度归一化会让不同资源误命中同一项。
匹配链按 **全等 → 剥 `#fragment` → 归一化** 三级降级，逐级 `AppLogger.info` 打出命中层级。

**本轮踩的坑（两次）**：
1. Kit 侧**全文件 0 命中** ⇒ 详情页下发的目标章被静默丢弃（自绘有、Kit 没有）。**加跨页信号时务必 grep 两个内核都落了消费点。**
2. 我第一版按"目录下标 vs spine 序混用"改造（给 `start()` 加 `catalogIndex` 反查）——
   **根因判错**。一条 `git show HEAD:<file> | grep <信号名>` 就能证伪（HEAD 版**根本没消费任何跳章信号**）。
   ⇒ **改根因前先验证旧代码里这条链路是否存在**，别对着想象中的 bug 改。

⚠️ **`@Watch` 信号不能传给"新开的页面实例"**：`AppStorage` + `@Watch` 的跳转信号
（本工程的 `readerSearchJump`）语义是"**给已经活着的页面**换定位"。若用户是从**详情页**
进搜索/书签页、点条目时栈里**没有阅读页** ⇒ 走的是「新开一个阅读页实例」，
而 **`@Watch` 在组件初始化时不触发**（只在值变化时触发）⇒ 新实例读不到刚写的信号，
会停在旧进度章。⇒ 凡是"开新实例"的分支，必须**额外走入口的 `targetChapter` 参数**
（初始化期路径），不能只写信号。

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

### ⚠️⚠️ 启动幂等标志的**置位权必须唯一**（2026-10-03 真机实证，P0）

「就绪后启动」通常写成两个方法：`startIfReady()`（门控，等视口/SDK 就绪）→ `start()`（真正下发）。
若 `startIfReady()` 里**自己先置位** `this.started = true`，而 `start()` 头部又有防重入守卫
`if (this.started && !this.disposed) { session.release(); this.started = false; }`，
则**首次正常启动就会被判定为重入** ⇒ 立刻 `off('pageShow') + off('resourceRequest') + releaseBook()`
把自己刚 `adopt` 的控制器释放掉。

**真机症状（极像 SDK 的锅，极易误判）**：
```
PreLayoutByChapter error for paraVec is empty      ← 反复，实测 7109 次 / 26 秒
getLitePageData failed try again
getSpineItemContent                                ← 实测 7105 次
```
主线程被占满 ⇒ 用户看到「**一直显示正在排版 + 整页点不动**」。
日志量是最好认的信号：**正常约 1 万行 / 死循环约 19 万行**（同窗口长度）。

**修法（三处，缺一不可）**：
1. `startIfReady()` 里**删掉** `this.started = true`，只保留"清看门狗 + 调 `start()`"；
2. `start()` 的**重入守卫之后**才置位 `this.started = true`（同步置位可挡住连点并发）；
3. `start().catch()` 里**复位** `this.started = false`（否则用户点「重试」会被自己的守卫当成重入 ⇒ 再走一遍 release）。

> 判据：只要日志里出现 `releaseBook` 而**用户并没有做"重进/重试"动作**，就说明启动期存在**自我释放**。
> 语义总结：**`started` 的置位权只归 `start()`**，门控方法不得代庖。

**相关次要根因**：`[OpenGL]: Init failed`（仿真翻页 `flipMode='0'` 依赖 native
`interactive`/OpenGL 模块；初始化失败会让 `paraVec` 恒空）。若自身释放已修但仍自旋，
试把 `flipMode` 换 `'1'`（横滑）绕开仿真路径再验。

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

⚠️ **2026-10-03 用户裁决改口径：阅读页用「只隐状态栏、保留导航条」，不做全屏**
（用户原话：「我看别人进来都是隐藏状态栏的」）。
**比全隐更保守**：底部手势区不消失，用户随时能上滑退出，不会把自己困在阅读页。
（原文那句「`['navigation']` 是给普通页面用的、不能复用于阅读页」**已作废**。）

### ⚠️⚠️ 但**不要**用 `setWindowSystemBarEnable(['navigation'])` 实现它 —— 白名单语义会连带吃掉手势条（2026-10-03 二次定案）

`setWindowSystemBarEnable(names)` 是**白名单**：**未列入的栏一律隐藏**。

| 写法 | 实际效果 | 判定 |
|---|---|---|
| `['navigation']` | 状态栏隐 + **`navigationIndicator`（底部手势条）也隐** | ❌ 用户实测原话「**底部手势条也没了**」 |
| `[]` | 三件套全隐（真全屏） | ❌ 用户不需要 |

**正解 = 细粒度 API `setSpecificSystemBarEnabled(name, enable, enableAnimation)`**（API 11，`SystemCapability.Window.SessionManager`），逐条点名、**只关想要的**：

```typescript
import { window } from '@kit.ArkUI';
// 逐条设置系统栏可见性（name 取值三选一）
//   'status'              = 状态栏
//   'navigation'          = 三键导航栏
//   'navigationIndicator' = 底部手势指示条
async function applySpecificBar(ctx: common.UIAbilityContext,
                               name: 'status' | 'navigation' | 'navigationIndicator',
                               enable: boolean, animMs: number): Promise<void> {
  const win = await window.getLastWindow(ctx);
  await win.setSpecificSystemBarEnabled(name, enable, animMs > 0);
}
```

隐藏状态栏 = **两条**，缺一不可：

```typescript
await applySpecificBar(ctx, 'status', false, 0);              // 关：状态栏
await applySpecificBar(ctx, 'navigationIndicator', true, 0);  // 显式保：底部手势条（关键）
```

★ 三点纪律：
1. **`'navigation'` 是「三键导航栏」，不是「导航区」** —— 想保留底部手势条要设 `'navigationIndicator'`，名字别混。
2. **必须显式补 `true`**：白名单式的旧 API 若在别处被调用过，基线可能已被改脏；**每次隐藏都成对写**（关 `status` + 显式保 `navigationIndicator`）。
3. 加**有界重试（2 次）+ 旧 API 回退**：`setSpecificSystemBarEnabled` 属 SessionManager，个别机型/低版本可能不支持，回退到 `setWindowSystemBarEnable(['navigation'])` 至少不会更差。

> **同轮定案：阅读页正文层的高度算式必须 `calc()` 包裹。**
> 这是「阅读页点不动」的第三个独立根因（前两个：`.rotate()` 投影、包裹层），
> 详见入口主册坑点表 **10b**。与本节的系统栏口径**直接耦合**：
> 隐藏成功 ⇒ `safeTop` 归 0 ⇒ 高度走 `'100%'`（合法）；**隐藏失败/未恢复** ⇒ `safeTop=38`
> ⇒ 必须走 `'calc(100% - 38vp)'`。**裸算式 `'100% - 38vp'` 非法 → 高度塌成 1px →
> XComponent 画面照常可见但热区为 0 = 全页点不到。** 两条分支都要合法，缺一不可。

### ⚠️ 工具栏/面板必须是**悬浮层**，绝不能改正文排版（2026-10-03 定案）

现象（用户原话）：「**点击打开工具栏为什么会导致排版上下被挤压 不是悬浮的吗**」。
根因：`onSafeAreaChange` 把"菜单/面板是否打开"也算进了正文避让判断 ⇒ 一开工具栏正文就位移。

正解 —— **菜单/面板开合不得进入排版算式**，用短路标记排除：

```typescript
const overlayOpen: boolean = this.showMenu || this.anyPanelOpen();
const menuDriven = this.safeTop === 0 || !this.statusBarVisible || overlayOpen;
```

并让正文层的 `margin.top` 走**与安全区同源**的单一函数 `this.layoutSafe()`，
不要在两处各写一遍 `safeTop`（会漂移）。工具栏用 `zIndex` + `Stack` 叠在正文之上。

⚠️ **窗口级连带效应（2026-10-03 定案）**：`setWindowSystemBarEnable` / `setStatusBarVisible`
是**窗口级**而非页面级 ⇒ ① 压在阅读页之上的子页（书内搜索/书签）会继承「无状态栏」，
须自己在 `aboutToAppear` 里恢复（否则 `SafeArea.top + 72` 里 `safeTop=0` ⇒ 标题贴屏幕顶边）；
② 子页 pop 回来后，宿主阅读页须**再补发一次隐藏**（信号走 `onPageShow` 转发；
⚠️ 该回调**只在 `@Entry` 组件触发**，阅读页组件本身不是 `@Entry`，必须由外壳页转发；
且写入 AppStorage 的**版本号要 `+1` 递增**——`@Watch` 只在**值变化**时触发，写死常量第二次起失效）。
③ 退出路径恢复状态栏要**立即**执行，不可排进转场延迟批次（否则状态栏在转场结束后才"弹回来"）。

隐藏系统栏后，上报的高度就是**整窗口高度**，不要再扣 `safeTop/safeBottom`。
⚠️ 但**组件高度仍要保持「动态读 `safeTop`」的形态**（`calc(100% - Nvp)` + `margin({top: safeTop})`），
不要写死 `'100%'`：隐藏是异步跨进程调用、可能被系统丢弃，**失败时 `safeTop` 仍是 38**，
必须让正文如实扣减，否则最后一行被状态栏压住。
⚠️ `margin` **不计入组件自身高度**，而 `height` 是显式给定的 ⇒ 组件真实高 == 上报 SDK 的
`viewPortHeight`（**严格同源**，多减/少减都表现为"最后一行显示不全"）。
⚠️ 包正文的根 `Stack` 要加 `alignContent: Alignment.Top`（默认 `Center` 会先垂直居中再被 margin 推下 ⇒ 底部溢出半屏）。

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

### ⚠️⚠️ `setPageConfig` **只改配置、不重新分页**（2026-10-03 真机实证，本轮最贵的一个坑）

**症状**：调字号 / 行距 / 视口尺寸后，面板上的数值变了、落盘的配置也变了，**但正文排版纹丝不动**
（用户原话：「**字号的调整似乎没有效果**」）。

**根因**：`ReaderComponentController.setPageConfig(setting)` 声明为**返回 `void`、无事件回执** ——
它只是把新 `ReaderSetting` 记进 SDK 配置，**不重排当前章**。已渲染的那一页是上次 `startPlay`
的分页结果，配置改了不会自动失效。

**正解**：改配置后用**当前页起点**再调一次 `startPlay` 触发重排：

```ts
// 页面侧：把当前定位一起传下去（不能只传 cfg）
const domPos = this.pageInfo !== null ? this.pageInfo.startDomPos : '';
this.session.applySetting(this.cfg, this.textW, this.textHeightOf(this.viewH),
  Math.max(0, this.spineIndex), domPos);

// 服务侧：setPageConfig 之后再 startPlay 同一位置
applySetting(cfg, viewW, viewH, spineIndex, domPos): void {
  if (!this.started) return;                       // 未就绪时下发必被丢（见第 3 节）
  this.controller.setPageConfig(ReaderKitSession.toSetting(cfg, viewW, viewH));
  this.repaginate(spineIndex, domPos);             // ⇒ 真正触发重排的是这一步
}
```

⚠️ **重排闸门必须做**（连续点 `A+` 会连发多次）：正在跑就只记下**最新**目标（覆盖旧的），
当前这趟跑完再补一趟；**绝不并发两趟 `startPlay`**（SDK 侧互相打断、`pageShow` 语义错乱）。

⚠️ **不要在重排时顺手改排版安全区口径**：状态栏随菜单显隐会让 `safeTop` 在 38↔0 之间摆，
若每次都跟着重下发排版 = **每次唤出菜单都整章重排 + 正文上下跳**。正解是把排版口径
**冻结**成一个独立值（首次隐藏状态栏时定档），窗口真值只用于菜单卡片避让。

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
1.5. **点「继续阅读」/目录项进阅读页白屏、或点了没反应？** → 查调用点是不是**绕过了统一开书入口**
   （直接 `AppRouter.push(阅读页)`）。★ 指纹 = **只有 `filePath` 非空的书**白屏（它们才需要 Kit），
   且 `push` 会被 `checkDuplicate`（同名 + 同参）静默拦掉（见第 2 节红字）
2. **配置/观感不对？** → 查数据库该书的 `filePath` 是否非空 ⇒ 判定实际内核
   - 非空（走 Kit）→ 查落盘配置是否覆盖了默认值（第 6 节）
   - 空（走自绘）→ 查开书链路的沙箱拷贝为何失败
3. **`setPageConfig` 抛 `1016910002`？** → 抢跑（组件未挂载），加重试（第 3 节）
3.5. **改了字号/行距/视口但正文纹丝不动？** → `setPageConfig` 不重排，必须补一次
   `startPlay(当前 spine, 当前页 startDomPos)`（见第 8 节红字；带合并闸门）
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
12. **⚠️ 正文「看得见、点不动、翻不了页」（本页最快排查项，先查这条）？** →
    ① **长度算式合法性**：`.height()` 是不是**裸算式**（无 `calc()` 包裹）⇒ 高度塌成 1px ⇒
       热区为 0（`XComponent` 画面不受布局约束、照常可见 ⇒ 症状极隐蔽）。见主册坑点表 **10b**、本节第 4 节。
    ② 正文之上/之下有没有**包裹层**或**几何变换**（`scale`/`rotate`/`translate`）——
       ArkUI 命中测试按**变换后几何**计算，而 `XComponent` 画面不受变换影响。
       历史两轮同症状根因：`.rotate({angle:-90, centerX:0})`（投影宽→0）、自定义包裹组件
       （违反「阅读组件必须直挂页面根」）。
    ③ **判据**：画面正常 + 交互全废 ⇒ 必是「绘制与命中解耦」类问题，先查命中侧（几何/算式），
       别去查 SDK 或手势注册。
13. **从书内搜索/书签页返回后，状态栏又出来了（隐藏被破坏）？** →
    `setWindowSystemBarEnable` 是**窗口级**：子页恢复过状态栏，宿主阅读页必须**再补发一次隐藏**。
    信号走外壳页的 `onPageShow` 转发（该回调只在 `@Entry` 触发），且版本号要 `+1` 递增（第 4 节）。
14. **⚠️ 一直显示「正在排版…」+ 整页点不动（不是白屏、正文看得见）？** →
    **先数日志行数**：万级正常、十几万级 = 死循环。查 `paraVec is empty` / `getSpineItemContent`
    的重复次数。**首要怀疑"启动期自我 `releaseBook()`"** ⇒ 见第 3 节末「启动幂等标志的置位权必须唯一」。
    另：日志出现 `[OpenGL]: Init failed` ⇒ 仿真翻页（`flipMode='0'`）依赖的 native 模块没起来，
    换 `'1'`（横滑）验证。
15. **正文看得见但"状态栏还在 / 顶部被压住"？** → 先分清两件事：
    `setWindowSystemBarEnable([])` = 状态栏+导航条全隐（真全屏）、
    `setWindowSystemBarEnable(['navigation'])` = **只隐状态栏**。
    用户说"隐藏状态栏就行"时**不要**上全屏方案；且窗口级设置会连带子页与退出路径（第 4 节）。
    ⚠️ 别把 **App 级**的 `setWindowLayoutFullScreen(true)`（布局底座，`git log -S` 可查引入点）
    误当成阅读页的页面级开关 —— 动它会影响整个 App。
