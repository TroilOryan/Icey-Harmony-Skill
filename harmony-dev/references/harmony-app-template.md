> **分册：`harmony-app-template` 主册** ｜ 原独立技能 `harmony-app-template`，2026-10-03 合并进 `harmony-dev`。
> 配套：`references/harmony-app-template/file-map.md`（文件职责表）、`references/harmony-app-template/workflows.md`（W1~W8 可复制代码）、`../assets/template/`（可移植模板工程副本）。

# 鸿蒙 App 模板基建 v1.3.11

> 📦 **本 Skill 自带模板工程副本**（`../assets/template/`，79 文件 / 1.2MB）——
> 整个 Skill 目录拷到任何机器都能直接起新鸿蒙 App，不依赖外部工程。

> 一份生产项目实战沉淀的 **HarmonyOS / ArkTS 应用脚手架方案**：
> 新建/扩展鸿蒙 App 时，不要从空工程起步，而是复用「已验证基建」——
> HDS 导航/标题栏、路由、弹窗、设置持久化、主题、安全区、日志七件套一次到位，
> 避免在每个新项目里重复踩同一批坑。

**本 Skill 是什么**：一套「读模板 → 按工作流剪裁 → 按铁律改代码」的操作规程。
**不是什么**：不是 ArkUI 语法教程 —— 语法查官方文档，这里只放**模板特有**的决策与坑。

---

## ⚡ 快速开始（30 秒选模式）

```
用户要什么？
├─ 🆕 从零起一个新鸿蒙 App
│    └─→ W1 新建项目（复制内置模板 → **先修附录 C 的 D1~D9** → 改 bundleName → 对齐本机 SDK → 按清单裁剪）
│
├─ ➕ 在已有工程（通常已是本模板）里加东西
│    ├─ 加一个底部 Tab            → W2
│    ├─ 加一个子页 + 路由跳转      → W3   ★最常用
│    ├─ 加一个持久化设置项         → W4   ★最常用
│    ├─ 加一个弹窗（底部/确认/选项）→ W5
│    ├─ 加一个图标                → W6
│    └─ 接自定义背景 / 毛玻璃      → W7
│
└─ 🔧 出问题了
     ├─ hvigor / 编译报错          → W8 + §4 坑点速查表
     ├─ 界面表现不对（留白/错位/颜色）→ §2 铁律 #11~#16 + §4
     └─ 「改了没生效」              → 先看 LSN-002（改错了地方 / 缓存）
```

> 💡 **提醒**：如果你要的功能模板里没有（比如视频播放、网络层），本 Skill 负责保证
> **它长在正确的骨架上**（scaffold/sheet/setting/router 四件套），不含业务实现。

---

## 0. 第一步：定位模板源（必做）

改动必须以真实模板为准，**禁止凭记忆写代码**。**本 Skill 自带模板副本**（`../assets/template/`），
换机器开箱即用，按三级顺序定位：

```
① 内置副本（首选，可移植）   <skill>/assets/template/
   └─ 79 个文件 / 1.2MB，含全部 34 个 .ets 与工程配置
   └─ 新建项目（W1）直接用它；改它之前先想清楚：改的是「模板资产」还是「用户工程」

② 环境变量（团队/老机器自定义源）   $HARMONY_TEMPLATE_HOME

③ 用户当前工程（扩展已有 App 时）
   └─ 判定是否为模板衍生：同时存在 layout/Index.ets + model/AppRouter.ets +
      components/SubPageScaffold/ = 是，按本 Skill 规程改
   └─ 不是模板衍生 → 先按 W1 用 ① 起工程，或只借鉴写法（此时铁律仍适用，路径全部换成用户工程）
```

> **W1 与 W2~W8 的区别**：W1 从 ① 复制；W2~W8 改的是 **③ 用户当前工程**。
> 不要直接改 ① 内置副本 —— 那是模板资产，改了会污染以后所有新项目。

**定位成功后必须先读这 5 个文件再动手**（它们是所有决策的依据）：

| 顺序 | 文件 | 你从中获得什么 |
|---|---|---|
| 1 | `entry/src/main/ets/layout/Index.ets` | 主布局结构、路由分发点、Tab 列表 |
| 2 | `entry/src/main/ets/entryAbility/EntryAbility.ets` | 初始化顺序、全屏/SafeArea、前后台信号 |
| 3 | `entry/src/main/ets/model/SettingsManager.ets` | 持久化写法的唯一范本 |
| 4 | `entry/src/main/ets/model/ThemeManager.ets` | 色彩 @StorageLink 版本号机制 |
| 5 | `README.md`（模板根） | 完整铁律原文（122 条经验，本 Skill 取其纲要） |

> ⚠️ **路径铁律**：模板路径可能随机器/磁盘变化。所有输出的路径必须是**本次定位到的真实路径**，
> 禁止沿用上一次会话记忆里的盘符。Skill 自身目录也要先定位再引用（常见位置：
> `~/.workbuddy/skills/harmony-app-template/`），不要假设它在某个固定盘符下。详见 LSN-005。

**内置副本内容清单与排除项**见 `../assets/TEMPLATE_MANIFEST.md`。

---

## 1. 模板提供了什么（能力清单）

| 层 | 能力 | 关键文件（均在 `entry/src/main/ets/`） |
|---|---|---|
| **导航** | HdsNavigation + HdsTabs 悬浮底栏、Tab 瞬时切换、全 Tab 预加载 | `layout/Index.ets` |
| **标题栏** | 滚动渐变模糊（GRADIENT_BLUR + ADAPTIVE 材质），主页/子页/详情页三套配置 | `model/TitleBarStyles.ets` |
| **子页** | 一行代码建子页（HdsNavDestination + 标题栏 + 背景 + 宽屏 embedded） | `components/SubPageScaffold/` |
| **路由** | 全局单例 NavPathStack + 重复页拦截 + 携带参数 | `model/AppRouter.ets` |
| **安全区** | 全屏后手动避让，含挖孔合并、旋转/avoidAreaChange 动态刷新 | `model/SafeArea.ets` |
| **持久化** | preferences 增量写 + 300ms 防抖 + saveNow 双保险 | `model/SettingsManager.ets` |
| **主题** | 跟随系统/强制深浅/自定义背景 + 版本号驱动全局重建 | `model/ThemeManager.ets` |
| **弹窗** | AppSheet（手机底部/宽屏居中 dialog 自适应）+ 同组互斥 + 退后台自动关 | `components/AppSheet/`、`services/SheetManager.ets` |
| **弹窗内容** | SheetContainer（限高+Scroll）、ConfirmSheet（danger）、OptionSheet（选项） | `components/SheetContainer|ConfirmSheet|OptionSheet/` |
| **设置 UI** | SettingItem / SettingsGroup / SettingsGroupCard / GlassCard / AppSwitch | `components/*` |
| **日志** | 内存环形缓冲 500 条 + 调试模式落盘 Download + 导出 picker | `services/AppLogger.ets` |
| **其它** | 全局 Context、系统栏 Helper、更新日志、文件授权、官方符号图标体系、**沉浸光感材质**（`services/SystemMaterial` + `components/MaterialCard`：卡片 / hero 沾色 / 弹窗 / chips 四形态 + 降级毛玻璃 + 诊断行）、**自定义壁纸**（`ThemeManager.setCustomBg` + 相册选择器 + 三链路状态重放） | `services/*`、`components/MaterialCard/` |

**完整文件职责表见** `references/harmony-app-template/file-map.md`。

---

## 2. 核心铁律（违反必出 Bug）

> 全部来自真机验证。每条都是「不这么做 → 就会出现某个具体现象」。

### 启动与恢复

| # | 禁止行为 | 后果 | 正确做法 |
|---|---|---|---|
| **00** | 拿内置副本当工程直接改 / 新建项目后不修缺陷 | 改坏模板资产（污染后续所有新项目）；或首次构建必然失败（D1/D2/D5/D6/D7/D8） | 新建项目一律 `cp -r` 出去再改；复制后**第一件事**是按附录 C 把 D1~D9 全扫一遍（详见 LSN-013） |
| **01** | `loadContent` 里 `await startupReady` | 数据恢复耗时可观 → 白屏久驻 | **UI 优先，永不阻塞**：立即 loadContent，恢复后台跑完写 AppStorage 响应式刷新 |
| **02** | 多个 `init()` 不各自包 try-catch | SettingsManager 挂了 → **所有设置静默丢失** | 每个 init 独立 `try{}catch{}`，一个失败不中断后续 |
| **03** | 初始化顺序随意 | 依赖设置的模块读到默认值 | `SettingsManager.init` **必须最先** |
| **04** | 只靠 300ms 防抖落盘 | 防抖未到期被杀进程 → 设置丢失 | `onBackground` / `onDestroy` 必须 `saveNow()` |

### 布局（最高频出错区）

| # | 禁止行为 | 后果 | 正确做法 |
|---|---|---|---|
| **05** | 页面根 Column 用 `height('100%')` | 在 Hds TabContent 内**溢出约 50vp** | 用 `.layoutWeight(1)` |
| **06** | `layoutWeight(1)` + `justifyContent(SpaceBetween)` 联用 | 子项高度异常、内容离屏 | 二者禁止同用 |
| **07** | 顶部留白硬编码 `112` | 换机型/折叠屏错位 | `Row() {}.height(SafeArea.top + 72)`（状态栏 + MINI 标题栏 56 + 16）。⚠️ **2026-10-01 修正：`+64` 已废弃**——因为 `maskExtraHeight: 28` 的滚动模糊带下缘是 `56 + 28 = 84vp`，`72` 才让内容出带；**且首卡必须自带 `margin-top: 12`**，否则卡顶停在 72、仍压在模糊带里（读作「卡片贴着标题栏、没有间距」）。见铁律 **14b** |
| **07b** | 子页（`HdsNavDestination`）与 tab 主页留白「同值却仍不等」 | 反复调 `SafeArea.top + N` 永远调不平 ⇒ 用户反复报「离顶部不统一」 | ⚠️ **先分清用户要的是哪一种「统一」**：<br>（a）**和参考工程统一**（原话「还是没和 player 统一啊」）→ 逐条抄对方**对应页面**的数字，**不要自创一个让两侧相等的数**；<br>（b）两侧彼此相等 → 那条路历史上连续改错 4 轮，**不要走**。<br><br>**2026-10-04 定案（Icey-Reader，口径 a；本口径以后为准）**：<br>| 侧 | 参考工程（`Icey-Player-Harmony`）代码 | 对方首卡顶 | 本工程落位 |<br>|---|---|---|---|<br>| 设置主页（tab，不走骨架） | `List({ space: 0 })` + `Blank(SafeArea.top + 72)`，卡自带 `top: 0`、间距靠卡内 `margin bottom: 16` | **72** | `List space → 0`；信息卡补 `margin bottom: 16` ⇒ **72** |<br>| 设置子页（走骨架） | `Blank(SafeArea.top + 72)` + 骨架 `margin top: -10` + 卡自带 `top`（2026-10-06 起为 **16**） | 当时 **74**（`top:12`）；现首卡顶 +4 | 骨架恢复 `-10` + `height 'calc(100% + 10vp)'`（成对） ⇒ **74** |<br><br>对方自己就是「72 vs 74」（差 2vp，观感不可辨）—— **抄这个差，不要去消灭它**。<br><br>❗**「两个工程不同构」是曾经用错的反驳理由**：曾以「本工程 `HdsNavDestination` 多写了 `.ignoreLayoutSafeArea([0],[0])`」为由把骨架补偿归零；实查 player `components/SubPageScaffold:138` **写着完全相同的一行**（+ `.titleMode(100)`）。⇒ **容器属性要逐项 diff 后再下不同构的结论**；两侧 `Stack/Column` 结构 + `HdsNavDestination` 属性全同、唯一差异就是那个常数时，**照抄就是最正确的做法**。见铁律 **14c** |
| **08** | 内容顶部加固定空白 Column 做避让 | 内容被滚动模糊带压住 | List **视口顶到屏幕顶**，留白放**第一个 ListItem**，内容自然滑进模糊带 |
| **09** | List 尾部不预留 | `barOverlap` 悬浮底栏遮住最后几项 | 末 ListItem `Blank().height(SafeArea.bottom + 80)`（子页 +40） |
| **10** | 卡片用 `width('100%')` 同时又给 margin | 溢出 → 边距不生效 | 左右间距交给**父容器 ListItem padding** 或 GlassCard 自带 margin |
| **10b** | **动态高度/宽度写「裸算式」**：`.height('100% - 38vp')`（无 `calc()` 包裹） | ⚠️ **P0**：官方行为是「**异常值时 `height` 恢复到不配置时的默认行为**」⇒ 高度**塌回内容高度**（不是撑满）。**若该层是 `XComponent`（SDK 直绘 GPU surface）⇒ 画面照常满屏可见、命中测试按节点几何算 ⇒ 热区为 0** = 「**看得见、点不动、翻不了页**」这个最难排查的组合 | 一律 `calc()` 包裹：`.height('calc(100% - 38vp)')`（运算符两侧留空格，API 10+）。**凡动态算式全项目统一 `calc(...)`**；模板合规样板 `SubPageScaffold` 的 `'calc(100% + 10vp)'`。⚠️ 排查「点不动」时**先查长度算式合法性**——这个组合已在阅读页（`ReadPageComponent`）连爆三轮同症状、第三轮才是本根因 |
| **10c** | **对齐另一个工程的「顶部留白」时，直接抄它的 Blank 值** | 恒偏一个说不清的常数（本工程 reader 首页抄 player 会差 **44**）——因为对方的 Blank 里含**它自己的**结构补差（player `MediaLibrary` 的 44 = 「空第 1 行 + 标题行」，reader 标题栏是纯文字 MINI 栏，没有那两行） | **对齐目标必须是「首个内容块顶的绝对值」而不是 Blank 值**。先算清对方的**目标值**（player 注释原文：`目标首卡顶 = SafeArea.top + 128`），再反推本工程 Blank = `128 − 首个内容块自带 margin`。⚠️ 写成**两个常量相加**（如 `HOME_TOP_BLANK_VP = 116` → 注释成 `72 标题栏 + 44 锚点间距`），让"补差项"在代码里看得见，不许塌成魔法数 |
| **10d** | **列表类不给 `fadingEdge` / 弹簧** | 上下边缘硬切割（内容在视口边缘"一刀切"），滚动到底无回弹——与项目其它列表**两套手感** | 列表统一口径：`.edgeEffect(EdgeEffect.Spring)` + `.fadingEdge(true, { fadingEdgeLength: LengthMetrics.vp(24) })`（`LengthMetrics` 从 `@kit.ArkUI` 导入）。⚠️ `fadingEdge` **只在内容溢出可视区时**才有渲染；内容不满屏时它「没效果」是**正常**的，不要误判成没生效。⛔ **例外：被「渐变模糊」压住的那类列表不要挂 `fadingEdge`** —— 它与 `linearGradientBlur` 会**双重淡出**，且 `fadingEdge` 是**上下两端同时渐隐**（用户往往只要求顶部）。⚠️ 但用户说「列表要能滚到标题下面」时，**先查的不是 fadingEdge，而是顶部留白放在哪**：写在**内容层 padding** 上 = 属于内容 ⇒ 吃掉同样多的滚动行程 ⇒ 内容最多滚到留白下沿，标题带那一片永远是空的。正解见 **10f** |
| **10e** | 分段控件 / 标签自绘一套、页面里另一套 | 同 App 内**两套视觉语言**（用户会逐项指出"和首页那个不统一"） | **口径唯一化**：分段控件直接用页面内既有的胶囊 tag 语言。样板参数（本工程 reader）：`34 高 / borderRadius 17 / fontSize 14 / padding {left:16,right:16,top:7,bottom:7}`，未选态挂 `MaterialCardLayer({ layerRadius: 17, layerShadow: false, scope: 'menu' })`，选中态 `colors.accent` 实色，材质不可用回落 `colors.buttonBg` |
| **10f** | 整页列表要「内容能滚到标题栏下面 / 被标题带渐变糊住」 | 顶部留白写在**内容层 padding**（外面包一层 `Scroll` 时更常见）⇒ 留白算进内容高 ⇒ 滚动行程白丢那么多 ⇒ 标题下永远空虚；或用了 `backdropBlur` ⇒ **均匀**模糊、带边界强度**突变** ⇒ 一条硬切割边 | **两件事都要做**：<br>① **留白改成滚动容器的第一个 item**（`ListItem() { Row() {}.height(topBlank()) }`）——item 能被完整滚出视野，天然可滚进标题带；用模板 `SheetContainer` 时同时传 `contentScroll: false` + `contentTopPad: false`。⚠️ 此后所有 `scrollToIndex` 下标 **+1**。<br>② 渐变模糊用 `linearGradientBlur`（**前景**模糊，糊组件自身内容 ⇒ 无硬边），**带长 = 该页顶部静止留白**（整页列表不能沿用弹窗 `blurBandVp` 的反推值，后者隐含「静止留白只有 64vp」）。Icey-Reader 已把该换算导出为 `SheetContainer.blurStopsForBand(bandVp, componentHeight)`。<br>③ 顺带：横向留白从**内容层**下放到**行**（列表必须全宽，模糊才能满幅铺开）。 |
| **11** | 设置页「主页」与「子页」各写一套分组卡片组件，间距/内边距各填各的 | 用户在两个页面之间来回切换时肉眼能看出**卡片间距不一样、内边距也不一样**（主页更宽 / 子页更紧），但每处单看都「合理」⇒ 极难自查出来 | **两套组件的间距口径必须逐项对齐，只允许「对齐自己那侧文字列」的一处例外**：<br>① **卡间距**统一 `16vp`（主页用 `margin({bottom:16})`；子页用 `margin({top:16})` + 无 bottom，两者都靠「后一张卡的 top」隔开 ⇒ **子页千万不要既没bottom 又把 top 写小**，那是间距变小的唯一来源）；<br>② **卡片内边距**统一恒定值（如 `padding({top:6, bottom:6, left:1, right:1})`）——❌ 禁按「有无标题 / 有无图标」分档（如有标题 3/3、无标题 6/6）⇒ **带标题的那种卡会比另一种紧 3vp**，用户看到的正是这一处；标题行自带 `padding`，不依赖卡片顶部留白定位；<br>③ **唯一允许不同**：Divider 左缩进。主页项带图标 32vp ⇒ `margin({left:52, right:8})`（12+32+8 对齐图标后的文字列）；子页项无图标 ⇒ `margin({left:12})`。**两侧各自对齐自己那侧的文字列，不是 bug。**<br>⚠️ **排查姿势**：页面里搜不到这些数值（都封在组件里）⇒ **下钻到组件定义**`grep -rn "SettingsGroup" --include=*.ets` 对比两个组件的 `margin/padding/Divider` 三处，差异一眼可见。参考实现 `Icey-Player-Harmony/components/SettingsGroup`（主页口径基准）与 `components/SettingsGroupCard`（子页，向主页看齐）。见 **LSN-037** |
| **12** | 给 SDK **高级组件**（`SegmentButton` / `Select` / 相对布局类）传「先组装好的变长数组」当参数 | ⚠️ **P0 真机闪退**（编译绿、必崩）：`TypeError: Cannot read property icon of undefined` → 进程被杀。这类组件的形参常是**定长元组**（SDK 原文 `ItemRestriction<T> = [T, T, T?, T?, T?]`），SDK 内部会**逐元素读字段**（如 `item.icon`）⇒ 塞了 `undefined` 就崩 | **必须按实际个数构造元组**（分段 2~5 项 ⇒ 写 `buildOptions2/3/4/5` 各自 `buttons: [a, b]` …），**不要**「补齐到 N 个元素再传」。<br>⚠️ 也别写 `as SegmentButtonItemTuple` —— 那是**三路联合类型**，断言会报 `Type 'A' is not assignable to type 'B'`；**直接传元组字面量**，让 ArkTS 自己选支。<br>⚠️ 另：`SegmentButton` **不支持通用属性**（`.width/.height/.margin/.padding` 全无效、不报错），高度唯一旋钮 = `buttonPadding`，间距只能父容器给；`onItemClicked` / `enableStateAnimation` 是**构造参数**（链式写报 `does not exist on type 'void'`）。见 **LSN-038** |

### 标题栏渐变模糊（**四处配套，缺一不可**）

| # | 组件/位置 | 必须做的配置 | 缺了会怎样 |
|---|---|---|---|
| **11** | 标题栏配置对象 | `avoidLayoutSafeArea: true` | 标题文字被状态栏压住 |
| **12** | HdsNavigation / SubPageScaffold | `.ignoreLayoutSafeArea([0], [0])`（SYSTEM=0/TOP=0） | 状态栏后面是一条白/黑带 |
| **13** | 根 Stack | `.expandSafeArea([SYSTEM],[TOP,BOTTOM])` + `.backgroundColor(ThemeManager.colors.background)` | 顶部露出裸白条 |
| **14** | 滚动蒙层高度 | `maskExtraHeight: 28`（内容短的页调小） | 模糊带盖住卡片顶部 |
| **14b** | 顶部留白给了、首卡却**无自带 `margin-top`** | 卡顶正好落在模糊带内（`SafeArea.top+72` ＜ 带下缘 `84`）→ 用户报「卡片和顶部的距离明显不大对」 | **留白 + 首卡间距两件事**：`Row() {}.height(SafeArea.top + 72)` **且**首卡 `margin-top: 12`（卡片组件默认就带，别改成 0）。参考实现 `Icey-Player-Harmony`：`GlassCard` 恒带 `margin: { left:16, right:16, top:12 }`；⚠️ **2026-10-06 起设置子页的 `SettingsGroupCard` 已由 `top:12` 改为 `top:16`**（与设置主页 `SettingsGroup` 的 `margin bottom:16` 对齐，见铁律 **11** / LSN-037）⇒ **通用卡（GlassCard）与设置卡（SettingsGroupCard）的卡间距现在故意不同**：通用卡 12 是既有观感，不要为了「统一」去动它 |
| **14c** | 拿「看起来自洽的常数」反解容器偏移（如"子页低 22vp ⇒ margin 取 -22"） | **伪造推导**：用户在错误状态下仍说不统一 ⇒ 该常数被证伪，白改一轮 | **先算清楚两侧的完整公式，再动**。留白公式 = `Blank(safeAreaTop + 72)` + **首卡自带 `top`** + **骨架 margin 补偿**：<br>子页 = `72 + 12 + (骨架 margin)`；tab 页 = `72 + (List space)`。<br>⚠️ **2026-10-04 修正（推翻同日的补偿归零）**：先分清口径 —— 用户说「**和 player 统一**」时，目标是**逐条抄参考工程对应页面的数字**，不是让两侧相等。对方自己就是 72（主页）/ 74（子页）；本工程照抄同一对数字即可（`SettingsTab space → 0` + 卡自带 `margin bottom: 16` ⇒ 72；骨架 `margin top → -10` + `height 'calc(100% + 10vp)'` ⇒ 74）。<br>**「两侧必须相等」是一条会反复走错的路**（本工程连改 4 轮）；一旦用户口径是「和 X 统一」，就**只有一个依据：X 对应页面写的是多少**。<br>引入非零补偿的**前置动作**：先把两边的容器属性（`ignoreLayoutSafeArea` / `titleMode` / `Stack-Column` 层级）**逐项 diff**，确认确实不同构才允许不抄；不同构的结论必须有 diff 输出为证。仍不足 ⇒ 停止调 margin，改在两侧首内容节点打 `onAreaChange` **量 y** |

> 记忆口诀：**标题栏避让 + 组件 ignore + 根节点 expand + 内容留白** = 四处配套。

### HDS 组件

| # | 禁止行为 | 后果 | 正确做法 |
|---|---|---|---|
| **15** | 不逐层设透明 | Hds 默认背景层**压暗**透出的自定义背景图 | `TabContent` / `HdsTabs` / `HdsNavigation` 全部 `.backgroundColor(Color.Transparent)` |
| **16** | 低 API 设备用 Hds 枚举名 | 闪退（release 打包无导出） | 仅限 **Hds 自有枚举**：`GRADIENT_BLUR=2`、`HdsNavigationTitleMode.MINI=2`、`HdsNavDestinationTitleMode.MINI=100`、`SYSTEM=0`/`TOP=0`。⚠️ **系统 ArkUI 枚举（NavigationMode/BarMode/BarPosition/TabsCacheMode）必须用枚举名**，数值字面量会踩错值——真机实证：`.mode(1)` 意图 Stack 实为 **Split=1**（Stack=0）→ 整页压左半屏右侧空白；`TabsCacheMode.CACHE_BOTH_SIDE=0`（写 1 是 CACHE_LATEST_SWITCHED）。拿不准就查 SDK d.ts 的枚举数值，别凭记忆写 |
| **17** | 设置页不复位滚动位置 | 内容短不可滚时模糊带**常显**（像一直在滚） | `aboutToAppear` 里 `scroller.scrollToIndex(0, true)` |
| **18** | Tab 切换动画用默认 | 用户感知「点了要等」 | `.animationDuration(0)` 瞬时切换 + `cachedMaxCount(TAB_COUNT, TabsCacheMode.CACHE_BOTH_SIDE)` 预加载 |

### 主题

| # | 禁止行为 | 后果 | 正确做法 |
|---|---|---|---|
| **19** | 以为 `ThemeManager.colors` 会响应式刷新 | 改了主题界面不变 | `colors` 是 **static 非响应式**；组件必须 `@StorageLink('themeColorsVersion')`（或用 `@Prop themeVersion` 从父级传入），版本号 +1 后重读 |
| **20** | 弹窗背景用 `ThemeManager.colors.background` | 自定义背景时该色是半透明 → **弹窗能看见底层内容** | 弹窗一律 `ThemeManager.opaqueBackground` |
| **21** | 判深色写 `colorMode === 2` | 深浅判定完全反了 | **`DARK = 0`**（LIGHT=1、NOT_SET=-1） |

### 生命周期

| # | 禁止行为 | 后果 | 正确做法 |
|---|---|---|---|
| **22** | 在 `@Entry` 页面组件里写 `onConfigurationUpdate` | **根本不会被调用**（非标准回调） | 只能在 UIAbility 级实现 |
| **23** | 在 `onConfigurationUpdate` 里调 `setColorMode` | 再次触发回调 → **无限循环几百次** | 只刷新 ThemeManager + 系统栏字色 |
| **24** | `applyColorMode` 只调一次 | 窗口未建时首帧材质按错误模式解析 | 调**两次**：`onCreate` + `onWindowStageCreate` |
| **25** | 不监听 `avoidAreaChange` | 状态栏显隐不触发 windowSizeChange → SafeArea.top 残留旧值 | `windowSizeChange` + `avoidAreaChange` **都监听** |
| **26** | 只取 `TYPE_SYSTEM` 算左右安全区 | 横屏挖孔在左右缘却没避让 | 左右取 `max(TYPE_SYSTEM, TYPE_CUTOUT)` |
| **27** | 复位 `appBackgrounded` 版本号 | 依赖 +1 增量的 @Watch **永不再触发** | 版本号只增不减；「当前是否在后台」用布尔 `appInBackground` |
| **28** | 依赖非 @Entry 组件的 `onBackPress` | 不会被系统调用 | 统一在 `App.ets` 的 onBackPress 里判断状态 → 广播版本号信号 → 目标组件 @Watch 消费 |

### 弹窗

| # | 禁止行为 | 后果 | 正确做法 |
|---|---|---|---|
| **29** | 多个弹窗不设 `group` | 两层蒙层叠压 | 同页传同一 group（`Index` 根级用 `'index'`，页面级用 `'page:xxx'`）；嵌套弹窗留空/换组 |
| **30** | `bindSheet`/`bindMenu` 挂在自定义组件外层 | **点击不生效** | 挂原生组件（Row/Column/Stack）上 |
| **31** | `onDisappear` 里立即 `show=false` | 打断关闭动画 →「回弹一下才关」 | 延迟 300ms；且延迟期内若 `show` 已是 true（用户重开）**不能再设 false** |
| **32** | 宽屏 dialog 不处理退后台 | 回前台弹窗残留 | AppSheet 已内置 `appBackgrounded` 订阅；自定义弹窗必须自己加 |

### 状态管理

| # | 禁止行为 | 后果 | 正确做法 |
|---|---|---|---|
| **33** | 用 AppStorage 当持久化 | 重启即丢（它是内存态，≠PersistentStorage） | 持久化一律走 SettingsManager(preferences) |
| **34** | 声明了 `@StorageLink` 却在 build 里没引用 | 值变了不触发重建 | 跨层传递靠 `@Prop themeVersion` 显式传参 |
| **35** | 用布尔值做变更信号 | 同值 set 不触发 @Watch | 用**版本号信号**（每次 +1 恒触发） |
| **36** | 嵌套括号三元 `a ? (b ? x : y) : z` | 老 es2abc 解析器报 `',' expected` | 必须**纯链式三元**（用 `&&` 拍平并列分支） |
| **38** | 在 `@Builder` 里写非 UI 语句（`const d = this.calc()` / `if` 语句块） | 编译错 `10905209 Only UI component syntax can be written here` | 计算逻辑抽成 `private` 方法（返回文案/值），Builder 内只留组件调用；条件用组件级 `if (...)`（ArkUI 的 if 是合法 UI 语法） |

### 构建

| # | 禁止行为 | 后果 | 正确做法 |
|---|---|---|---|
| **37** | 并行构建 / 构建中编辑文件 | hvigor `[safe-delete]` 缓存损坏 | 删 `entry/build/default/cache/default/default@CompileArkTS`，前台串行 `--no-daemon` 重建；**本项目构建必须前台串行**。**「改了没生效」加强**：改源码后 CompileArkTS 仍 UP-TO-DATE 时，删 `entry/build/default/cache` + `.hvigor/report` 可能仍不够——再删 `entry/build/default/intermediates/loader*` 并 `touch` 源文件才能强制重编（Icey-Days 实证，同一会话内连续踩两次） |
| **38** | 只在 `signingConfigs` **数组**里配签名材料，不在 `products[]` 里**引用**它 | 产出 `entry-default-unsigned.hap`，真机安装报 `error:9568320 no signature file`（2026-09-16 实测，白折腾一轮） | 两处都要改：`app.signingConfigs[]`（材料）+ `app.products[].signingConfig: "default"`（引用）。模板里 `signingConfigs` 默认为**空数组**，配签名时才新增，故**不要**给模板预设引用（空数组时会报引用不存在）（见 LSN-017） |
| **39** | 改完 `bundleName` 直接 Run，不 Sync | IDE 缓存 `.idea/.deveco/project.cache.json` 的 `BUNDLE_NAME` 未更新 → 日志仍 `Launching <旧包名>`，装了个不存在的包 | 改 `app.json5` 后必须 **Sync / 重启 DevEco**；并注意 p7b 描述文件绑定 `bundle-name`，改包名即证书失效需重申请（见 LSN-017） |

---

## 3. 工作流索引

> 完整可复制代码见 `references/harmony-app-template/workflows.md`，此处只给决策要点。

| 编号 | 场景 | 涉及文件 | 关键点 |
|---|---|---|---|
| **W1** | 从模板新建项目 | 复制 `../assets/template/` → `build-profile.json5`、`AppScope/app.json5`、string.json、Index.ets | **先按附录 C 修 D1~D9（否则编不过）** → 改 bundleName → **targetSdkVersion 对齐本机 sdk-pkg.json 的 apiVersion** → DevEco 关联 SDK → 按裁剪清单删模块 |
| **W2** | 加一个底部 Tab | `layout/Index.ets` | Tab 数 +1、`tabTitles`、`TabItemBuilder`、注意 2<N≤5 |
| **W3** | 加一个子页 + 路由 | 新文件 + `AppRouter.ets` + `Index.ets` | 四步：建组件 → 加 ROUTE 常量 → navDestinationBuilder 分发 → push |
| **W4** | 加一个持久化设置项 | `SettingsManager.ets` + UI | **五步**（漏第 3 步 = 重启丢失，见 LSN-003） |
| **W5** | 加一个弹窗 | `AppSheet`/`ConfirmSheet`/`OptionSheet` | 按用途三选一；group、dismissible、不透明背景三要素 |
| **W6** | 加一个图标 | **无需新增任何文件**（用系统符号） | 从 `id_defined.json` 检索 `"type": "symbol"` 选名 → 直接 `SymbolGlyph($r('sys.symbol.xxx')).fontSize(22).fontColor([...])`。**禁止自研 SVG 图标组件**（见 LSN-020） |
| **W7** | 给卡片/控件加**沉浸光感** | `services/SystemMaterial.ets` + `components/MaterialCard/`（**模板已内置**） | 卡片改 `MaterialCard{...}`；小控件 `Stack{MaterialCardLayer+控件}`；hero 卡用「材质+半透明沾色」；弹窗配 `bindSheet backgroundColor:Transparent`。加「强制光感」开关走 SettingsManager 五步（键 `settings_forceMaterial`）。⚠️ 材质不生效**不报错**，必须真机截图验证（见 LSN-022）。**实色大卡改多卡**（表单 / 详情页多卡片化）见 **LSN-025**（控件描边 / 属性链位置 / 分卡边界） |
| **W8** | 加**自定义壁纸** | 复用 `ThemeManager.setCustomBg` + `FilePermission` | `PhotoViewPicker.select`（**字段是 `photoUris`**）→ `SettingsManager.setCustomBgUri(uri)` → `ThemeManager.setCustomBg` 背景半透明 → 根 Stack 底层 `Image.objectFit(Cover).expandSafeArea`。**三处链路重放状态**（App 启动 / onConfigurationUpdate / 设置变更）（见 LSN-023） |
| **W7** | 接自定义背景/毛玻璃 | `Index.ets` + ThemeManager | `hasCustomBg` 走 `applyThemeMode`；卡片自行判定 mao玻璃 or 实色 |
| **W8** | 排障 | — | 五层模型：源码 → 编译产物/缓存 → 工具 → 环境 → **改动是否为文件真身** |

**所有工作流的共同收尾动作**（不可跳过）：

1. 前台串行构建一遍（`#37`）
2. 真机跑一次并 `hilog` 确认 TAG 输出（每个模块都有 `const TAG`）
3. 若涉及既有判断逻辑的改动 → 全局 grep 同模式引用，改全（LSN-001）

---

## 4. 坑点速查表（想实现 X → 错写法 → 对写法）

| 想实现 | ❌ 常见错误写法 | ✅ 模板正确写法 |
|---|---|---|
| 页面占满剩余高度 | `.height('100%')` | `.layoutWeight(1)`（Hds TabContent 内 100% 溢出 50vp） |
| 顶部避让标题栏 | `Blank().height(112)` | `Row() {}.height(SafeArea.top + 72)`（`ListItem` 内 Blank 会编译失败，见下一行） |
| 读取当前主题色 | 定义 `@State color` 缓存 colors 值 | 每次 build 直接读 `ThemeManager.colors.xxx`，版本号驱动重建 |
| 弹窗背景色 | `ThemeManager.colors.background` | `ThemeManager.opaqueBackground` |
| 判断深色模式 | `colorMode === 2` | `colorMode === 0`（DARK=0） |
| push 子页 | `Navigation()` 新建一套栈 / 层层透传 stack | `AppRouter.getInstance().push(ROUTE_XXX)` |
| 子页读参数 | 子页 `@StorageProp('xxx')` 读初值 | `AppRouter.getLastParam()` + `aboutToAppear` 读（时序可靠） |
| 加一个开关 | 组件内 `@State` | `@StorageLink('settings_xxx')` + `SettingsManager.setXxx()` |
| 组件上弹菜单 | `.bindMenu()` 挂自定义组件外 | 挂原生 `Row` 上（见 `SettingItem` 的 withMenu 分支） |
| 关闭动画流畅 | `onDisappear` 立即 `show=false` | 延迟 300ms + 「期间用户重开则不覆写」竞态保护 |
| 底栏中央「+」大按钮 | 隐藏自带 bar（`barHeight(0)`）+ 自绘 customTabBar + 外层 Stack 叠加 | **5 页签方案**：「+」= 空 `TabContent` 占位（如 index=2）+ `onContentWillChange` 对该 index 返回 `false` 阻止切换 + `onTabBarClick` 弹弹窗——全程 HdsTabs 标准 API，无叠加层（用户实测否决自绘方案）。对齐细节：其他页签 `padding({bottom:4})` 使重心偏上，红钮需同级 padding（不够再 +2 微调） |
| 日期选择（公历/农历） | 手写三列滚轮（List+spacer+onScrollStop 回写索引，易索引/值错位）+ 手动闰月开关 | `getUIContext().showDatePickerDialog({start, end, selected, lunar, lunarSwitch: false, onDateAccept})`；单一公历事实源，口径 chip 弹窗外控制；onDateAccept 只回公历 Date（见 LSN-011） |
| 跑马灯「滚完暂停 N 秒」 | 指望 Marquee 自带暂停参数（**没有**）、loop=-1 一直滚、或 `.key(轮次)` 变更重建（**普通组件上的 key 被忽略**，告警「key 只能用于测试目录」，Marquee 停在 loop 结束态不再滚） | `if` 卸载/重挂载：暂停阶段渲染静态 `Text`（显示开头），滚动阶段挂载 `Marquee({start:true, loop:1})`，`onFinish` → 切回暂停并 `setTimeout` N 秒后重新挂载，循环往复；组件销毁 clearTimeout |
| 让组件重新初始化 | 改 `.key()` 期望重建 | 普通组件 `.key()` 无效（仅 ForEach/if 的 diff key 生效）；用 `if (条件)` 卸载再挂载 |
| 弹窗配色随主题 | 官方弹窗默认蓝选中项 #ff007dff | showDatePickerDialog 支持 selectedTextStyle/disappearTextStyle/textStyle（PickerTextStyle: color+font{size,weight}）+ acceptButtonStyle/cancelButtonStyle（API 12+），全部走 ThemeManager.colors |
| bindSheet 弹窗带预填打开 | @Prop 传 class 实例（@Prop 同步与 @Watch 顺序不保证，惰性构建首开不触发） | AppStorage 信号：宿主先写 pendingXxx* 字段 + 版本号 +1，弹窗 @StorageLink+@Watch 回填，读后即清 |
| 子页请求宿主弹窗 | 子页自己挂 bindSheet（违反单组件 1 bindSheet；且子页 pop 后弹窗随之销毁） | 子页写 AppStorage 信号（版本号 +1）后 pop；宿主页 @StorageLink+@Watch 收信号再置 show=true——弹窗始终单挂宿主根 Stack |
| 保存自定义文件 | `picker.save()` DOWNLOAD 模式 | 直写 `Download/<包名>/` 路径（绕开 13900002），见 AppLogger.downloadDirPath |
| fileShare 传路径 | 直接传 `/storage/...` | 先 `fileUri.getUriFromPath()` 转 `file://docs/...`（否则 code=3 Invalid path） |
| 批量文件授权 | 一次性传全量 URI | 分批 200 条 + 处理 `13900001` 的 `err.data` 部分失败明细 |
| 注册字体 | 在 onCreate 里注册 | 必须在 `loadContent` **回调里**注册 |
| Service 层打日志 | `console.log` | `AppLogger.info/warn/error`（console 不进用户导出日志） |
| 列表顶部/尾部留白 | `ListItem() { Blank().height(SafeArea.top + 72) }`（**编译失败**：Blank 只能嵌在 Row/Column/Flex） | `ListItem() { Row() {}.height(SafeArea.top + 72).width('100%') }` |
| 给子页挂 bindSheet | `SubPageScaffold({...}) { ... }.bindSheet(...)`（**编译失败**：build 被解析成两个根节点） | 把 bindSheet 挂到内容里的原生组件上：`SubPageScaffold({...}) { List(){...}.bindSheet(...) }` |
| 声明 SDK 版本 | `"targetSdkVersion": "26.0.0"`（**构建直接失败** 00306042） | `"6.1.1(24)"` —— 先读 `<DevEco>/sdk/default/sdk-pkg.json` 的 `apiVersion`，格式必须 `x.y.z(api)` |
| 写 Hds 标题栏 menu | `opts.content.menu = {...}`（可能是 undefined，编译报错） | `const c = opts.content; if (c !== undefined) { c.menu = {...}; }` |
| 多个 @Watch 顺序 | `@StorageLink('k') @Watch('cb') x`（**静默失效**） | `@Watch('cb') @StorageLink('k') x`（Watch 恒在前） |
| 卡片左右内缩 | 卡片自己挂 `width('100%')` **加** `.margin({left:16,right:16})`（**编译通过但被裁**：margin 在尺寸之外，总占位 = 父宽 + 32，右端越界被 List 切直角 —— 用户会报"显示不全"） | 横向内缩**只由宿主 `List` 的 `.padding({left:16,right:16})` 提供**；卡片保留 `width('100%')`、**去掉横向 margin**，只留 `.margin({top:12})`（见 LSN-014） |
| List 子项里的横向滚动条（筛选 chips） | `Row(){ Scroll(){ chips } .layoutWeight(1) }` 不给 Scroll 设高（ListView 子项内高度不确定 → 塌成 0 或撑高整行） | Scroll 显式 `.height(36)` + `.scrollable(ScrollDirection.Horizontal)` + `.scrollBar(BarState.Off)` |
| 给子组件传列表数据渲染 | `@Prop items: AssetItem[]`（**含方法的类实例经 @Prop 深拷贝后方法丢失**，且违反"UI 只读不重算"） | 在 model 侧聚合成**不含任何方法**的展示型数据类（比例、文案都算好），子组件 @Prop 只收纯数据（见 LSN-015） |
| 给 `SettingItem` 配下拉菜单 | 跨组件传 `@Builder`：`SettingItem({ withMenu:true, menu: this.themeMenu })`（**能编译、菜单能展开、点菜单项才崩**：builder 执行时 this 被重绑成子组件实例，`this.xxx()` → `TypeError: undefined is not callable`；同时 `.selected(this.xxx)` 恒 false、打钩静默失效） | **配置化而非调用方塞 @Builder**（沿用 `SheetContainer` 的既有约定）：传 `@Prop menuOptions: string[]` + `@Prop menuSelected: number` + 普通函数属性 `onMenuPick: (i:number)=>void`；`Menu`/`MenuItem` 在 `SettingItem` **内部**用 `ForEach` 构建（见 LSN-016） |
| 排查"跨组件 @Builder 是否丢了 this" | 只验菜单能否弹出（能弹就以为没问题） | 两类症状**成对出现，必须同时验**：① 点菜单项报 `undefined is not callable`；② `.selected()` 打钩永不显示。反证法：同一处"只调用模块级导入"的 builder（如 `SettingsManager.xxx()`）不崩 → 丢的是 this，而非 API 不支持 |
| 让 DevEco 能装到真机 | 只在 `build-profile.json5` 的 `signingConfigs` **数组**里配好签名材料（**声明 ≠ 使用**） | 还必须在 `products[].signingConfig` 里**引用**它（如 `"signingConfig": "default"`）；否则产出 `entry-default-**unsigned**.hap`，安装报 `error:9568320 no signature file`（见 LSN-017） |
| 改完 bundleName 后重新 Run | 只改 `AppScope/app.json5` 就 Run（日志仍 `Launching <旧包名>`） | 三步缺一不可：① 改 `app.json5`；② 在 DevEco **Sync / 重启**（`.idea/.deveco/project.cache.json` 缓存了 `BUNDLE_NAME`）；③ 重新申请**绑定新包名**的调试证书（p7b 内嵌 `bundle-name`，改包名即失效）（见 LSN-017） |
| 给 UI 打"启动完成"标记 | `AppStorage.set('dataLoaded', true)`（**键不存在时静默落空**）+ `App.aboutToAppear` 无条件 `setOrCreate('dataLoaded', false)`（**会覆盖已置的 true**） | 写入方一律 `setOrCreate`；建键方**只在键不存在时**初始化（`if (get(...) === undefined)`）；再配一个 300ms 自愈兜底（判断仓库 `isReady()`）。三者缺一，恢复够快时列表页就**永久停在「加载中…」**（见 LSN-018，模板 App.ets/EntryAbility.ets 原样自带此缺陷 D10） |
| 在 `@Builder` 里显示**会变化**的值 | `this.valueRow(AssetMath.formatDateCn(this.effectivePurchaseDate()), ...)` —— **按值传参**，状态变化**不刷新** Builder 内部 UI：编译通过、值也存对了，只是界面不动，重开才见新值（同理：分段控件 `selected` 高亮不动、开关行 `isOn` 不回显） | 三选一：① **内联到 `build()`**（最稳，首选）；② 传**对象字面量**走按引用传参（`class P{v: string=''}` + `this.row({ v: this.someState })`）；③ 交给子组件 `@Prop`。**纯静态文案**可继续按值传（见 LSN-019）。⚠️ 别用"保存后重开"验证 —— 值本来就对，会误判 |
| 给 UI 加图标 | 自研 SVG 图标组件 + `resources/base/media/*.svg` + 名字常量表（`SFIcon` 那套：要维护几十个 SVG、要分 normal/fill 两套、还无法随系统字体缩放） | **直接用官方符号**：`SymbolGlyph($r('sys.symbol.xxx')).fontSize(22).fontColor([color])`。选名查 `id_defined.json` 的 `"type": "symbol"`（本机 4042 个）；选中态用配对 `xxx` / `xxx_fill`。⚠️ `$r()` 只能写字面量，通用组件要接 `Resource`（见 LSN-020） |
| 写 `compatibleSdkVersion` / `targetSdkVersion` | 一律写 `"6.1.1(24)"` 或一律写 `"26.0.0"` —— **两种写法各有适用区间，写错直接构建失败** | **按 API 级别分界**：API < 26 用旧式 `x.y.z(api)`（如 `"6.1.1(24)"`）；**API ≥ 26 用点分制 `major.minor.patch`（如 `"26.0.0"`）**。给 26 加 `(26)` 报 `00308018`；26 之前不写 `(api)` 报 `00306042`（见 LSN-021） |
| 升级 SDK 版本 | 只改 `compatibleSdkVersion`（或只改 `targetSdkVersion`）就以为完事 | **两个字段一起改**，并保证 `compatibleSdkVersion ≤ targetSdkVersion ≤ compileSdkVersion`。改半截（如 compatible 改 26、target 还留 24）→ IDE sync 报 **`00303015 Configuration Error`**。⚠️ 该错误 **CLI 构建可能不报**（`compileSdkVersion` 由 IDE 解析的 SDK 决定）⇒ **`--sync` 与 `assembleHap` 必须各验一次**（见 LSN-021） |
| 给**内容区**的搜索框 / 工具条加沉浸光感 | 直接给内容区节点挂 `.systemMaterial(...)`（搜索框放在 `Column`/`List` 里）→ **材质完全不生效**，不报错不警告，日志只一行 `Material inactive: out of scope` | 通用属性 `systemMaterial` **只在 Navigation/NavDestination 标题栏区域生效**。正解：① **上提到标题栏扩展位** —— Hds 6.0.0(20)+ 的 `titleBar.content.bottomBuilder = { builder, height }`（⚠️ 该 `height` 必须与"内容区首个留空项"同源相加，否则首项被盖）；② 内容区就地生效用 `Toggle` 承载层（`MaterialCardLayer`，见上表光感行）。**排查口诀：材质"完全没反应"先 grep 日志有没有 `out of scope` —— 有就是放错位置**（见 `harmony-material-layer.md` §八之二） |
| 列表类给「上下边缘渐隐 + 弹簧」 | 只给 `List` 加 `.edgeEffect(...)` 忘了 `fadingEdge`，或反向漏一个 → 与项目其它列表两套手感 | 两条**成对**：`.edgeEffect(EdgeEffect.Spring)` + `.fadingEdge(true, { fadingEdgeLength: LengthMetrics.vp(24) })`（`LengthMetrics` from `@kit.ArkUI`）。⚠️ `fadingEdge` **只在内容溢出可视区时**渲染，内容不满屏时"看着没效果"是正常的 |
| 对齐另一个工程的页面顶部留白 | 直接抄对方 `Blank` 的值（如抄 player 的 `SafeArea.top + 44 + 56`）→ 恒偏一个说不清的常数（本工程 reader 首页会差 **44**） | 对齐**绝对目标值**而不是 Blank 值：先读对方注释里的目标（player `目标首卡顶 = SafeArea.top + 128`），再反推本工程 `Blank = 128 − 内容块自带 margin`。⚠️ 对方 Blank 里含着**它自己的结构补差**（那 44 = player"空第 1 行 + 标题行"），本工程标题栏是纯文字 MINI 栏、没有那两行 ⇒ 照抄必偏。写成两常量相加（`72 + 44`）让补差项在代码里看得见（见铁律 10c） |
| 给卡片加沉浸光感 | 直接给卡片 `.backgroundBlurStyle(Thin)` 或给外壳 `backgroundColor` 设材质 | 卡片外壳 = `Stack{ MaterialCardLayer + Column{内容} }`（模板 `components/MaterialCard`）。**承载层只能用 `ToggleType.Button`**（Checkbox 未适配；Switch 只覆盖开关本体），五条属性缺一不可：`LayoutPolicy.matchParent`（百分比会顶大卡片）/ borderRadius 同外壳 / `backgroundColor(Transparent)` / `enabled(false)+focusable(false)+accessibilityLevel('no')+hitTestBehavior(None)` / `attributeModifier` 放链**末**。应用级前置 `module.json5` metadata `ohos.arkui.UIMaterial.state="enable"`（模板已自带，改后须重装）。⚠️ 材质**不报错不失效提示**，必须真机截图验证（见 LSN-022） |
| 光感材质画出来了但不刷新/不显示 | ① `attributeModifier` 写成内联对象字面量（拨开关后已画卡片不更新）② 外壳/承载层有**不透明底色**（材质层级在 backgroundColor 之下，被盖住）③ `interactive:true` 配**空 `lightEffect:{}`**（材质完全不渲染）④ `bindSheet` 不设透明底（默认白底整块盖住） | ① modifier 写成**方法调用**并读订阅变量；② 材质开时底色一律 `Color.Transparent`，关闭时回实色；③ 无流光色时**省略** lightEffect 字段；④ `bindSheet(..., { backgroundColor: Color.Transparent })`。材质不可用时降级：**半透明底色 + `backgroundBlurStyle(Thin)`**，缺半透明底色则模糊被盖住（见 LSN-022） |
| 加自定义壁纸（选图作背景） | ① `result.uris`（**PhotoSelectResult 没有 uris 字段**，直接编译报错）② 对象字面量不标类型（`arkts-no-untyped-obj-literals`）③ 改了壁纸但重启后背景变回不透明 | 正确写法：`const opts: photoAccessHelper.PhotoSelectOptions = {...}`（显式类型）→ `result.photoUris[0]`（字段名 **photoUris**，class 定义在 openharmony 侧 `@ohos.file.photoAccessHelper.d.ts`）→ `SettingsManager.setCustomBgUri(uri)` 联动 `ThemeManager.setCustomBg`。picker 返回的 URI **自带永久授权**（persist 仅保险）。⚠️ **三处链路必须重放壁纸状态**：App 启动 / `onConfigurationUpdate`（updateFromConfig 重算 colors 会打回不透明）/ 设置变更（见 LSN-023） |
| 把实色卡片换成光感 / 玻璃卡 | 卡内控件仍用 `surface` 浅填充 → 与玻璃卡面几乎同色，「输入框 / 开关行 / 分段控件」看不出边界；`surface` 次级按钮直接贴在页面背景上 → 浅色下 `#F2F3F4` vs `#F5F5F5` 几乎看不见按钮 | 控件加 **`0.5vp` 发丝描边**（复用 `colors.fieldBorder`，实色填充保留 ⇒ 文字对比度不受材质影响）；**次级按钮留在卡片内**（见 LSN-025） |
| 给已有嵌套组件插卡片边界 | 内层容器与外层组件两个 `}` 都写完了才写 `.width()/.padding()` → `10505001 Declaration or statement expected` + `Cannot find name 'width'`，**报错点比真实元凶低一层** | 修饰符写在**内层容器 `}` 之后、外层自定义组件 `}` 之前**（自定义组件闭括号后不能再挂属性链，与附录 D7 同源）（见 LSN-025） |
| 设了自定义壁纸，但页面/顶部仍发白（用户口语「白色蒙版」） | 壁纸之上还有两层无色**不透明底**在盖：① 主界面 `HdsNavigation.backgroundColor = colors.background`（壁纸时 ≈70% 白，整屏压暗）② 首页标题栏滚动蒙层 `#CCFFFFFF`（80% 白块）。子页两条链默认已透明 ⇒ 只有主界面发白 | 改成与子页同口径：`HdsNavigation.backgroundColor` 条件透明（注意属性链上 **`backgroundColor` 可能写了两次，后写生效**）+ `buildHomeTitleBar(..., transparentScrollMask = true)`（见 LSN-023） |
| 材质下方是**纯色背景**（无壁纸 / 页面无内容） | 材质/毛玻璃无信息可采 → 卡片退化成**「与页面同色的灰玻璃」**（浅色下只剩一圈模糊边，比原来的实色白卡更差）；不报错 | 把「有底层」做成 `materialActive(forceOn, backdrop)` 的**第二形参**；无底层时**不下发材质** + 回落实色 `cardBg`（浅色白 / 深色 #212121）+ **去掉模糊**（见 LSN-026） |

**口诀**：**"玻璃要看得见，背后先得有东西；没有底层就回实色，别把纯色糊一遍"**
| 修改模板/工程里的资源引用（$media/$color/$string） | 引用写对了名字但 `resources/base/media/` 里没有对应文件 → 构建报 `The resource reference '$media:xxx' is not defined`，且报错指向 **build 中间产物**，难以定位源头 | 引用与资源**成对检查**：改完先 `grep -rn '\$media:' --include="*.json5"` 列出全部引用，再 `ls resources/base/media/` 核对。⚠️ 报错路径是 `entry/build/.../module.json`（中间产物），**真实源头在 `src/main/module.json5`**（见 LSN-024） |
| 给卡片/列表项做「长按」交互 | 写 `.onLongPress(() => {...})` 挂在 `Stack`/`Column` 上 → 报 `10505001 Property 'onLongPress' does not exist on type 'StackAttribute'`；再改成 `import { LongPressGesture } from '@kit.ArkUI'` → 报 `10311006 ... is not exported from Kit '@kit.ArkUI'` | **`LongPressGesture` 是 ArkUI 全局声明、无需 import**，写法 = 容器根节点 `.gesture(LongPressGesture({ duration: 500 }).onAction(() => {...}))`。内部"不吃手势"的承载层（`hitTestBehavior(None)` + `enabled(false)`）不拦截。改交互时回调属性**同步改名**让调用点漏改编译失败（见 LSN-027） |
| 同一组件既要「点击」又要「长按」（如列表卡：点击看详情 / 长按编辑） | `.onClick(...)` + `.gesture(LongPressGesture(...))` **并存**（两个独立手势）：长按命中后抬手**又触发点击** ⇒ 连跳两页（进编辑页又跳详情页）。编译全绿、只有真机暴露 | 绑成**互斥手势组**：`.gesture(GestureGroup(GestureMode.Exclusive, LongPressGesture({duration:500}).onAction(...), TapGesture({count:1}).onAction(...)))` —— 独占模式"先满足条件者胜出"。❌ 不要 `GestureMode.Parallel`（两个都触发）（见 LSN-028） |
| 子页需要「外部数据变更后自动刷新」（编辑保存返回详情要显示新值） | 把重算结果放**普通字段缓存**、在 `build()` 里读 ⇒ 刷新链尾段是"父组件重渲染**会不会顺带重跑 `@Builder`**"这一**不确定行为** ⇒ 返回后仍是旧值、退出重进才对 | 用 **`@State` 持有视图模型 + `@Watch` 驱动重算**（`@Watch` 写在状态装饰器**之前**，LSN-012）；入参**只取 id、不持快照**，页面永远 `repo.find(id)`，取到 `null` 渲染「记录不存在」兜底卡（见 LSN-028） |
| `ForEach` 里的数值变了但界面不更新（编辑后明细行还显示旧值） | key 只写"身份"：`(r) => \`kv_${r.label}\`` ⇒ 项还在、值变了 ⇒ **key 不变 ⇒ 复用既有节点、不重跑 `@Builder`** | key 里**带上会变的值**：`\`kv_${r.label}_${r.value}_${r.accent}_${r.isLast}\``。同理列表页 key 带上 `_${this.assetsVersion}` 做双保险（见 LSN-028） |
| 数据层改的是**同一个对象引用**（`Repo.find(id)` 返回的实例 `in-place` 改字段），页面 `@State` 存了它 | `this.pinned = repo.find(id).pinned` 之后再 `repo.toggle(id)`、然后想让界面跟着变 ⇒ **`@State` 重新赋的是同一个引用 ⇒ 判定"引用未变"⇒ 不重渲染**（值其实已经变了，界面却是旧的）。且**编译全绿、无告警**，只有真机/运行才暴露 | **跨"数据层 in-place 改字段"的桥一律用值类型 `@State` 快照**（`@State pinned: boolean` / `@State curChapter: number`），**绝不 `@State book: Book` 存引用**；改完数据层立刻**回读并赋快照**（`const b = repo.find(id); this.snap = b !== null ? b.field : 默认`）。★ 同类指纹 = 书签/进度/置顶这些"内存态翻转"字段不刷新 |
| 需要判断"刚刚那次操作前是什么状态"（如置顶后提示文案） | `repo.toggle(id)` 是 **in-place 翻转**，而调用方持有的 `actionTarget` 与 `find()` 返回**同一引用** ⇒ toggle 之后读 `actionTarget.pinned` 拿到的是**新值** ⇒ 刚置顶却提示「已取消置顶」（**文案与动作相反**，用户会报「显示反了」） | **翻转前把旧值存下来**：`const wasPinned = target.pinned; repo.toggle(id); toast(wasPinned ? '已取消置顶' : '已置顶')`。⚠️ 同一页面里"读新值"与"读旧值"两种写法都能自洽，但**必须只选一种并写注释说明**，混用必错 |
| 要做「**上次退出时在哪，下次打开回到哪**」（阅读记忆 / 会话恢复） | 想用"记录时间戳 + 启动时判断是否够新"来区分"用户主动退出"与"进程被杀" —— 阈值怎么定都不对，且要额外的标志位与清理逻辑 | ⭐ **不需要任何时间戳/标志位：用「`aboutToDisappear` 在进程被杀时不执行」这个事实本身做判据。** 进页 `set(key, id)`、离页 `set(key, '')`；进程被杀 ⇒ 离页回调没跑 ⇒ 键**残留** ⇒ 下次启动正好命中"上次在页内"；用户自己返回 ⇒ 键已清 ⇒ 停在原位。★ **写/清必须在同一层成对**（写在 `@Entry` 宿主页的 appear/disappear，别跨层）<br>⚠️ 两个必须加的**硬闸**：① 恢复前判**数据仓已就绪**（未就绪时 `repo.find()` 恒 `null` ⇒ 会把有效会话**误判成已删除并清掉**，不可逆地毁掉自己的能力）；② 延迟恢复的窗口内**复检是否已在目标页**（用户可能已自己点进去了 ⇒ 无脑再进 = 开两份）。<br>⚠️ 恢复触发**要两路**（`@Watch('dataLoaded')` + `aboutToAppear` 尾部延迟），因为启动恢复可能在页面挂载**之前**就打完了标记 ⇒ **`@Watch` 对初始值不触发**、收不到那次变化（见铁律 35 / LSN-012） |
| 撤掉一条"一镜到底 / 共享元素"通道时，机制要不要一起删 | 全删 ⇒ 下次要在**另一条路径**复用（用户原话「从列表到详情不用转场了，**从详情到阅读页才需要**」）时得重建整套曲线 / 置位 / DOM 配对机制；不删又怕留死代码被误用 | **分层决策**：① 先看新路径是否**具备落地条件** —— 若与已实证的硬约束冲突（如"共享元素要在页面根插层" vs "SDK 重组件必须**直挂**页面根"），则机制**整块保留**；② 保留时**必须把"写入端已归零"写进注释**（`HERO_TRANSITION_MS` 处注明"当前零调用方、恒 false ⇒ `pop()` 那条 branch 是死分支但无害"），避免后人误以为它在工作；③ **必须撤得干净的部分**：所有 `.geometryTransition` / `.transition` 绑定 + 各页 `@Prop heroEnter` + 骨架里的分支判据 —— 只撤一半会"起了手却没人播"（见 LSN-034 A） |
| 新建工程/写 `.gitignore` 或把工程推上 Git | 照抄模板 `.gitignore` 的裸 `signing/` ⇒ **整个签名目录被忽略**，仓库里没有 p7b/cer/p12/csr；clone 到新机器构建不出可安装包（`9568320 no signature file`） | **签名打包文件全提交**（p7b/cer/p12/csr）；**material 不提交**（换设备重输密码后重新生成）；**明文密码绝不记录**（build-profile 里只有密文）。**换应用只换 p7b**，cer/p12/csr 跨 Icey 系通用（LSN-029 终版，2026-10-17） |
| 详情/只读页的某个字段为空 | 整块隐藏（`if (hasNote) { 备注卡 }`）⇒ 用户**分不清"没填"还是"不支持"**（本工程实测：详情页备注卡「无备注不渲染」，随即被用户报「详情页要能显示备注」） | **详情/只读页的字段卡常驻**，空值给占位文案（「暂无备注」）——"这一栏存在"本身要被表达出来。表单/编辑页相反：空字段不渲染更清爽（没有"存在与否"的疑问）。备注等正文块要用与输入框同款承载（`surface` + 0.5vp `fieldBorder` 描边），别直接铺在玻璃上（见 LSN-025） |
| 本地书/音乐"存入库、不复制文件"后**重启打不开**（导入当次正常、重开白屏/无声） | 只调了 `FilePermission.persist([uri])`，**没有每次启动 `activatePermission`**。持久授权跨重启不自动生效 ⇒ `openSync(原始URI)` 抛 `13900001 EPERM` ⇒ 读取 catch 静默 return ⇒ 画布/列表全空 | ① 启动恢复链路（`EntryAbility.startupReady`，数据仓库 init **之后**）加 `await BookRepo.activatePermissions()`（遍历全部 bookUrl 调 `FilePermission.activate`）；② 读取路径加 `FilePermission.ensureActive(uri)` 单条兜底。★ 指纹 = **导入当次能看、杀进程重开就白**；日志找 `13900001`/`EPERM`（见 LSN-030） |
| 读取失败导致"整片空白"的页面（阅读页纯色、列表空态） | catch 里只 `AppLogger.error(...)` 然后 return ⇒ 用户看到一块底色，**没有任何提示**，长相差不多的根因（权限/文件移动/偏移错位）无法区分，排查几轮都在猜 | **绝不静默失败**：把失败落到 `@State loadError`，渲染**可见错误态 + 重试按钮**；并对"内容为空""排版 0 页"等**非异常**分支同样报错（见 LSN-030） |
| 给 Canvas 自绘的正文加"长按划选" | 用**比例**估字符下标（`x / 行宽`、`y / 页高`）⇒ 随字号 / 字距 / 段距变化**必然错位**（多选少选一个字、跨行乱选）。且排版产物只有整串文本、**没有每行的 `charStart`** ⇒ 拿不到章内偏移，选中的内容无法与书签 / 笔记定位对齐 | **三层收敛**：① `localX/px2vp − 页边距` ⇒ 页内容区坐标；② 按行的 y 区间定位行，`行高 = 字号 × lineSpacing`，**标题行字号 +2**（行高不同）；③ 行内找**最后一个左缘 ≤ cx** 的字形，过其右缘中点则 +1 ⇒ 章内偏移 `line.charStart + idx`。★ **排版期就把每行 `charStart` 存下来**，别在交互期反推。底衬要**逐行画**（求行 ∩ 选中区间的交集），不能拿章内偏移当页面坐标（见 LSN-031） |
| 在已有 struct 里新增 `@Builder` / 方法 | 把新成员写到结构体 `}` **之后**（如插在文件末尾）⇒ 一条改动引发**几十条级联假错误**：`Property 'xxx' does not exist on type 'Xxx'` + `UI component 'Column' cannot be used in this place` + `Cannot find name 'b'`。**元凶不在报错点上**，逐条改会白费 | 用脚本扫「**独占一行的 `}`**」定位那个提前闭合处（本工程实证在 615 行），把成员**移回结构体内**（去掉多余的 `}`）即可，别按报错逐条补（见 LSN-031） |
| 从管理页（书签列表 / 搜索结果）跳回阅读页 | 一律 `pop()` ⇒ 若用户是从**书架 → 书籍详情页**进入的管理页，路由栈里**没有阅读页** ⇒ pop 退到**错页**（详情页）而不是阅读页 | 先判存在再决定：`AppRouter.has(ROUTE_READER) ? pop() : push(ROUTE_READER, bookUrl)`（`has(name) = getAllPathName().indexOf(name) >= 0`）。配套：多个入口**共用一条 `@StorageLink` 跳转信号**，消费方 `@Watch` 读到后**立即清空**（见 LSN-031） |
| 给"整页"加转场动画（缩放 / 翻页 / 位移） | 把变换挂在**包裹内容子树**的容器上 ⇒ **命中测试热区随变换后几何收窄**：`scale 0.29` 时热区只剩原尺寸 29%；`rotateY(-90°)` + `centerX:0` 时**投影宽 → 0 ⇒ 热区宽为 0 ⇒ 全页点不到**。⚠️ 而 `XComponent`（Reader Kit 的 `ReadPageComponent`）/ `Canvas` 这类 **native 直绘内容不受 ArkUI 变换影响** ⇒ 合成「**看得见、点不动**」这一最难排查的组合（自绘与 Kit 两条内核表现完全一致，极易被当成两个 bug） | **凡改变组件几何的修饰符（`scale` / `rotate` / `translate` / `rotate3D`…）一律不得挂在包裹内容子树的节点上** —— 无论它是不是"只是一个动画"。要"看起来像整页在动"就**另起一层纯视觉层**（同尺寸 + `hitTestBehavior(HitTestMode.None)` + 播完 `opacity 0`），内容层恒定满尺寸、恒定零变换。这样即使动画一帧都没跑，最坏也只是**视觉瑕疵**而非**静默致瘫**。★ 指纹 = 正文能看见但点击/手势全无响应，日志 `InputKeyFlow: Touch test result is empty.`（正常应为 `TTHNI:{ T: List, D: 36 }` 之类有节点）（见 LSN-032） |
| 把图片 / 长文本存进 `preferences` | **`preferences` 的 string 值上限 = 8192 字节**（官方硬约束）⇒ 720w JPEG 的 base64 data URI（40~110 K 字符）**必然超限**，`putSync` 每次抛 `Parameter error. The type of 'value' must be ValueType.` 被 catch 吞掉 ⇒ **该槽位从未落盘**。★ 极具欺骗性：当次运行内存态有值 ⇒ **显示完全正常**；**重进 App `getSync` 读回空串 ⇒ 失效**（用户报「壁纸失效 / 重启就没了」） | `preferences` **只放轻量标量**（开关 / 档位 / 短字符串 / 路径 / `file://` URI）；图片、长 JSON、二进制**一律落沙箱文件**，只存路径。路径转 URI 用官方 `fileUri.getUriFromPath()`，别手拼 `'file://' + path`。**并给 `save()` 加显式长度预检**（`value.length > 8192` 就报 error 并放弃写入）——让"存了却没生效"在运行日志里一眼可定位，不再静默丢值（见 LSN-033） |
| 对接 SDK 级重组件（Reader Kit / Map / Camera / 各种 `XComponent`）时页面「**看得见、点不动**」 | 删干净全部几何变换后**仍然点不动**（同一 P0 复发第 3 次）⇒ 根因换成了**包裹层**：SDK 内部控制器只在「组件**直挂**真·路由页页面根 Stack」的形态下可靠建立。组件与页面根之间**每多一层容器都是一个独立变量**，**不论它是否参与变换**（视觉层 / 自定义组件 / 带 padding 的容器都算）。★ 排除法顺序：先证伪"窗口级全屏"（`git show HEAD:` 看它**本来就存在**⇒非根因），再证伪几何变换，最后收敛到层数 | **两条铁律必须同时满足**：**零变换**（LSN-032）+ **零包裹层**（本条）。容器一律删掉、`build()` 直挂 `pageRoot()`；状态栏避让**绝不给组件本体加 `padding`**（padding 会让 SDK 仿真翻页动画在**组件内容盒内**合成、padding 区成硬裁切线 ⇒ 动画上下被裁切）⇒ 改「**组件自身 `height` + 顶部 `margin`**」（margin 不计入自身高 ⇒ 真实高 == 上报 SDK 的 `viewPortHeight`，两者严格同源），并配 `Stack({ alignContent: Alignment.Top })`。⚠️ 撤掉"飞行层/一镜到底"必须**整条链路一起撤**（调用点 + 判定点 + 中继 + 组件），否则留下"起了手却没人播动画"⇒ 转场被关 ⇒ **硬切**（见 LSN-034 A） |
| 「同一元素在两个页面显示成两套样子」（如书架封面 vs 详情页封面） | 各页面各写一份占位绘制 ⇒ 默认绘制**有两套实现**，观感不统一；做共享元素转场时因"两端不同源"，只能**两端都不绑 hero** 来避免断层（用户要的动画一并丢了） | **先统一绘制、再谈转场**：把默认绘制抽成**唯一 `@Component`**（尺寸由调用方容器决定，用 `@Prop showTitle` 之类的开关适配不同形态），所有消费点替换。⚠️ 抽完后每个 `if` 分支都要**重新补绑** `geometryTransition`（`@Builder` 挂不了属性，需外包一层只含共享元素本身的 `Stack`）——漏一支 = 单边注册 = `pop(false)` 下**返回硬切**（见 LSN-035） |
| 给 `@Component` 抽出来的元素做共享元素转场 | 直接把它包在外层容器上挂 `geometryTransition`（外层还叠着书脊/页缘/scrim/文字信息层）⇒ 这些图层被一起"搬"到目标页 ⇒ 视觉断层 | hero 层必须**只含共享元素本身**：**另起一层 `Stack` 只放该组件**，属性挂在这层 `Stack` 上；外层容器（有额外图层的那层）不挂。这条与"两端视觉同源"是同一件事的两面（见 LSN-035） |
| 快速多次「返回 → 进入」同一页 ⇒ **一直显示"正在排版 / 加载中"** | 三条机制叠加：① 退出时把 `release()` **排进延迟批次**（为让开转场），而 **SDK 控制器在新旧会话间是同一个实例**（进程级）⇒ 用户 ~50ms 内重进、新会话已 `start()`，旧页面在 T+420ms 才 `releaseBook()` ⇒ **从外部释放掉新会话** ⇒ `pageShow` 永不回调；② `on(type, cb)` 是**追加**语义 ⇒ 重试/重进叠加 N 层回调（处理函数跑 N 遍，**完全不报错**）；③ `loading` 只靠外部事件 `pageShow` 收起 ⇒ 无超时出路就是**永久 loading** | ① `release()` **立即执行**（释放 native 资源不是耗时操作，留在延迟批次换不来流畅度却制造竞态）；延迟批次只留**真正耗时**的（全库序列化落盘 / 跨进程窗口调用 / 统计结账）；② 注册即替换 —— **先 `off(type)` 再 `on`**（`off` 省略 callback = 注销该类型全部回调）；③ 加**两道分开的看门狗**：`readyWatchdog`（管组件挂载前，8s）与 `pageWatchdog`（管 `startPlay` 后的**外部**事件，6s），超时**强制收起 loading + 渲染可见错误态（带重试）**；④ 入口加防重入守卫、回调处理器加 `disposed` 守卫（见 LSN-034 B） |
| 多级页面（主页 / 子页）的分组卡片「间距和内边距看起来不统一」，但每处单看都合理 | 两个页面各用一个卡片组件，各自把 `margin/padding` 写死且**值不一样**，甚至同一个组件按「有无标题」分了档 ⇒ 用户跨页切换时能直接看出松紧不一，却极难定位（页面里搜不到数值，全封在组件里） | **两套组件的间距口径逐项对齐，以「主页」为基准**：卡间距 16 + 内边距恒定（不分档）；只有 Divider 左缩进按「项有无图标」各自对齐自己那侧的文字列。⚠️ **禁按有无标题分档内边距**（差 3vp 恰好是肉眼可辨量级）。排查 = `grep -rn "<卡片组件名>" --include=*.ets` 下钻对比 `margin/padding/Divider` 三处（见 LSN-037） |
| 做「缩略图 → 全屏」共享元素一镜到底，关闭时**黑底连图片一起瞬间消失**（看不到飞回） | 把 `geometryTransition` 挂在 `bindContentCover` 的覆盖层里。覆盖层一收起就**立刻拆掉整棵子树** ⇒ 共享元素的目标侧没了 ⇒ 没有回程可飞。这是**结构冲突**，不是参数问题 —— `ModalTransition.NONE` / `transition: IDENTITY` / 黑底两段式 / 显式透明背景**全部无效** | **改成真正的路由页**：预览层 = `NavDestination`（`.mode(DIALOG)` + `.hideTitleBar(true)`），注册进 `navDestinationBuilder`（**不可当普通子节点挂**，否则立即渲染）；开 = 源页 `animateTo({250,EaseIn}, pushPath(…, false))`、关 = `animateTo({300,EaseIn}, pop(false))`；源侧缩略图打开时**让位**（`opacity(ready && !previewOn ? 1 : 0)`）、关闭时**在同一个 animateTo 里复位**；两侧 transition 反向：源侧 `opacity(0.99)` / 目标侧大图 `OPACITY`。★ 判据 = 官方 `transitions-collection` 里 `geometryTransition` 6 处全在 push/pop，`bindContentCover` 2 处**没有一处**配几何转场（见 LSN-039） |
| 用 `SegmentButton` 做分段切换（分类 / 歌曲-专辑） | ① 把 `buttons` 写成**变长数组 + `undefined` 占位**（想「统一补齐到 4 项」）⇒ **真机点进去就闪退**（`Cannot read property icon of undefined`，编译不拦）；② 想调高度写 `.height(43)` ⇒ **无效且不报错**；③ `onItemClicked` 链式写 ⇒ 编译错 `does not exist on type 'void'` | ① `buttons` 是**定长元组**，按段数分派构造（2/3/4/5 各一个方法）+ **不要 `as` 断言**；② 高度只能改 `buttonPadding`（配套重算圆角：药丸半径 = 药丸高/2+0.5）；③ 两个回调写在**构造参数**里。见 LSN-038 |

---

## 5. FAQ（覆盖高频提问）

**Q1：我要新起一个鸿蒙 App，最省事的做法？**
复制整个模板目录 → 改 `AppScope/app.json5` 的 `bundleName` 与 `AppScope/resources/base/element/string.json` 的 `app_name` → DevEco 打开自动关联 SDK → 按 W1 裁剪清单删除不需要的部分。不要新建空工程再往里搬，容易丢配置文件之间的隐式依赖。

**Q2：加一个设置开关，为什么重启后回到默认值？**
三选一的锅：① `SettingsManager.init()` 里没 `getSync` 读回该 key（**最高频**，模板自身就有两处遗漏，见 LSN-003）；② setter 里没调 `save()`；③ onBackground/onDestroy 没 `saveNow()`，防抖未到期被杀进程。按顺序查这三点。

**Q3：改了主题色/深浅模式，界面不刷新怎么办？**
`ThemeManager.colors` 是 static，不响应式。组件必须持有 `@StorageLink('themeColorsVersion')` 或接收父级传来的 `@Prop themeVersion`，版本号 +1 时重跑 build 重读 colors。**仅声明未引用**不会触发重建。

**Q4：新增子页四步是哪四步？漏一步会怎样？**
① `pages/subPages/XxxPage.ets` 用 `SubPageScaffold` 包裹；② `model/AppRouter.ets` 加 `ROUTE_XXX` 常量；③ `layout/Index.ets` 的 `navDestinationBuilder` 加 `else if` 分发；④ 调用处 `AppRouter.getInstance().push(ROUTE_XXX)`。漏 ③ → 白屏且无报错；漏 ② → 到处硬编码字符串，改名必崩。

**Q5：为什么我的弹窗能看见底下的内容？**
用了半透明的 `ThemeManager.colors.background`（自定义背景时它是 `#B3...`）。弹窗必须 `ThemeManager.opaqueBackground`。

**Q6：宽屏（平板/2in1）上弹窗要居中，要不要自己写？**
不要。用 `AppSheet`，它内置：≥600vp 或 deviceType=tablet/2in1 → 自动切 `promptAction.openCustomDialog` 窗口级居中；窄屏 → `bindSheet` 底部弹窗。

**Q7：加图标最简做法？**
**直接用鸿蒙官方符号，不要自研 SVG 图标组件。** 一行搞定：
`SymbolGlyph($r('sys.symbol.xxx')).fontSize(22).fontColor([ThemeManager.colors.textPrimary])`。
符号名从 `<DevEco>/sdk/default/openharmony/toolchains/id_defined.json` 检索 `"type": "symbol"` 得到
（本机 HarmonyOS 26.0.0 / API 26 共 **4042** 个可选）；Tab 选中态用配对的 `xxx` / `xxx_fill`。
⚠️ `$r('sys.symbol.xxx')` 是**编译期字面量**，不能用变量拼接 → 通用组件要接 `Resource` 参数而非名字字符串（见 LSN-020）。

**Q8：hvigor 报 `[safe-delete]` 怎么修？**
= 构建缓存损坏（构建期间并行编辑或并行构建所致）。删 `entry/build/default/cache/default/default@CompileArkTS`，然后**前台串行** `--no-daemon` 重建。本项目禁止并行构建。

**Q9：AppStorage 和 Preferences 到底用哪个？**
AppStorage 是**内存态全局**（重启即丢），用于跨组件通信/信号广播；持久化一律走 SettingsManager（preferences，增量写 + 防抖 + 原子 flush）。两者通过 `fillAppStorage()` 单向同步：preferences → AppStorage。

**Q10：返回键要收起某个浮层，该怎么接？**
非 @Entry 组件的 `onBackPress` 不会被系统调用。统一在 `App.ets`（@Entry）的 `onBackPress` 里判断 AppStorage 状态 → 广播版本号信号（如 `appBackRequest` +1）→ 目标组件 `@Watch` 消费。别忘了模板默认顶层返回 = `moveAbilityToBackground()` 最小化而非退出。

**Q11：这个 Skill 覆盖 HarmonyOS API 多少？**
**以本机实装 SDK 为准，不要照抄文档里的版本号**：先 `cat <DevEco>/sdk/default/sdk-pkg.json`
读 `apiVersion` / `platformVersion`（2026-09-17 实测为 **HarmonyOS 26.0.0 / API 26**）。
SDK 版本号的**书写格式按 API 级别分界**（API ≥ 26 用点分制 `"26.0.0"`，API < 26 用 `"6.1.1(24)"`），
写错会直接构建失败 —— 详见 LSN-021。Hds 组件（`@kit.UIDesignKit`）相关写法按此范围验证；
更低版本请参考铁律 #16 退数值字面量。

**Q12：光感材质画出来了但看不到 / 拨开关不刷新？**
四选一排查（全部只能靠**真机截图**确认，材质不报错）：
① 有**不透明底色**盖在材质上（材质层级位于 backgroundColor 之下）——外壳与承载层材质开时一律
`Color.Transparent`；② `attributeModifier` 写成了内联对象字面量——改成**方法调用**并读订阅变量；
③ `interactive:true` 配了空 `lightEffect:{}`——无流光色时**省略**该字段；
④ `bindSheet` 没设 `backgroundColor: Color.Transparent`（默认白底整块盖住）。
建议设置页放诊断行（`materialDiagnostics()`），五段判定一眼看出卡在哪一环。
**Q13：自定义壁纸和深浅模式/光感怎么协同？**
壁纸**不动深浅模式**（主题仍由用户选择/系统决定）；有壁纸时页面背景变半透明充当压暗层，
文字可读性由半透明背景 + 玻璃卡/材质保证。壁纸是材质的最佳舞台：玻璃卡采样窗口背后的壁纸，
**零适配**即得毛玻璃效果。⚠️ 三处链路（App 启动 / onConfigurationUpdate / 设置变更）都要重放
壁纸状态，漏了就会出现「重启或旋屏后壁纸失效」（见 LSN-023）。

**Q12：模板里没有的能力（网络/播放/数据库）怎么加？**
新建放 `entry/src/main/ets/services/`（无 UI 逻辑；用 AppLogger 打日志）或 `model/`（数据模型）。**不要**把业务塞进 `Index.ets` 或 `App.ets`——它们是骨架层，只允许放全局装配逻辑。

---

## 6. 踩坑经验库（LSN）

> 每条都来自真实项目，不是编的。**来源：HarmonyAppTemplate + 其母体项目（Icey-Player 系）2026-08 ~ 2026-09。**

### LSN-001 改 A 先看 B/C/D —— 执行者的完整责任
- **风险**：🔴 高频（修一半漏一半）
- **场景**：改了一处判断逻辑（如某个 Map 的取值方式），模板/工程里有 4 处相同模式
- **错误**：改了 2 处就提交，用户发现「另外两处怎么没改」
- **正确**：改前先 `grep -rn "关键词" entry/src/main/ets/`，把所有同模式引用一次改全
- **口诀**：司令员说「改 a」，跑步员要把 a 的上下游全部清完

### LSN-002 「改了没生效」五层排障
- **风险**：🔴 高频
- **场景**：编译通过、产物正确，但用户看到的还是旧内容
- **排查顺序**：源码 → 编译产物/缓存 → 工具（DevEco 加载了哪个目录？） → 设备/环境 → **是否改到了文件的真身**
- **血案**：改了 `home.vue`/`Index.ets` 2 小时无效果 → grep 发现实际渲染在另一个文件 → 10 秒解决
- **铁律**：方向试 **2 次**无效必须换思路，禁止死磕第三次

### LSN-003 新增持久化项「五步」而非「三步」
- **风险**：🔴 高频（重启静默丢失）
- **场景**：模板 `SettingsManager` 里 `HANDEDNESS_KEY`、`MATERIAL_LEVEL_KEY` 有常量、有 setter、
  但 `init()` **没有 getSync 读回** → 这两个设置重启必然回默认值
- **五步**：① KEY 常量 → ② `SettingsRecord` 字段 + 默认值 → ③ **`init()` 里 getSync 读回** → ④ `fillAppStorage()` 回填 → ⑤ setter（set 内存 + AppStorage + save）
- **防御**：加完运行 `grep -n "<KEY>" model/SettingsManager.ets`，出现次数必须 ≥ 4（定义/读/写常量各一处 + setter）

### LSN-004 静态类的单例幻觉（编译期必炸）
- **风险**：🔴 必现编译失败
- **场景**：`SettingsManager` 写成**纯 static 类**，但 8 处调用写成 `SettingsManager.getInstance().xxx()`
  （EntryAbility ×4、SettingsTab ×2、SettingsSubPage ×2）
- **后果**：ArkTS 编译直接失败，且报错是「找不到 getInstance」而非「缺新能力」，容易误判成 SDK 问题
- **防御**：改任何 Manager 前先确认它属于哪一种范式：
  `static 全静态`（直接 `Mgr.fn()`） vs `单例 getInstance()`（见 `AppRouter`）。**两种不可混写**

### LSN-005 路径硬编码陷阱
- **风险**：🔴 高频（换机/换盘必踩）
- **场景**：提示框里说文件在 `E:\project\...`，实际用户把工程搬到了别的盘
- **规则**：① 每次会话开头先定位模板源（见 §0）；② 输出前 `ls` 验证路径存在；③ 不用缓存里的旧盘符
- **附带**：身份文件（SOUL.md / IDENTITY.md / AGENTS.md）是只读的，非用户明确要求绝不改动

### LSN-006 编码与写入工具
- **风险**：🔴 高频（乱码/白屏）
- **规则**：① 所有 `.ets`/`.json5`/`.json` 必须 UTF-8 无 BOM；
  ② **禁止**用 PowerShell `Set-Content`/`Out-File` 写文本文件（自动加 BOM），用 Edit/Write 工具或 Node.js `fs`；
  ③ 禁止用 Python 做文本替换（用户级规则），一律用 Edit/Write

### LSN-007 已 push / 已验证过的代码，最小影响原则
- **风险**：🟠 中频（成型系统上大动干戈是灾难）
- **规则**：对已上线/已验证模块，只动必须动的那一处；重构与功能改动分离提交

### LSN-008 版本号信号 ≠ 布尔状态
- **风险**：🟠 中频
- **场景**：把 `appBackgrounded`（版本号，每次 +1）当布尔用并尝试复位 → 依赖它的 @Watch 从此不触发
- **规则**：版本号 = **事件**（单调递增，永不复位）；布尔 = **状态**（可查询）。两者并存，语义勿混用

### LSN-009 项目规模→是否值得沉淀
- **风险**：🟢 低频但高价值
- **规则**：跨 2 个以上模块、或修了超过 8 次工具调用才定位的问题 → 立刻写 LSN 更新到本文件；
  单次小改动不必

### LSN-010 HdsTabs 底栏中央「+」按钮：标准方案与视觉对齐
- **风险**：🔴 高频（导航栏加 FAB 是普遍需求，且第一直觉都是错的）
- **场景**：用户要求「+」按钮内嵌 HdsTabs 底栏正中央。三轮迭代实证：标题栏悬浮→被否决；隐藏自带 bar（`barHeight(0)`）+ 自绘 customTabBar + 外层 Stack 钉底→被否决（「必须使用 hdstabs」）
- **SDK 事实**（读 `@hms.hds.hdsBaseComponent.d.ets` 实证，官方文档页 WebFetch 拿不到正文）：`HdsTabsOptions extends TabsOptions`，页签栏完全由 `TabContent().tabBar(builder)` 驱动，**没有**中间异形按钮专用 API；但复用系统 Tabs 的 `onContentWillChange((currentIndex, comingIndex) => boolean)`（返回 false 阻止切换）
- **最终方案（5 页签）**：「+」= 空 TabContent 占位（index=2）+ `onContentWillChange` 对该 index 返回 `false` + `onTabBarClick(index)` 弹弹窗；自带 bar 恢复 `barFloatingStyle`（barBottomMargin=导航条+2、ADAPTIVE 材质）
- **两个隐藏坑**：① TabContent 从 4 变 5 后，所有按 index 取值的数组/参数必须同步补位——`TabItemBuilder(index)` 参数（选中高亮靠 `currentIndex===index`）、**`tabTitles` 数组**（标题栏按 `tabTitles[currentIndex]` 取值，漏补则后段标题整体错位、末项越界空标题；占位 index 填空串）——改完 `grep -rn "currentIndex\]\|TabItemBuilder(" 全查一遍；② 「+」红钮与其他页签的视觉对齐——`TabItemBuilder` 有 `padding({bottom:4})` 使图标+文字组重心偏上，红钮必须带同级 padding，且 44vp 大目标对 1vp 偏差敏感（4 不够上 6，用户截图逐轮反馈）
- **口诀**：FAB 想进 tabBar，占位页签 + willChange 拦截；改完页签数，index 参数全 grep

### LSN-011 日期选择优先官方 DatePickerDialog，勿手写滚轮
- **风险**：🟡 中（自定义日期滚轮代码量大、坑多——索引/值换算错位、闰月联动、月天数收敛全要自己维护）
- **场景**：表单需要选公历/农历日期。手写三列滚轮（List + spacer 居中 + onScrollStop 回写）真机暴露年份错乱 bug（回调传「索引+1」当值，月/日蒙对、年错位成 126），最终整体推翻改官方弹窗
- **SDK 事实**：`this.getUIContext().showDatePickerDialog(options)`（API 11+，替代已废弃的静态 `DatePickerDialog.show`）；`DatePickerDialogOptions` 支持 `start`/`end`/`selected`(Date)/`lunar`(boolean)/`lunarSwitch`(boolean)/`onDateAccept?: Callback<Date>`；**onDateAccept 只回传公历 Date，读不回用户是否切了农历开关**（`DatePickerResult` 仅年/月/日无农历字段）
- **最终方案**：删除自研滚轮 + 闰月开关；日期状态收敛为单一公历事实源（`@State selSolar: Date`），弹窗 `lunar: this.lunarMode` 控制展示口径、`lunarSwitch: false` 隐藏弹窗内开关（避免开关状态读不回的语义分裂），公历/农历由弹窗外 chip 单一事实源控制；农历中文显示由 LunarUtils 换算（闰月自动带出）；保存按钮 enabled 不再判「换算失败」——公历事实源恒有效
- **注意**：官方弹窗不支持深浅色热更新（需重开弹窗）；弹窗内年月列联动/天数收敛全部系统自理
- **口诀**：选日期用 showDatePickerDialog；回传只有公历 Date，口径开关自己管、别开 lunarSwitch

### LSN-012 `@Watch` 装饰器顺序硬性约束 + 跨 Tab 信号驱动 UI 走「父级级联」
- **风险**：🔴 高频（静默失效，编译不报错，最难查）
- **场景**：用 `@StorageLink('sig') @Watch('onSig')` 想在某个信号变化时重算列表，结果列表「有初始数据但永远不更新」
- **根因①（装饰器顺序）**：ArkTS 规定 **`@Watch` 必须写在状态装饰器之前**（`@Watch('cb') @StorageLink('x') x`），写反（`@StorageLink('x') @Watch('cb')`）SDK **静默忽略 `@Watch`**——回调永不触发，依赖它的 `@State` 缓存只算一次
- **根因②（跨 Tab 不可靠）**：仅依赖「子 Tab 自己的 `@StorageLink` 信号」触发重渲染，对**当前非活跃 Tab** 不可靠（组件未激活时状态变更未必驱动其重渲染）
- **正确做法**：
  - 顺序：`@Watch('cb') @State/@StorageLink/@Link(...) x`（Watch 在前）
  - **更稳的排序/重排**：让**父组件（如 Index）在 `build()` 里引用该信号**（类比主题 `themeColorsVersion` 放 `.opacity(...)` 里被引用），父级整树重渲染**级联**到子 Tab 重排——这是模板已验证的通路（深浅切换即此机制），比依赖子 Tab 各自 `@StorageLink` 可靠得多
  - 列表计算直接在 `build()` 内调 `EventSorter.sorted(...)` 重算（不缓存到 `@State`），彻底绕开 `@Watch` 顺序陷阱；ForEach key 仍带信号做双保险
- **口诀**：@Watch 写前面；跨 Tab 信号让父组件 build 引用→级联，别只靠子 Tab 自己监听

### LSN-013 内置副本 compile-ready 校验：原样复制后必须"全表扫一遍"
- **风险**：🔴 高频（新建项目第一小时全耗在来回编译上）
- **场景**：2026-09-16 用内置副本起「资产日耗」App，按 §0 只修了 D1~D4 就构建 → 仍然连挂 3 轮
- **实测错误链（逐层暴露，每次只报一层）**：
  1. `hvigor 00306042`：`targetSdkVersion: "26.0.0"` 格式非法 → **D5**
  2. ArkTS 编译 10 个错：`HdsNavigationTitleBarOptions` 未 import + `opts.content` 可能 undefined → **D6**；
     `AboutPage` 自定义组件后链式 `bindSheet` → **D7**；`ListItem` 直接持有 `Blank` → **D8**
- **正确流程**：复制模板后**一次性**核对 附录 C 全表（D1~D9）再构建；构建前先 `cat <DevEco>/sdk/default/sdk-pkg.json`
  确认本机 apiVersion，别照抄模板里的 26
- **判定经验**：ArkTS 报错**位置经常不是元凶**——`AboutPage` 那条报的是"@Entry 组件 build 只能有一个根节点"
  （AboutPage 根本不是 @Entry），真实原因只是链式属性把解析器带偏。**先看报错点所在语法结构是否合法，再怀疑逻辑**
- **口诀**：模板不是"复制即可用"，是"复制 + 全表体检 + 对齐本机 SDK"

### LSN-014 `width('100%')` 与横向 margin 不可同挂：卡片右端被裁切（用户只说"显示不全"）
- **风险**：🟠 中频但**最难自查**——编译通过、无任何告警、纯视觉缺陷，且只在真机截图上才看得见
- **场景**：2026-09-16「资产日耗」首页总览卡：`AssetTab` 的 `List` 没加左右 padding，
  卡片组件内部却挂 `width('100%')` + `margin({left:16,right:16})`
- **症状**：卡片**左边距正常（≈16vp）、右边距为 0**，右端被切成**直角**紧贴屏幕边缘
- **根因**：ArkUI 中 **margin 计算在组件尺寸之外**。`width('100%')` 取父内容区宽，
  再加左右 margin 16 → 总占位 = 父宽 + 32vp；起点右移 16、右端越界 16，被父 `List` 裁切
- **定量量测（截图取证法）**：取卡片中间一行逐像素扫蓝/背景边界 → 若「左内缩 ≈ 16vp 且右内缩 = 0 且右上角无圆角」，
  即可确诊；若左右都正常则与本坑无关
- **正确写法**：**横向内缩只由宿主 `List` 的 `.padding({left:16,right:16})` 提供**；
  卡片保留 `width('100%')`、**去掉横向 margin**，只留 `.margin({top:12})`。
  模板中 `SettingsGroup.ets` 已按此实现（注释：*"width('100%') + margin 会溢出导致边距不生效"*），
  `SettingsTab` / `AboutPage` 的 List 也都带 `.padding({left:16,right:16})` —— 新增页面照抄
- **孪生反例（不会裁切但会"窄一圈"）**：卡片**既**被 List padding 又自带横向 margin → 双倍内缩 32vp，
  同一 App 内两页卡片左右边界不一致。归一化时把这两类一起清
- **同族第三例（2026-10-04，`BookEditPage` 全宽保存按钮）**：`ListItem { Button('保存').width('100%').margin({left:16,right:16}) }`
  —— 与卡片完全同因（ListItem 是满宽的，16vp 没人吸掉 ⇒ 右端贴屏幕边）。
  **修法等价**：外层包 `Row().width('100%').padding({left:16,right:16})` 承接内缩，按钮回到裸 `width('100%')`。
  ⇒ **判据是"父容器有没有先把这 16vp 扣掉"，不是组件的类型**（卡片 / 按钮 / 任何满宽件都适用）。
  ⚠️ 反向陷阱：**看到别处 `Button.width('100%')` 没出问题就照抄** —— 那是它的内层容器
  自己带了 `.padding({left:16,right:16})`（如 `BookDetailPage` 的内容列）。
  **必须看父容器，不能复制结论。**
- **口诀**：横向内缩归宿主，子项只留纵向间距

### LSN-015 跨组件只传"展示型数据类"：@Prop 深拷贝会丢方法，视图层禁止重算
- **风险**：🟠 中频（页面一多、图表一加就撞上），且后果是**运行时 undefined / 白屏**而非编译错误
- **场景**：2026-09-16 给「资产日耗」加趋势页，需要把聚合结果喂给柱状图/排行条组件
- **两条硬约束（互相印证，指向同一个架构）**：
  1. **`@Prop` 对类实例做深拷贝，方法不保证存活** —— 传 `AssetItem[]` 进子组件后调 `it.dailyCost()`
     就是运行时炸弹
  2. **视图层不应做业务计算** —— 在 `build()` 里遍历列表求和/求比例，列表一长就是每帧白算一遍
      （模板既有约定：`build()` 内连局部变量都不允许声明）
- **正确做法**：把"算"全部留在 model，产出一个**只有字段、没有任何方法**的展示型数据类，
  连比例、宽度百分比、右侧说明文案都预先算好；子组件 `@Prop` 收进来只做排版
  ```ts
  // model/TrendStats.ets —— 无方法，专供 @Prop 传递
  export class NameValue { name = ''; value = 0; ratio = 0; count = 0; extra = ''; }
  // components/Charts —— 只排版
  @Component export struct RankRows { @Prop items: NameValue[] = []; /* ... */ }
  ```
- **判别口诀**：**"这个类要被 @Prop 传吗？"→ 要，就一个方法都别加**
- **附带收益**：@Prop 深拷贝的语义变得完全可预测（纯数据，拷贝后行为一致），也天然满足
  "bar 宽度 / 百分比文案不在 UI 层重算"的可维护性要求

---

### LSN-016 跨组件传 @Builder 会丢 this：菜单能弹出、点一下才崩（"undefined is not callable"）
- **风险**：🔴 高频陷阱（凡是"给通用组件塞 builder"的封装都会撞），且**编译零报错**，只在真机点击那一刻崩
- **场景**：2026-09-16「资产日耗」设置页切换主题模式闪退：
  ```
  Reason:TypeError / Error message:undefined is not callable
  at anonymous entry (entry/src/main/ets/pages/SettingsTab.ets:106:32)
  ```
  106:32 正好是 `.onChange(() => { this.applyThemeMode(2); })` 里的 `applyThemeMode`
- **根因**：`SettingItem` 用 `@BuilderParam menu` 接收父组件的 `@Builder`，父组件以
  `menu: this.themeMenu` **传未绑定引用**。菜单**展开时**正常（`.selected(...)` 只是取值，
  读不到也只是 false，不抛），但**点击菜单项时**执行 builder 体内闭包，`this` 已被重绑为
  子组件 `SettingItem` 实例 —— `this.applyThemeMode` → undefined → 调它即抛
- **三步闭锁定性（照抄即可复现此判据）**：
  1. **看列号落到哪个标识符**：`106:32` 指向 `this.applyThemeMode` 而非 `this`，说明
     `this` 是"有效对象但缺这个成员" → 是被重绑，不是 undefined
  2. **找同文件对照物**：同页「沉浸光感材质」菜单**不崩**，因其 builder 只调用
     **模块级导入**的 `SettingsManager.setMaterialLevel()`，体里根本没有 `this`
  3. **反推静默 bug**：既然 builder 里 `this` 错了，`.selected(this.themeMode === 0)` 读到的
     就是 undefined，`undefined === 0` → false → **选中打钩从来没显示过**（用户只报了闪退，
     不会报这个）—— 修此 bug 必须两个症状一起收
- **正确做法（配置化，对齐模板 `SheetContainer` 的"配置化而非调用方塞组件"约定）**：
  ```ts
  // 子组件：不再收 @Builder，改收数据 + 普通函数属性（普通函数属性的 this 是正常的）
  @Prop withMenu: boolean = false;
  @Prop menuOptions: string[] = [];        // 父组件传模块级常量数组，引用稳定
  @Prop menuSelected: number = -1;         // 选中下标；@Prop 保证父级切换后重渲染
  onMenuPick: (index: number) => void = (index: number) => {};

  @Builder
  private menuBuilder() {
    Menu() {
      ForEach(this.menuOptions, (opt: string, idx: number) => {
        MenuItem({ content: opt })
          .selected(this.menuSelected === idx)
          .onChange(() => { this.onMenuPick(idx); })
      }, (opt: string, idx: number) => `${idx}-${opt}`)
    }
  }
  ```
  ```ts
  // 父组件：只给数据 + 回调（回调是箭头函数，this 在创建点被词法捕获，正确）
  SettingItem({
    /* ... */
    withMenu: true,
    menuOptions: THEME_OPTIONS,           // 下标即 mode 值：0 跟随系统 / 1 浅色 / 2 深色
    menuSelected: this.themeMode,
    onMenuPick: (index: number) => { this.pickTheme(index); },
  })
  ```
- **注意区分：同组件内 `bindMenu(this.xxxMenu)` 是安全的**。`AssetTab.sortMenu`、
  `AssetFormSheet.categoryMenu` 都这么写且正常 —— 因为 builder 与调用点在**同一个组件**里，
  `this` 未被重绑。**只有"跨组件传递"才触发本坑**
- **判别口诀**：
  - **"这个 builder 要传给别的组件吗？"→ 要，就别用 `@BuilderParam`，改成「数据 @Prop + 回调函数属性」**
  - **"builder 体里出现 `this.` 了吗？"→ 一旦跨组件出现，就一定会丢**
- **附带收益**：通用组件不再依赖 ArkUI 的 builder 编译细节，调用方只需提供数据，
  组件也更易测（`Menu` 结构固定在组件内，不在每个调用点重复写一遍）

---

### LSN-017 签名与安装三连坑：`signingConfigs` 声明 ≠ 使用、改包名后 IDE 仍启旧包、签名无法靠魔数判定
- **风险**：🔴 装不上就完全无法真机验证（打断整条交付链），且报错信息指向"没签名"，
  很容易误判成"证书过期/账号没登录"而白折腾
- **场景**：2026-09-17「资产日耗」改包名后 DevEco 运行失败：
  ```
  Launching com.icey.assetscost          ← 旧包名（已改过 app.json5）
  Install Failed: error: failed to install bundle.code:9568320
                  error: no signature file.
  ```
- **三个独立故障点（逐一定位）**：

  **① `signingConfigs` 里声明了材料 ≠ product 会使用它（致命）**
  `build-profile.json5` 里 `app.signingConfigs[]` 只是一个**候选清单**，
  product 必须**显式引用**才生效：
  ```json5
  "products": [ { "name": "default",
                  "signingConfig": "default",   // ★ 缺这行 → 产出 unsigned.hap
                  "targetSdkVersion": "6.1.1(24)", "runtimeOS": "HarmonyOS" } ]
  ```
  - 症状：`entry-default-**unsigned**.hap` 与 `-signed.hap` 同时存在，IDE 却装了 unsigned
  - 判据：CLI 构建日志出现 `WARN: No signingConfig found for product default`，
    且 `SignHap` 任务名**不出现**（修好后 `SignHap` 会实际执行数秒）

  **② 改 `bundleName` 后 IDE 仍启动旧包名**
  `.idea/.deveco/project.cache.json` 的 `BuildOptions.BUNDLE_NAME` 会缓存包名，
  DevEco 的运行配置据此启动。改包名后必须 **Sync / 重启 IDE** 重建缓存。
  （该文件属 IDE 生成物、不纳入版本控制，可临时手改验证，但 Sync 才是正解）

  **③ 签名无法靠"魔数/条目 diff"判定（验证方法论）**
  - ❌ 找 `Hap Signature Block` 魔数 → 本 SDK（HarmonyOS 6.1.1 / API 24）**找不到**，
    因为签名实体是「内嵌描述文件(p7b 内容) + 证书链」，文件尾部仍是普通 zip EOCD
  - ❌ 对比 signed / unsigned 的 zip 条目 → **所有条目内容与大小完全相同**，
    差异仅在条目顺序 + 多一个 `.pages.info`(96B)，会得出"没签名"的错误结论
  - ✅ **唯一可靠判据**：解包后检索 **kebab-case** 字段 `bundle-name` /
    `app-identifier` / `debug-info` —— 它们**只存在于 p7b 描述文件**；
    `module.json` 用的是 camelCase `bundleName`，因此不会误判
    ```bash
    python -c "d=open('<hap>','rb').read();i=d.find(b'bundle-name');print(d[i-60:i+260].decode('utf-8','replace'))"
    ```

- **改包名的连带影响（做前先问清）**：
  - p7b 描述文件**绑定 `bundle-name`** → 改包名后旧证书失效，需重新申请
  - 描述文件的 `debug-info.device-ids` 是**设备白名单**（`device-id-type: udid`），
    仅名单内设备可安装调试包
  - bundleName 即应用身份 → 已安装设备的 preferences 数据**不迁移**，新包为空白数据
- **真机验证标准动作（`hdc` 在 `<SDK>/default/openharmony/toolchains/hdc.exe`）**：
  ```bash
  hdc list targets                 # 连接设备（真机序列号形如 62T0226127013362，非 127.0.0.1:port）
  hdc shell bm get --udid          # 取 UDID，核对是否在证书白名单内
  hdc install -r <signed.hap>      # 安装 → "install bundle successfully"
  hdc shell bm dump -a             # 确认包已注册；appIdentifier 应等于描述文件里的值
  ```
- **口诀**：**"材料配了"要问"引用了没"；"包名改了"要问"IDE 知道了没"；
  "有没有签名"只看 kebab-case 描述文件字段，别找魔数**

---

### LSN-018 启动竞态：`AppStorage.set()` 对不存在的键是静默空操作 → 列表页永久「加载中…」
- **风险**：🔴 高危害 + **极高隐蔽性**——编译零报错、必现与否取决于机器速度，
  且"加载中"看起来像正常的慢，很容易被误判成"数据没读出来"去查持久化
- **场景**：2026-09-17「资产日耗」改包名重装后，资产/心愿/趋势三个 Tab **全部永久转圈**。
  日志是决定性证据：
  ```
  I .../Startup: 启动恢复总耗时 34ms                              ← 恢复链路已完成
  I .../App: App colorMode=1 themeMode=0                          ← UI 此时才开始建树
  W .../App: launch fallback: dataLoaded false after 300ms        ← 标志位仍是 false
  ```
- **双重根因（必须同时理解，缺一会误判）**：

  **① 写入落空（主因）：`AppStorage.set` 不会创建键**
  ```
  AppStorage.set('dataLoaded', true)   // ← 键尚不存在时：静默丢弃，不报错、不创建
  ```
  `EntryAbility` 的恢复链路（34ms）**快于** `App.aboutToAppear` 里
  `setOrCreate('dataLoaded', false)` 的建键时刻（55ms）→ `set(true)` 落空。

  **② 建键覆盖（次因）：`App.aboutToAppear` 无条件初始化**
  ```ts
  AppStorage.setOrCreate('dataLoaded', false)   // ❌ 无条件 → 会覆盖已置的 true
  ```

  **两者叠加 = 顺序敏感**：
  | 顺序 | 结果 |
  |---|---|
  | 链路**晚于** UI 建键（旧版：恢复 382ms） | `set(true)` 命中已存在的键 → 正常 ✅ |
  | 链路**早于** UI 建键（新版：恢复 34ms） | `set(true)` 落空 → 随后被建键为 false → **永久加载** ❌ |
  → **恢复越快越容易触发**，所以本地调试"有时好有时坏"，上线到快设备/空数据时 100% 复现

- **正确做法（三处协同，任一处都不能省）**：
  ```ts
  // ① 写标记方（EntryAbility 恢复链路）：一律用 setOrCreate，与键是否存在/先后顺序无关
  AppStorage.setOrCreate<boolean>('dataLoaded', true);

  // ② 建键方（App.aboutToAppear）：只在键不存在时初始化，绝不回退已完成的状态
  if (AppStorage.get<boolean>('dataLoaded') === undefined) {
    AppStorage.setOrCreate<boolean>('dataLoaded', false);
  }

  // ③ 自愈兜底：数据源已就绪却仍未标记 → 强行补标记（只打日志是不够的）
  setTimeout(() => {
    if (AppStorage.get<boolean>('dataLoaded') === true) return;
    if (YourRepository.isReady()) {              // 仓库需暴露静态 isReady()
      AppStorage.setOrCreate<boolean>('dataLoaded', true);
      hilog.warn(0x0000, TAG, 'fallback: 数据源已就绪但标志位未置，已兜底补标记');
    }
  }, 300);
  ```
  配套：数据仓库在 `init` 的 try/catch **之后**（成功失败都）置 `loaded = true`，
  让"载入结束"（失败也算结束，UI 应显示空态而非无限转圈）可被查询。

- **判别口诀**：
  - **"这个键谁先创建？"→ 凡是 `AppStorage.set`，就必须确认键已存在，否则换 `setOrCreate`**
  - **"跨模块共享的完成标记，只允许单向（false→true），任何地方都不许写回 false"**
  - **看到"永久加载中"先排查顺序，而不是先查持久化**
- **正确验证姿势**：不要只看 UI，**看 hilog 的应用域日志**确认
  `启动恢复总耗时` 已打印、且 **`launch fallback` 告警数为 0**
  （`hdc shell hilog -x | grep launch fallback`）——告警为 0 才说明不依赖兜底、链路本身正确

---

### LSN-019 @Builder 按值传参不刷新：改了值界面不变、但"重开又对了"
- **风险**：🔴 高频 + **极难自查**——编译零报错、数据也存对了，只是界面文本/高亮/开关态不跟着变。
  最坑的是**验证方式**：如果只用"保存后重开看看对不对"，会看到正确值而误判为无 bug（见下）
- **场景**：2026-09-17「资产日耗」新增资产表单：改完**购买日期**，界面日期文本纹丝不动；
  但保存后重新点进去编辑，日期却是**对的**
- **根因（ArkUI 明文规则）**：
  > @Builder **按值传参**时，状态变量的改变**不会**引起 @Builder 方法内的 UI 刷新；
  > 只有传**对象字面量**才是**按引用传递**，才会随状态刷新。
  ```ts
  @Builder valueRow(value: string, placeholder: boolean, onTap: () => void) {
    Row() { Text(value) /* ... */ }        // ← value 是按值参数
  }
  // ❌ 状态变了不会刷新：只是首次构建的值生效
  this.valueRow(AssetMath.formatDateCn(this.effectivePurchaseDate()), false, () => { ... })
  ```
- **同文件"对照实验"（决定性证据，照抄可复现）**：该表单里
  - 分类 / 目标日期 / 到期时间 → 都是**在 `build()` 里内联 `Row { Text(this.xxx) }`** → **全部正常**
  - 购买日期 → 走 `this.valueRow(...)` 按值传参 → **唯一异常**
  → 同一页面、同一状态机制，唯一差异就是这个 @Builder 边界 ⇒ 确诊
- **正确做法（三种，按推荐度排序）**：
  1. **内联到 `build()`**（最稳，首选）：该行直接在 build 里写 `Row { Text(this.xxx) }` + `.onClick`
     —— 本工程四处日期/分类行均为此写法
  2. **按引用传参**：参数改成单个类实例，调用处传**对象字面量**
     ```ts
     class SegmentsParams { labels: string[] = []; selected: number = 0; onChange: (i: number) => void = (i: number) => {}; }
     @Builder segments($$: SegmentsParams) { /* 内部用 $$.selected ... */ }
     this.segments({ labels: KIND_LABELS, selected: this.kind, onChange: (i: number) => { this.kind = i; } })
     ```
     （旧版 SDK 要求形参名为 `$$`；对象字面量必须**写在调用处**才算按引用）
  3. 交给**子组件**用 `@Prop` 传值（子组件的 @Prop 会随父级刷新）
- **可以继续按值传的情况**：参数是**纯静态**内容（如 `fieldLabel('名称')`、`sectionTitle('基础信息')`）
  —— 永不变化就没有刷新需求。**但一旦文案依赖状态就必须改**，例如
  `fieldLabel(this.isWish() ? '目标金额（元）' : '价格（元）')` 在切换类型后不会更新
- **同一根因的其他受害者（排查时一并看）**：
  - 分段控件的 `selected` → **选中高亮不动**
  - 开关行的 `isOn` → **开关态不回显**（尤其**互斥开关**：开了 A 应关 B，B 的显示不会跟着关）
  - 任何 `@Builder(param)` 里 param 由 `this.someState` 算出来的显示值
- **判别口诀**：
  - **"这个值会变吗？会变就别当参数传"**
- **⚡ 一眼定案的现场判据（2026-10-12 BiliDownload-Harmony 实证，值得优先用）**：
  **同一屏上，同一个值 ——「build 内联 `Text(this.xxx)` 会实时更新」而「经 `@Builder(a, b)` 渲染的不更新」**
  ⇒ **立刻就是本坑**，别再去查数据层/依赖登记/ForEach key（那些方向是错的）。
  实例：详情页「按钮」里内联 `Text(\`${this.task.percent}%\`)` **实时更新**；
  同页「任务状态卡」用 `this.row('进度', \`${...}%\`)`（按值 @Builder）**永远冻结**。
  ⇒ **刷新类 bug 的第一刀就切这里**：`grep` 一下那个不更新的文案是不是走 `@Builder`。
- ⚠️ **别把「实时刷新两件套」用错地方**：`@StorageLink @Watch` → `@State renderTick` → build 零重量锚
  这套只能驱动**内联读取**的元素重渲染；**它救不了按值传参的 `@Builder`**
  （builder 内部只认首次构建的字符串快照）。两者叠加 = 表里不一（部分更新、部分冻结）。
- ⚠️ **组件内 `@Builder` 里凡是读 `this.xxx` 的，一律写成「零参数 + 体内现读」**
  （如把 `layer(content, op)` 拆成 `layerA()`/`layerB()`，各自内部读 `this.aText/this.aOp`），
  这是"双层交叉淡化"这类模式最容易踩的地方（16 个字符的便利换一次线上冻结）。
  - **"@Builder 的参数里出现 `this.<状态>`（或依赖状态的表达式）→ 一定会 stale"**
  - **"UI 不跟着变、但数据是对的" → 先怀疑 Builder/参数边界，而不是数据层**
- **⚠️ 验证姿势（这条最容易骗人）**：
  **不要**用「保存 → 重开 → 看值对不对」来验证 —— 值本来就是对的，会误判为没 bug。
  必须在**改完值后停留在当前页面**看 UI 是否立刻跟着变。
  UI 自动化可用 `hdc shell uinput -T -c <x> <y>` 点击 + `snapshot_display` 截图比对。

---

### LSN-020 图标统一用鸿蒙官方符号（`SymbolGlyph`），不要自研 SVG 图标组件
- **风险**：🟠 中频，但**成本极低收益极高**；反之自研图标体系的维护成本会持续累积
- **决策来源**：2026-09-17 用户明确要求「不要用 sficon，使用鸿蒙官方的图标」
- **为什么要放弃自研 SVG 图标组件（`SFIcon` 那套）**：
  | 维度 | 自研 SVG 体系 | 官方符号 |
  |---|---|---|
  | 资源 | 每个图标一个 `.svg` 文件（本项目曾达 **28 个**） | **零文件** |
  | 选中态 | 需手工备 normal / fill **两套**文件 | 系统已提供 `xxx` / `xxx_fill` 配对 |
  | 缩放 | 位图/矢量需自己适配 | 随系统字体缩放自动适配 |
  | 配色 | `Image.fillColor` 单色（多色层次会丢失） | `.fontColor([...])` 支持**分层多色** |
  | 动态 | `$r(\`app.media.${name}\`)` 需拼字符串 | 见下方约束（改传 Resource） |
- **选名方法（唯一权威来源）**：SDK 内置清单
  ```bash
  # 本机 HarmonyOS 26.0.0 / API 26 共 4042 个符号
  grep -A1 '"type": "symbol"' \
    "<DevEco>/sdk/default/openharmony/toolchains/id_defined.json" \
    | grep -o '"name": "[a-zA-Z0-9_]*"' | sed 's/.*"name": "//; s/"$//' | sort -u
  ```
  搜索关键词示例：`grep -E "yensign|coin|wallet"`（货币）、`grep -E "^heart|^chart|^histogram"`（图标族）
- **⚠️ 核心约束：`$r('sys.symbol.xxx')` 是编译期字面量，不能拼接变量**
  因此**通用组件不能收「符号名字符串」再自己解析**（`$r(\`sys.symbol.${name}\`)` 无效），
  必须把参数类型改成 **`Resource`**：
  ```ts
  // 通用组件（SettingItem）
  iconSymbol: Resource | null = null;          // 非装饰成员：图标不中途变化，无需观察
  // 组件内
  if (this.iconSymbol !== null) { SymbolGlyph(this.iconSymbol).fontSize(16).fontColor(['#FFFFFF']) }
  // 调用处（字面量写在调用点）
  SettingItem({ iconSymbol: $r('sys.symbol.trash'), iconBg: '#E60012' })
  ```
  接口字段同理：`interface SettingsGroupEntry { iconSymbol?: Resource; }`，
  透传时用 `iconSymbol: item.iconSymbol ?? null` 兜住「不传图标」的条目
- **两个易错点**：
  1. `.fontColor()` 收的是**数组**：`.fontColor([color])`（不是 `.fontColor(color)`）
  2. Tab 选中态在 `@Builder` 内**直接读 `this.currentIndex`**（可刷新）；符号本身是静态资源不参与刷新，不触发 LSN-019
- **本项目的落地映射（可作选名参考）**：
  | 用途 | 符号 |
  |---|---|
  | Tab 资产 / 心愿 / 趋势 / 设置 | `wallet(_fill)` / `heart(_fill)` / `histogram(_fill)` / `gearshape(_fill)` |
  | 主题·外观 | `paintpalette` | 
  | 声音/材质 | `speaker_wave_2` |
  | 删除/清空 | `trash` |
  | 关于/信息 | `info_circle` |
  | 会员皇冠 | `crown` |
  | 标题栏新增 | `plus` |
- **验证姿势**：符号名写错时**不报错、不崩溃，只是渲染空白**。
  故必须**真机截图确认图标真的画出来了**，不能只看构建通过。
- **附带收益**：本项目资源目录从 **33 个文件精简到 5 个**（仅剩应用图标与应用内空态插图）

---

### LSN-021 SDK 版本号书写格式**按 API 级别分界**：API ≥ 26 用点分制，别再加 `(api)` 后缀
- **风险**：🔴 写错**直接构建失败**（连编译都进不去），且两条错误信息互相矛盾，极易来回试错
- **场景**：2026-09-17 用户按 DevEco 提示把 SDK 升到 26，`compatibleSdkVersion` 写成 `"26.0.0"`——
  与本文档旧版 D5「必须写 `x.y.z(api)`」冲突，试错两轮
- **权威依据（读 hvigor 源码取得，非记忆）**：
  `hvigor-ohos-plugin/node_modules/@ohos/sdkmanager-common/build/src/core/constants/component-contants.js`
  ```js
  exports.API_VERSION_PATTERN     = /^(?:[1-9]\d{0,2}|...)$/;        // 旧式
  exports.DOT_API_VERSION_PATTERN = /^[1-9]\d?\.(?:[0-9]|[1-9]\d)\.(?:[0-9]|[1-9]\d)$/;  // 点分制
  exports.FIRST_DOT_API_VERSION   = 26;
  ```
  `utils.shouldUseDotApiVersion()` 注释原文：**「api版本大于等于26时…点分制版本号取major位比较」**
  即：`major >= 26` → 用 `DOT_API_VERSION_PATTERN`（**恰好三段、每段 1–2 位数字**）；
  否则用 `API_VERSION_PATTERN`。官方文档亦同：「**从 API 26.0.0 开始，HarmonyOS 和 OpenHarmony
  配置统一，字段类型是字符串，配置示例 `"compatibleSdkVersion": "26.0.0"`**」。
- **正确姿势**：
  ```json5
  // ① 先读本机 SDK 的真实版本
  //    cat <DevEco>/sdk/default/sdk-pkg.json  →  apiVersion / platformVersion
  // ② 按 API 级别选格式
  "compatibleSdkVersion": "26.0.0",   // API ≥ 26：点分制纯数字三段式
  "targetSdkVersion": "26.0.0",
  // 若 SDK 是 API 24 时代，则写：
  // "compatibleSdkVersion": "6.1.1(24)", "targetSdkVersion": "6.1.1(24)"
  ```
- **两种错误码对照**：
  | 错误码 | 触发 | 含义 |
  |---|---|---|
  | `00306042` | API < 26 时漏写 `(api)`，如 API24 环境写 `"26.0.0"` | must be string, Example: '5.0.0(12)' |
  | `00308018` | API ≥ 26 时多写了 `(api)`，如 `"26.0.0(26)"` | api version parameter is illegal! Expected format: `<major>[.<minor>][.<patch>]` |
- **附加事实（官方文档）**：`runtimeOS` 为 **HarmonyOS** 时 `compileSdkVersion` **不需要显式配置**
  （默认用 DevEco 内置 SDK），且**只能**配成本机配套的 SDK 版本；`targetSdkVersion` 未配则默认与
  `compileSdkVersion` 一致。所以通常只改 `compatibleSdkVersion` + `targetSdkVersion` 两个字段。
- **第三个错误码 `00303015`（IDE sync 比 CLI 构建更严，务必单独验）**：
  ```
  hvigor ERROR: 00303015 Configuration Error
  Error Message: In the project-level configuration file build-profile.json5, the version
  relationship between compileSdkVersion, compatibleSdkVersion and targetSdkVersion is incorrect.
  * Configure the API version according to the rule of
    compatibleSdkVersion <= targetSdkVersion <= compileSdkVersion.
  ```
  - **触发场景（本项目真实踩到）**：把 SDK 升到 26 时**只改了 `compatibleSdkVersion` 为 `"26.0.0"`，
    而 `targetSdkVersion` 还留着 `"6.1.1(24)"`** → compatible(26) > target(24) → 违反规则。
    **升版本必须两个字段一起改**，改半截必挂。
  - 校验实现（`hvigor-ohos-plugin/src/utils/one-sdk-validator.js` 的 `apiInspection`）末行即：
    `(c <= d && c <= p && d <= p) || printErrorExit("SDKVERSION_ORDER_ERROR")`
    —— `c=compatible.version`、`d=target.version`、`p=compile.version`
  - **重要**：`compileSdkVersion` 未配置时由 **IDE 解析到的 SDK** 决定，
    因此**同一个工程「CLI 构建通过」不代表「IDE sync 通过」**（两者可能解析到不同 SDK）。
  - **排查姿势**：先 `hvigorw.js --sync -p product=default --no-daemon` 复现（CLI 可直接看到该错误），
    而不是只在 IDE 里反复点 Sync。
- **口诀**：**"先读 sdk-pkg.json，再按 26 分界选写法：26 前带 `(api)`，26 起纯三段数字"**；
  **"升 SDK 三个版本字段要一起动，且 sync 与 build 都要各验一次"**

---

### LSN-022 沉浸光感材质（Immersive Material）：承载层五条属性 + 四条层级规则 + 三档降级
- **风险**：🟠 中频；材质**不生效、不刷新、不报错**——所有问题都只能靠**真机截图**发现
- **来源**：2026-09-17 AssetDailyCost 全量接入（卡片/hero/弹窗/chips）+ 官方《沉浸光感常见问题》
- **API 侦察先行**：`@ohos.arkui.uiMaterial`（经 `@kit.ArkUI` 导出，API 26+）——
  `ImmersiveMaterial({style, materialColor, colorInvert, applyShadow, interactive, lightEffect})`、
  `isImmersiveMaterialSupported()`、`getMaterialInfo(){state,type}`。
  应用级前置：`module.json5` metadata `ohos.arkui.UIMaterial.state="enable"`（**模板已自带**；改动后必须重装）
- **承载层只能用 `ToggleType.Button`**：官方文档明确 Checkbox 未适配材质、
  Switch 只覆盖开关本体那一小片；只有 Button 影响背景/边框/阴影，才能得到**一整块矩形材质**
- **五条属性缺一不可**（模板 `components/MaterialCard/MaterialCardLayer` 已内置，逐条注释了缺失后果）：
  ① `LayoutPolicy.matchParent`（百分比按"父级可用尺寸"解析，卡片在列表里会把卡片顶大）
  ② `borderRadius` 与外壳一致（否则 Toggle 画出自己的小圆角描边）
  ③ `backgroundColor(Color.Transparent)`（不透明底色垫在材质之下，叠灰甚至完全盖住）
  ④ `enabled(false)+focusable(false)+accessibilityLevel('no')+hitTestBehavior(None)`（只是画布）
  ⑤ `attributeModifier` 放属性链**最末**（systemMaterial 要在其他样式属性之后设置）
- **四条层级规则**（官方硬规则，逐条踩过）：
  ① 材质视觉层级位于 `backgroundColor`/`backgroundBlurStyle` **之下** → 承载层与外壳必须透明
  ② `systemMaterial` 放其他样式属性**之后** → 用 `attributeModifier` 挂链末
  ③ 材质**不采样同一 Stack 的兄弟节点**（采样组件背后的**窗口内容**）→ 内容画在材质**之上**
  ④ 弹窗面板不例外 → `bindSheet(..., { backgroundColor: Color.Transparent })`，否则默认白底盖住
- **`attributeModifier` 必须写成方法调用**（`this.carrierModifier()`）并在 `applyNormalAttribute`
  里读**订阅变量**（组件用 `@StorageLink` 持有开关值）——写成内联对象字面量 →
  拨开关后已画出来的组件不更新；函数内直接读 AppStorage 也登记不上依赖
- **`interactive: true` 配空 `lightEffect: {}` → 材质完全不渲染**：无流光色时**省略**该字段
- **惰性构造**：`export const X = uiMaterial.ImmersiveStyle.THIN` 模块级求值会在低版本设备
  启动即闪退 → 一律包在函数里；构造失败**返回 null**（别用 `Material.empty` 伪装成功）
- **缓存分档**：静态带影 / 静态无影 / 可交互按流光色存 Map —— 共用一档会出现
  「关掉阴影的那档把带阴影的覆盖了」
- **降级三件事**（API<26 / 应用开关关 / 系统总开关 DISABLE）：外壳模糊回 **Thin** +
  **半透明底色**（`fallbackSurface`，约 70% 不透明——不透明底色会把模糊盖住）+ 不下发材质
- **分形态接入**（模板已验证）：普通卡片=`MaterialCard{内容}`；小控件（chips/按钮）=
  `Stack{MaterialCardLayer(同控件圆角, layerShadow:false)+控件}`（chip **选中态保持实色深底**）；
  hero 渐变卡=`Stack{材质层+内容层(半透明品牌渐变沾色)}`——沾色放**内容层自身 linearGradient**
  （不能放外壳 backgroundColor，会被材质层级盖住），材质关时三元回退不透明渐变
- **⚠️ 验证姿势**：材质是否生效**无法读回**，只能真机截图看视觉结果（承载层区域应通透而非纯色）；
  建议在设置页放**诊断行**（`materialDiagnostics()`：材质支持/构造/系统状态/应用开关/承载 五段摊开）
- **模板内置文件**：`services/SystemMaterial.ets`（惰性构造/三档缓存/applyMaterialCarrier/
  pressLightColor/fallbackSurface/诊断）+ `components/MaterialCard/`（MaterialCardLayer + MaterialCard）
  + `module.json5` metadata。**键名约定**：`settings_forceMaterial`（默认 true，须与 `KEY_FORCE_MATERIAL` 一致）

---

### LSN-023 自定义壁纸：PhotoViewPicker 的 photoUris + 三处链路重放
- **风险**：🟠 中频；选择器字段名写错直接编译失败，链路漏放则「重启/旋屏后壁纸失效」
- **来源**：2026-09-17 AssetDailyCost 新增功能，真机全流程走通
- **选择器**：`photoAccessHelper.PhotoViewPicker`（**免权限**）——
  ① 字段名是 **`photoUris`**（`PhotoSelectResult` 是 class，定义在 openharmony 侧
  `@ohos.file.photoAccessHelper.d.ts`，**不是 hms 目录**；网络资料常误写 `uris`）
  ② `PhotoSelectOptions` 对象字面量必须**显式类型标注**（`arkts-no-untyped-obj-literals`）
  ③ **⚠️ 反例（2026-09-29 修正）**：**不要**写「picker 返回的 URI 自带永久授权，`persist/activate` 仅作保险」——
     这只对「**本次进程内**」成立。把 URI 存起来**跨重启**再用（书库/音乐库这类"存原始 URI 不复制文件"的
     场景），**持久授权必须每次启动重新 `activatePermission`**，否则 `openSync(uri)` 抛
     13900001(EPERM)。详见 **LSN-030**（本条曾误导 Icey-Reader 的阅读器漏掉启动激活 → 重启后白屏）
- **持久化**：SettingsManager 五步新增 `customBgUri`（键 `settings_customBgUri`）；
  **键名与模板 `SubPageScaffold` 的既有订阅一致 → 子页自动获得同一壁纸，零成本**
- **主题联动**：`ThemeManager.setCustomBg(has)` —— 有壁纸时页面背景色变**半透明**
  （约 70%，背景色退化为压暗层保证文字可读）；**不动深浅模式**
  （`applyThemeMode` 里按图片亮度联动的分支保持 dormant，需要时再启用）
- **渲染**：根 Stack **最底层** `Image(uri).objectFit(Cover).width('100%').height('100%')
  .expandSafeArea([SafeAreaType.SYSTEM],[TOP,BOTTOM])`——有壁纸时既有的
  `.backgroundColor(colors.background)` 自动变半透明压暗层，无需改
- **⚠️ 三处链路必须重放壁纸状态**（漏一处就「某场景下壁纸消失」）：
  ① App 启动（在 `applyThemeMode` **之后**调 `setCustomBg`）
  ② `EntryAbility.onConfigurationUpdate`——`updateFromConfig` 重算 colors 会把背景**打回不透明**，必须补放
  ③ 设置变更（setter 内联动）
- **与光感的协同**：壁纸是材质的「最佳舞台」——玻璃卡采样窗口背后的壁纸，**零适配**即得毛玻璃效果；
  hero 卡半透明沾色同样透出壁纸
- **⚠️ 两组载体各自的「蒙版」来源——必须都改成透明，否则壁纸被压白**（用户口语：「白色蒙版」）：
  | 载体 | ① 页面底色 | ② 标题栏滚动蒙层 |
  |---|---|---|
  | **主界面（tab）** | `Index` 的 `HdsNavigation.backgroundColor`（壁纸时 = `colors.background #B3F1F3F5` ≈70% 白，**整屏压暗**） | `buildHomeTitleBar` 的 `scrollEffectStyle.backgroundColor` = `#CCFFFFFF`(浅) / `#CC000000`(深) —— **80% 白块** |
  | **子页（push）** | `SubPageScaffold` 已写成 `customBgUri ? Color.Transparent : colors.background` | `buildSubPageTitleBar(..., transparentScrollMask = true, ...)` → `#00000000` |
  子页两条链默认就是透明的，**主界面极易漏**（本模板即出现「子页干净、主界面发白」的不一致）。
  做法：`HdsNavigation.backgroundColor` 改条件透明 + 给 `buildHomeTitleBar` **加 `transparentScrollMask` 形参**并传
  `wallpaperUri.length > 0`（口径与子页同名参数对齐）。
  ⚠️ 排查注意：`HdsNavigation` 的属性链上可能**重复写了两次 `backgroundColor`**（先 `Transparent` 后 `colors.background`，
  **后写生效**）——要改透明的是**最后那一次**，只删前面那次没有任何效果。
  ⚠️ 根 `Stack` 的底色**保留不透明**：它在壁纸 `Image` **之下**（Stack 自身底色先于子节点绘制），
  稳态不遮挡，仅作壁纸解码期间的兜底底色（避免首帧露 window 底色）。
- **模板内置依赖**：`services/FilePermission.ets`（persist/activate，分批+错误明细）
  + `components/SubPageScaffold`（子页壁纸渲染，模板自带）

---

### LSN-024 资源引用（$media/$color/$string）与文件不成对 → 构建报错且指向中间产物
- **风险**：🔴 高频；报错路径是 `entry/build/.../module.json`（**中间产物**），
  看不到真实源头，极易在错误的位置排查
- **场景**：2026-09-17 模板构建报 `The resource reference '$media:tab_music' is not defined
  At file: ...\entry\build\default\intermediates\process_profile\default\module.json`——
  真实源头是 `src/main/module.json5` 里残留的旧图标引用，而 `resources/base/media/` 已被精简
- **防御**：引用与资源**成对检查**——改完先
  `grep -rn '\$media:' --include="*.json5" src/main/` 列出全部引用，
  再 `ls resources/base/media/` 核对；报错指向 build 目录时**直接去 src/main 找同名引用**
- **附带教训**：**模板/工程每次精简资源后必须跑一次完整构建**——资源阶段（CompileResource）
  在 ArkTS 编译**之前**，资源坏了会掩盖后面的所有错误信息

---

### LSN-025 「实色大卡」改「多卡光感」时的三件事：控件可辨性 / 属性链位置 / 分卡边界
- **风险**：🟠 中频。①是**纯视觉缺陷**（编译全绿、不报错，只有真机截图才看得出）；
  ②**直接编译失败**但报错点误导；③只是改动量问题
- **来源**：2026-09-18 AssetDailyCost 新增/编辑表单——由「单张实色 cardBg 大卡」改为
  「8 张 `MaterialCard` + 强制光感」，卡片节奏与「趋势」tab 对齐（用户要求「样式参照趋势界面，采用多卡片」）

**① 卡内控件可辨性（最容易漏，也最容易被用户一眼看出）**
实色卡时代，卡内控件靠 `surface(#F5F5F5)` 填充与 `cardBg(#FFFFFF)` 的**亮度差**划定边界；
换成光感材质（或降级毛玻璃）后卡面亮度 ≈ 页面背景，浅填充与卡面几乎同色 ⇒ 输入框/开关行/分段控件"消失"。
两种修法：
- **(a) 加 `0.5vp` 发丝描边（推荐）**：复用现成的 `colors.fieldBorder`（浅色 `#1A000000` 10% 黑 /
  深色 `#33FFFFFF` 20% 白）。**实色填充保留不动** ⇒ 输入文字对比度不受材质影响，深浅两种模式都成立
- (b) 把填充改成比卡面更亮的 `cardBg`：依赖卡面实际亮度，材质/降级两条路径表现不一致，不如描边稳

⚠️ **次级按钮同理，且更隐蔽**：`surface` 填充的按钮**直接贴在页面背景上**在浅色下几乎不可见
（`#F2F3F4` vs `#F5F5F5`）；原先"按钮贴在实色大卡里"之所以正常，只是因为卡片是 `cardBg(#FFFFFF)`。
⇒ **操作区（取消/保存/删除等）必须留在卡片内**，或同样加描边；主按钮（brand 色实心）不受影响。
原注释「表单卡片用实色 cardBg 保证输入可读性」这一取舍，在多卡 + 光感方案下应改写为
**"实色填充 + 发丝描边"**。

⚠️ **只读内容块（备注 / 说明文字）同样要"承载"**：玻璃卡面上直接铺一段正文，深浅两色都可能不够清晰；
应给内容套一层与输入框同款的容器（`surface` 底 + `borderRadius 12` + `0.5vp colors.fieldBorder` 描边）。
好处是"同一份内容在表单页是 TextArea、在详情页是同款承载"，视觉语言一致、切换无割裂。

⚠️ **字段为空时不要整块隐藏**（用户会分不清"没填"与"不支持"）：详情/只读页的字段卡应**常驻**，
空值给占位文案（如「暂无备注」）。本工程实证：详情页备注卡原为"无备注不渲染"，
用户随即报「详情页要能显示备注」——隐藏掉一整栏的代价是**用户不知道这一栏存在**。
（表单/编辑页相反：空字段不渲染更清爽，因为没有"这一栏存在与否"的疑问。）

**② 属性链位置：报错点比真实元凶低一层**
给已有嵌套结构**插入**卡片边界时，内层容器的属性链必须写在
**内层容器 `}` 之后、外层自定义组件 `}` 之前**：
```ts
ListItem() {
  MaterialCard({ cardRadius: 20, cardMarginTop: 12 }) {
    Column({ space: 12 }) { ...字段... }
    .width('100%')            // ✅ 修饰符跟着内层容器走
    .padding(16)
  }                           // ← 这里才结束 MaterialCard
}
```
写成 `}`（内层）→ `}`（外层）→ `.width(...)` 会报
`10505001 Declaration or statement expected` + `Cannot find name 'width'`，
**报错落在那个 `}` 的下一行**，与真实元凶差一层，极易去查无关的地方。
与**附录 D7**（自定义组件后链式挂 `bindSheet`）同源：**自定义组件（含 `@BuilderParam` 尾随 lambda 的组件）
闭括号之后不能再挂属性链**。
自查手段：改完 `grep -n '^\s*}\s*$' -A2` 或直接读改动的边界块——`}` 后面若紧跟 `.xxx(` 就是本坑。

**③ 分卡边界直接取原有「区块标题」**
长表单改多卡时，以原 `sectionTitle('xxx')` 调用点作为切割锚点——一个标题 = 一张卡的标题，
改动量最小、语义不变。两个附带事实：
- `if (分支) { ListItem() ... }` 里可以放**多个** ListItem（同一分支拆多张卡无需额外包裹），
  `List` 的 `space` 只对实际渲染出的 ListItem 生效（分支不成立时不产生空档）
- 卡标题样式统一成卡片规格（**14 / Medium / textPrimary / width 100%**）——
  原先区块标题常用的 12 / 次级色在"每块都是一张卡"的语境下层级不足
- 卡片间距口径与参照页保持一致：`List({ space: 12 })` + `MaterialCard.cardMarginTop: 12`

**口诀**：**"卡从实色换玻璃，控件靠描边找边界、按钮留在卡内；属性链挂内层容器；标题即卡界"**

---

### LSN-026 沉浸光感必须有「可采样底层」：纯色背景上必然退化为灰玻璃
- **风险**：🟠 中频，**纯视觉缺陷、编译全绿**，只有真机截图能发现；且**默认状态就会命中**
  （模板/大多数用户初始都没有自定义壁纸）
- **来源**：2026-09-18 AssetDailyCost 真机反馈——「强制光感没有自定义背景图的时候，应该变回白色」

**现象**：没有设置自定义壁纸时打开「强制光感」，卡片不是通透的实色卡，
而是一块**与页面底色几乎相同的灰玻璃**（浅色下只剩一圈模糊边）。
比不开材质的实色白卡**更差**，看起来像"卡片没画出来"。

**根因（一句话）**：材质采样的对象是**组件背后的窗口内容**（LSN-022 规则③：不采样同 Stack 兄弟节点）。
应用在**无壁纸时页面背景是一整片纯色**（`colors.background`）⇒ 材质与毛玻璃背后没有任何信息可采，
只能把纯色再模糊一遍 ⇒ 卡面 ≈ 页面底色。
> ⇒ **材质的观感依赖「背后有内容」。没有可采样底层时，材质不是"低配玻璃"，而是"错误的视觉"。**

**修法（四步，缺任一都会出现"只有一部分卡片正常"）**
1. **判定独立成形参**：`materialActive(forceOn)` → `materialActive(forceOn, backdrop)`
   （本工程底层来源 = 自定义壁纸 ⇒ `backdropAvailable(customBgUri)` + `KEY_CUSTOM_BG_URI`）。
   做成**第二形参**而非函数内部读 AppStorage：既满足"依赖必须由调用方传订阅值"的局部更新规则，
   又能**让编译器强制所有调用点表态**——漏改即报参数数量不匹配，不会静默漏掉某个卡片形态。
   （本工程首改即 6 个调用点：`MaterialCard` / `SheetContainer` / `AppSheet` /
   `AssetSummaryCard` / `AssetTab` / `WishTab`）
2. **回落实色，而不是"降级模糊"**：无底层时 `.backgroundColor(cardBg)`（浅色白 / 深色 #212121）
   且 `backgroundBlurStyle(NONE)`——背后是纯色，模糊不仅无收益还会拖性能。
   注意这**多出一态**：原来的两态（材质 / 半透明+模糊）变成三态
   （材质 / 有底层但材质不可用=半透明+模糊 / **无底层=实色**）
3. **同源控件一律同步**（否则用户会看到"有的卡白了、有的还是灰的"）：
   - `GlassCard` / `SettingsGroupCard` 等 `MaterialCard` 派生组件：自动继承，无需改
   - hero 卡（材质 + 半透明沾色）：无底层 ⇒ 沾色改**完全不透明**（品牌色不再被玻璃洗淡）
   - chips / 排序按钮：无底层 ⇒ 实色 `cardBg`
   - 弹窗卡片：无底层 ⇒ 实色 `cardBg`，且**弹窗宿主的底也要改回不透明**
     （否则弹窗卡片实色了、弹窗外壳还透明，会透出底层内容）
4. **诊断串加一档**：`materialDiagnostics()` 输出「底层=自定义壁纸 / 无」，
   并把承载结论细化为「下发材质 / 降级毛玻璃 / 实色卡片（无壁纸）」，避免"开关打开却看不出效果"的困惑

**通用推论（不限于壁纸）**：任何"采样背景"的视觉能力（材质、毛玻璃、`backgroundEffect`）
都隐含**前置条件——背后得有东西**。设计这类开关时应当**同时定义它的回退形态**，
并在设置项副标题里写清前置条件：本工程即改为
「有自定义壁纸时卡片走系统「沉浸光感」材质，无壁纸时回落实色卡片」。

### 补遗（2026-10-02，reader / Icey-Reader 实测三连）：门槛对了，颜色还会不对
> 上面四步做完，**"卡片该不该走材质"已经正确**；但用户仍可能反馈「卡片颜色不对」。
> 那是另外两条**独立**成因，必须分别修——只修门槛不会消失。

**① 薄层材质不该额外着色**（`materialColor` 必须 `Color.Transparent`）
- 症状：有壁纸时卡片发**"奶白"**、玻璃感被抹平；无壁纸时卡面比页面**灰一档**。
- 根因：材质出口函数对**所有** scope 都喂了 `systemMaterialColor()`（浅色 = 42% 白 `#6BFFFFFF`）。
  42% 白是"给弹窗**面板**压住内容"用的，套到薄层卡片上就是一层白纱。
- 正解（与 player `SettingsManager` 同口径）：
  | 场景 | materialColor |
  |---|---|
  | `'sheet'`（弹窗**面板**） | 按挡位着色 |
  | `'menu'` / `'search'` / `'system'`（**薄层**） | **`Color.Transparent`** |
  ⇒ 挡位差异只由 `style` 表达，着色不参与薄层。单函数出口就写 `scope === 'sheet' ? 着色 : Transparent`。

**② 无壁纸的兜底底必须是 `cardBg` 实色 + `BlurStyle.NONE`**
- 症状：无壁纸时卡面是**"一块与页面糊在一起的灰玻璃"**（与 026 首版症状同源，但成因不同）。
- 根因：兜底色沿用了**半透明** `#B3F2F3F5` + `BlurStyle.Thin`——那是"材质不可用一律配毛玻璃"
  时代的写法（半透明才透得出模糊）。但**无壁纸时既没有东西可透、又让卡片与页面糊在一起**。
- 正解（三态表，与 LSN-026 第 2 步合并成同一张表）：
  | 状态 | backgroundColor | backgroundBlurStyle |
  |---|---|---|
  | 有壁纸 + 材质可用 | `Color.Transparent`（材质接管） | `NONE`（材质自带模糊，双层发灰） |
  | 有壁纸 + 材质不可用 | `Color.Transparent` | `COMPONENT_REGULAR` / `Thin` |
  | **无壁纸**（不论材质可用与否） | **`colors.cardBg` 实色** | **`NONE`** |

**③ 门槛要分「页面卡片 / 弹窗卡片」两套，且页面卡片**必须**要求有壁纸**
- 与 LSN-026 第 1 步的"独立成形参"配套：把判定拆成两个具名函数更好读——
  `materialActiveWithWallpaper(forceOn, customBgUri)`（页面卡片）与
  `materialActive(forceOn)`（弹窗卡片 / 浮动件）。
- ⚠️ 常见错法：**页面卡片只判 API 可用性**（`materialActive(forceOn)`）——就是 026 那条根因的复发。
  player 的三处页面卡片（`GlassCard` / `SettingsGroupCard` / `SettingsGroup`）**全部**都写
  `customBgUri.length > 0 && materialAvailable()`；只有**弹窗内卡片**（压在 sheet 面板上）与
  **浮动件**（背后恒有内容可采样）才只判 API。
- 同一文件内两套门槛并存时**必须分成两个方法**并在注释里互相指路（`useMaterial()` /
  `useActionMaterial()`），否则日后必被误换成一个。

**口诀**：**"薄层不着色、无底就实色；页面卡要壁纸，弹窗卡不要"**

---

### LSN-027 长按手势：`Stack`/`Column` 没有 `.onLongPress` 修饰符，必须用 `LongPressGesture` + `.gesture()`
- **风险**：🟡 低频但**必踩一次**——写"长按"时直觉会去写 `.onLongPress(...)`，
  该修饰符在容器组件上不存在，**直接编译失败**；且失败后若去"补 import"，会踩第二个错
- **来源**：2026-09-18 AssetDailyCost——用户要求「列表卡片改为长按编辑」，连报两种编译错误后定稿

**两个连环编译错误（现场记录）**
1. `.onLongPress(() => {...})` 挂在 `Stack` / `Column` 上：
   `10505001 Property 'onLongPress' does not exist on type 'StackAttribute'`（换 `Column` 报 `'ColumnAttribute'`）。
   ⇒ **API 26 的 `StackAttribute` / `ColumnAttribute` 均无 `onLongPress` 成员**，不是拼写问题。
2. 于是改 `import { LongPressGesture } from '@kit.ArkUI'`：
   `10311006 'LongPressGesture' is not exported from Kit '@kit.ArkUI'`。
   ⇒ **`LongPressGesture` 属于 ArkUI 全局声明，本来就无需 import**；从 kit 里导反而报错。

**正确写法（手势描述符 + `.gesture()`）**
```ts
// 不要 import LongPressGesture —— 它是全局声明
Stack() { /* 内容 */ }
  .width('100%')
  .gesture(
    LongPressGesture({ duration: 500 })   // 默认 500ms 即系统长按阈值
      .onAction(() => { this.onLongPress(); })
  )
```
- **挂载点选容器根节点**（如卡片外壳的根 `Stack`）：手势判定范围 = 该组件矩形；
  内部若有"不吃手势"的承载层（`hitTestBehavior(HitTestMode.None)` + `enabled(false)`，
  如 `MaterialCardLayer`）不会拦截，整卡区域都能触发
- **`.gesture()` 默认 `GesturePriority.Normal`**：与宿主 `List` 的滚动手势可共存——
  长按要求"按住不动 500ms"，滚动要求"位移"，二者判定条件互斥，列表内长按可正常工作
- 需要"长按后持续触发"才加 `repeat: true`（如连发按钮），编辑入口用默认单次即可

**与 `.onClick` 的取舍**：把交互从点击改为长按 = **`.onClick` 整段替换为 `.gesture(LongPressGesture)`**。
改完后：
- 短按不再有响应（这正是"防误触浏览列表"要的效果）
- 回调属性建议同步改名（如 `onCardTap` → `onLongPress`），**让调用点漏改编译失败**而不是静默沿用旧语义
- 复用组件（本工程 `MaterialCard` 有 12+ 调用点）应把回调做成**带默认空实现的可选属性**
  （`onLongPress: () => void = () => {}`），不传的调用点零副作用

**口诀**：**"长按不用 onLongPress，LongPressGesture 不用 import、配 .gesture()"**

---

### LSN-028 同一组件「点击 + 长按」必须绑成 `GestureGroup(Exclusive)`；详情页刷新走 `@State` 视图模型
- **风险**：🟠 中频——三处都**编译全绿**、只在真机暴露：① 长按后**双跳**（进编辑页又跳详情页）；
  ② 编辑保存返回详情页**还显示旧值**；③ `ForEach` 列表值变了**界面不更新**
- **来源**：2026-09-18 AssetDailyCost——用户要求「长按编辑」后再要求「点击查看详情」，一轮内三坑齐现

**坑 ①：`.onClick` 与 `.gesture(LongPressGesture)` 并存 → 长按抬手后点击也触发**
一次「长按进编辑页」，抬手又被点击命中「跳详情页」⇒ 路由栈里连进两页，用户看到的是莫名其妙的跳转。
正确写法 = **互斥手势组**（保证"先满足条件者胜出"）：
```ts
.gesture(
  GestureGroup(GestureMode.Exclusive,
    LongPressGesture({ duration: 500 }).onAction(() => { this.onLongPress(); }),
    TapGesture({ count: 1 }).onAction(() => { this.onTap(); })
  )
)
```
- 按住 500ms → 长按命中、点击判负；快速抬手 → 点击命中、长按判负
- 回调属性仍建议**成对提供并带默认空实现**（`onTap` / `onLongPress`），未传的调用点零副作用
- ❌ 不要用 `GestureMode.Parallel`（并行 = 两个都触发）；❌ 不要写两个 `.gesture()` 叠加

**坑 ②：子页需要「外部数据变更后自动刷新」时，别用「build 现算 + 普通字段缓存」**
把重算结果放进**非状态字段**（`private cache`）再在 `build()` 里读，刷新链变成
「`@StorageLink` 变化 → 父组件重渲染 → *会不会顺带重跑 `@Builder`*」——后半段是**不确定行为**，
表现为「编辑保存返回后详情页仍是旧值，退出重进才对」。
正确写法 = **`@State` 持有视图模型 + `@Watch` 驱动重算**（`@Watch` 必须写在状态装饰器**之前**，见 LSN-012）：
```ts
@Watch('reload') @StorageLink('assetsVersion') assetsVersion: number = 0;
@State view: DetailView = DetailView.of(null, [], 0);
reload(): void { this.view = DetailView.of(this.row(), AssetRepository.all(), Date.now()); }
```
配套两条：
- **入参只取 `id`、不持有记录快照**：快照会被编辑页替换掉，页面永远读 `repo.find(id)`；
  `find` 返回 `null` ⇒ 渲染「记录不存在」兜底卡（不要在 build 里 pop，也不要不处理）
- **口径仍归 model**（LSN-015）：`DetailView` 只做文案拼装，日均/进度/达标/汇总一律调既有 model 方法
  —— 视图模型可以是页面内私有 class（同 `SegmentsParams` 范式），但**不许复算业务**

**坑 ③：`ForEach` 的 key 只写"身份"不写"值" → 值变了不刷新**
`ForEach` 对 **key 相同**的项**复用既有节点、不重跑 `@Builder`**。明细行若用 `kv_${label}` 作 key，
「已使用 / 目标成本 / 已存金额」这类**行还在、值变了**的就永远停在旧值（最隐蔽的一种）。
对策：**key 里带上会变的值**（必要时连"是否最后一行/是否强调"一起带）：
```ts
ForEach(v.rows, (r: KvRow) => { this.kvRow(r) },
  (r: KvRow) => `kv_${r.label}_${r.value}_${r.accent}_${r.isLast}`)
```
> 口诀：**"ForEach 的 key 要能代表'这一屏长什么样'，代表不了就会赖着不更新"**

**口诀**：**"点击长按绑一组、子页刷新用 @State、ForEach 的 key 带上值"**

---

### LSN-029 `.gitignore` 签名约定（2026-10-17 终版）：signing 打包文件全提交、material 不提交、密码不记录

- **风险**：🔴 仓库里一个签名文件都没有 ⇒ 新机器 clone 后 `assembleHap` 产不出可安装包
  （`entry-default-unsigned.hap` / 安装报 `9568320 no signature file`），
  也无法复现签名类问题（`00303074` p7b bundle-name 不匹配等）。
- **场景**：2026-09-29 Icey-Reader —— 照抄模板 `.gitignore` 的**裸 `signing/`** ⇒
  整个签名目录被 ignore，`git status` 永远看不见；用户复核 commit 时发现并纠正。
- **⚠️ 2026-10-17 终版定案（用户原话：「只是不记录密码 不提交 material
  因为换设备都要重输密码 material 也会重新生成」）**：
  本条经历过**两次反转**（09-29 "material 是缓存可忽略" → 10-08 "material 必须进仓库"），
  终版以**用户工作流**为准：换设备 = 重输密码 ⇒ material 重新生成 ⇒ **material 不提交**。
  （v1.4.1 的"material 必须进仓库"更正**作废**——那是单机换目录场景的结论，跨设备场景
  material 根本不需要。）

  ```gitignore
  # 签名：p7b/cer/p12/csr 全提交；material 不提交（换设备重输密码后重新生成）；
  # 密码只以密文存在 build-profile.json5 里随仓库走，明文密码绝不记录
  /signing/material/
  /signing/debug/material/
  ```

  | 路径 | 是否版本化 | 理由（终版） |
  |---|---|---|
  | `signing/debug/*.p7b` `.cer` `.p12` `.csr` | ✅ 进仓库 | 新机器构建可安装 HAP 的必要材料 |
  | `signing/release.*` | ✅ 进仓库 | 同上（发布链） |
  | `signing/**/material/**` | ❌ **不提交** | 换设备重输密码后重新生成（提交它反而是噪音） |
  | `build-profile.json5` 里的**密码密文** | ✅ 随仓库走 | 密文安全；**明文密码绝不写进任何文件** |

- **⚠️ 跨应用复用（2026-10-17 用户：「换应用就是换 p7b 其他的都通用」）**：
  **同一套 cer / p12 / csr 跨所有 Icey 系应用通用**，换应用只需要**换 `.p7b`**
  （profile 按 bundleName 绑定）⇒ 新应用的 signing 接入成本 = 拷全套 + 换一个 p7b。
  （实证：Icey-Reader 的 `signing/debug/debug.p7b.bak-iceyplayer` 就是换应用时留下的旧 p7b 备份。）
- **⚠️ 判定口径**：`git check-ignore <目录>` 对**目录路径**的判定不可信；
  验证一律用 **`git status --porcelain`** + **`git ls-files | grep signing`**（权威）。
- **口诀**：**"signing 全提交、material 与明文密码除外；换应用只换 p7b；check-ignore 不可信用 ls-files 验"**

---

### LSN-030 存 URI 不复制文件 ⇒ **每次启动必须重新 `activatePermission`**（漏掉=重启后静默白屏）

- **风险**：🔴 高危且**极难定位** —— 症状是"**导入当次完全正常，杀进程重开就白屏**"，
  代码里没有任何报错，画布只剩一层底色；不看日志完全想不到是权限。
- **场景**：2026-09-29/30 Icey-Reader（本地电子书阅读器）：用户两次报"进入阅读页白屏"。
  前几轮我一直在怀疑 `canvasW` 尺寸 / 排版口径 / px2vp（都不成立，见 LSN-029 上一条的排查史）。
  真因是**剪裁模板时漏抄了权限激活**。
- **机理**（三步锁死）：
  1. 本地书/音乐**不拷贝进沙箱**（省空间 + 秒导入）⇒ 仓库里存的是导入时的**原始 URI**
     （`file://docs/storage/.../x.txt`），正文靠 `fileShare` 持久授权**直读原始 URI**。
  2. `fileShare.persistPermission(policies)` 授予的权限**跨应用重启不会自动生效**，
     必须**每次启动**对每个 URI 调 `fileShare.activatePermission(policies)`。
     ⚠️ 「picker 返回的 URI 自带永久授权」**只在本次进程内成立**（LSN-023 旧文曾据此写成"仅作保险"，已修正）。
  3. 漏掉第 2 步 ⇒ 重启后 `fileIo.openSync(原始URI)` 抛 **13900001 EPERM** ⇒
     读取函数的 `catch` 只 `AppLogger.error` 就 return（**静默**）⇒ 渲染层拿到空内容 ⇒
     `drawPageContent(ctx, undefined)` 只填了个底色 ⇒ 用户看到**纯色白屏**。
- **指纹（怎么一眼认出它）**：
  | 现象 | 说明 |
  |---|---|
  | **导入当次能看，重开就白屏** | ★ 最强指纹：导入时 picker 刚授的权还在 |
  | 冷启动后所有"历史数据"都打不开 | 但新建的（本次导入的）正常 |
  | 日志出现 `13900001` / `EPERM` / `PERMISSION_NOT_PERSISTED(4)` | 直接坐实 |
- **正解（两件事都要做，缺一仍复发）**：
  ```ts
  // ① 启动恢复链路里复激活（EntryAbility.startupReady 内，数据仓库 init 之后）
  await BookRepo.activatePermissions();   // 遍历全部 bookUrl 调 FilePermission.activate(uris)

  // 仓库侧（BookRepo / MediaScanner 同款）
  static async activatePermissions(): Promise<void> {
    const uris = BookRepo.books.map(b => b.bookUrl).filter(u => u.length > 0);
    if (uris.length === 0) return;
    try { await FilePermission.activate(uris); }        // 内部分批(≤200) + 逐 URI 错误明细
    catch (e) { AppLogger.error(TAG, `activatePermissions 失败: ${JSON.stringify(e)}`); }
  }
  ```
  ```ts
  // ② 读取路径再加"单 URI 兜底"（覆盖"本次导入但 persist 失败"/"用户刚移动过文件"）
  try { await FilePermission.ensureActive(uri); } catch (_) {}   // 内部 activate 失败会 persist+activate 重试
  ```
- **参考实现**：`Icey-Player-Harmony/services/MediaScanner.ets:540` 注释即写着
  「**存原始 URI，重启后通过 activatePermission 恢复访问，不复制文件**」，并在 `:152/:624` 分批激活。
  本项目模板 `services/FilePermission.ets` 已自带 `persist/activate/ensureActive/waitActivateDone` ——
  **剪裁模板时"删掉没被引用到的服务"很容易把它连带删掉，务必保留**。
- **配套原则（本轮一并确立）**：**绝不静默失败**。凡是"内容读到空 ⇒ 界面整片空"的路径
  （记录缺失 / 目录为空 / **正文 0 字** / 排版 0 页 / 读文件抛异常），都必须落到**可见错误态
  + 重试入口**，而不是只打日志。这次白屏之所以拖了两轮才定位，根因就是**失败被静默吞掉**。
- **口诀**：**"存 URI 不复制 ⇒ 每次启动 activate；导入能看重开白 ⇒ 先查 13900001"**

---

### LSN-031 Canvas 自绘正文要支持「长按划选」+ 功能面横向铺开（划选命中 / 手势分流 / 跨页返回）

- **场景**：2026-09-30 Icey-Reader：用户要求「照着 legado 把该做的功能都做了」——
  阅读页一次性补齐 **书签 / 笔记 / 划选 / 书内搜索 / 阅读统计 / 书架分组 / 排版扩展**。
  其中**长按划选**是唯一需要"在 Canvas 上做字符命中测试"的能力；其余几个坑都是
  **一次横铺多个能力**时才暴露的（这类"能力面对齐"任务建议一次做完 + 一次编译，比零敲碎打省事）。
- **坑① Canvas 自绘文本的字符命中（最容易写错，也最值得一次写对）**：
  - ❌ 错法：用「局部 `y / 页高`」或「`x / 行宽`」的比例**线性估**字符下标 ——
    行高、字宽随**字号 / 字距 / 段距**变化，估算**必然错位**（多选一个字、少选一个字、跨行乱选）。
  - ✅ 正解（**三层收敛**，逐层都用真实数据、不用比例）：
    1. `localX/px2vp − 页边距` ⇒ 得到**页内容区**坐标
       （⚠️ 别拿画布原始坐标去比字形坐标，页边距会整体偏移）；
    2. 按**行**的 y 区间定位到行：`行高 = 字号 × lineSpacing`，且**标题行字号 +2**
       （标题与正文行高不同；只用正文行高 ⇒ 从标题之后开始**整页错位一整行**）；
    3. 行内按字形 `x` 找**最后一个「左缘 ≤ cx」**的字形；若已越过该字形**右缘中点**则 +1；
       章内字符偏移 = `line.charStart + idx`（注意是**章内偏移**，不是页内偏移）。
  - ★ **关键前提**：排版产物必须**每行都带 `charStart`（章内起始偏移）**。若排版结果只有
    一个字符串（无偏移表）⇒ 无法映射回章内位置 ⇒ 划选只能拿到"屏幕上一段"，**无法与
    书签 / 笔记的 `chapterPos` 对齐**。**排版期就把偏移存下来，别在交互期反推。**
- **坑② 划选必须与翻页手势「同一手势分流」，不要再加一个手势**：
  阅读页已用 `PanGesture` 做翻页；再挂独立 `PanGesture` / 手势组做划选 ⇒ 两者争抢，
  出现"想选字结果翻页"。正解 = **复用同一个 Pan，按状态分流**：
  ```ts
  .gesture(PanGesture()
    .onActionStart(e  => { if (this.selecting) this.extendSelect(e); })
    .onActionUpdate(e => { if (this.selecting) this.extendSelect(e); })          // selecting ⇒ 扩选
    .onActionEnd(e    => { if (this.selecting) return; this.handlePageSwipe(e); })// 否则 ⇒ 翻页
  )
  ```
  进入划选的入口是**长按**（`LongPressGesture({ repeat: false, duration: 400 })` → `beginSelect`）；
  退出用页面点击（`selecting` 态下 `exitSelect()` 后 **直接 `return`**，**不要再触发翻页 / 呼出菜单**）。
- **坑③ 划选底衬要「逐行画」，不能把章内偏移当页面坐标**：
  选中区间是**章内字符偏移** `[selStart, selEnd)`，而绘制发生在**当前页**坐标系里。
  正解 = 遍历当前页每一行，求**行与选中区间的交集**，**逐行**铺半透明色块
  （`ctx.fillRect(行左缘, 行顶, 按交集字符数折算的行宽, 行高)`）；直接拿 `selStart/selEnd`
  当 x/y 去画会**跑到页外**。色块用 accent 色 **alpha≈0.22** 半透明，叠在文字**之下**。
- **坑④ 划选浮动条 / 长按菜单「只放文字项」**：浮条 `position({ x: 16, y: 96 })` 固定贴顶，
  底色 `#E6000000`，项 = 「**笔记 / 复制 / 取消**」**纯文字**（不引图标）；
  破坏性项（删除笔记）用**红色文字**表达，不靠图标 —— 与本项目一贯 UI 口径一致（§2）。
- **坑⑤ 从「管理页」返回阅读页：栈里不一定有阅读页**：
  书签列表 / 搜索结果可能从**书架 → 书籍详情页**直接进入，此时路由栈里**没有阅读页**，
  一律 `pop()` 会退到**错页**（详情页）而不是阅读页。正解 = 先判存在再决定：
  ```ts
  AppRouter.getInstance().has(ROUTE_READER) ? pop() : push(ROUTE_READER, bookUrl);
  // has(name) = pathStack.getAllPathName().indexOf(name) >= 0
  ```
  配套：搜索页与书签页**共用一条跳转信号**（`@StorageLink('readerSearchJump')`），
  阅读页 `@Watch` 消费后**立即清空信号**（否则同一条会被反复触发）。
- **配套：功能面横向铺开时的 3 个必查项**（本轮全部踩到）：
  1. **`$r('sys.symbol.xxx')` 必须先核实存在** —— 符号名写错**不报错、只是渲染空白**（LSN-020）。
     查 `<DevEco>/sdk/default/openharmony/toolchains/id_defined.json` 里 `"type":"symbol"` 的记录。
     本轮实测**存在**：`bookmark` / `bookmark_fill` / `bookmark_notepad` / `magnifyingglass` /
     `timer` / `folder` / `xmark_circle_fill` / `square_and_pencil` / `trash` /
     `exclamationmark_circle` / `arrow_counterclockwise`；
     **不存在**：`bookmark_square` / `note_text` / `highlighter` / `chart_bar` / `text_quote` / `pencil`。
  2. **单文件内同一模块只写一行 import** —— `import { AppRouter }` 与 `import { ROUTE_SEARCH }`
     各写一行 ⇒ 视同重复声明报错；合并成 `import { AppRouter, ROUTE_SEARCH } from '...'`。
  3. **新增成员一旦写到 struct 的 `}` 之后，会引发几十条级联假错误**（见坑点速查表）：
     报 `Property 'xxx' does not exist on type 'Xxx'` + `UI component 'Column' cannot be used in
     this place` + `Cannot find name 'b'`。**元凶在报错点之外** —— 用脚本扫「独占一行的 `}`」
     定位那个提前闭合处（本工程实证在 615 行），把成员移回结构体内即可，**别按报错逐条补**。
- **口诀**：**"划选三层收敛（局部→行→字形），手势同源分流；跨页先问 has，符号先查 id_defined"**

---

### LSN-032 几何变换（`scale`/`rotate`/`translate`）挂在**内容层** ⇒ 命中热区收窄 ⇒ 「看得见、点不动」

- **场景**：2026-10-02 Icey-Reader。做「书架卡片 → 阅读页一镜到底」转场时，
  把整页（含正文）包在根容器里做变换 ⇒ 用户报「**进入阅读页 完全无法操作了 翻页 点击出操作啥的都不行**」。
- **⚠️ 同一事故发生了两次，第二次更隐蔽**：
  | 轮次 | 挂上去的修饰符 | 为什么第一次修完还复发 |
  |---|---|---|
  | 首次 | `scale(sx,sy) + translate(x,y)` | 修法只写明「内容层绝不能参与几何变换」，**举例只列了 scale/translate** |
  | 复发 | `.rotate({ angle: -90, centerX: 0, centerY: '50%' })` | 作者以为"旋转只是动画"、不属于那两类 ⇒ **漏网**，同一 P0 原样复发 |
  ⇒ **教训：铁律必须按「改变几何」这个本质来表述，不能按枚举具体 API 来表述** ——
  凡改几何的修饰符（`scale` / `rotate` / `translate` / `rotate3D` / …）一视同仁。
- **机理（数学闭合，不是猜测）**：ArkUI 的**命中测试按变换后的几何计算**。
  - `scale 0.29` ⇒ 热区只剩原尺寸 29%（用户点屏幕中央，落在小块外 ⇒ 空命中）；
  - `rotateY(-90°)` + `centerX: 0` ⇒ 该节点 **edge-on、投影宽 → 0 ⇒ 热区宽为 0 ⇒ 全页点不到**。
- **⚠️ 为什么表现为「看得见、点不动」这种最难排查的组合拆解**：
  `ReadPageComponent`（Reader Kit 内核）内部是 **`XComponent`**（native GPU surface）、
  自绘内核是 **`Canvas`** —— 两者的画面都由 SDK 直绘，**不受 ArkUI 的 scale/rotate/translate 影响** ⇒
  **正文照常满屏可见**，而**命中区已被缩/转没了**。恰好两条内核表现完全一致 ⇒
  极易被误当成两个独立的 bug 去分别排查。
- **判据（真机 hilog，决定性）**：
  ```
  W InputKeyFlow: ITK Id:761851, TTHNI:fId: 0        ← 命中链为空
  W InputKeyFlow: Touch test result is empty.        ← 该次点击不落在任何组件上
  ```
  对照正常值：同机其它 App 是 `{ T: List, D: 36 };{ T: List, D: 56 };` —— **有节点才对**。
- **✅ 结构性修法（让 bug 从根上不可能复现）**：
  - 内容层（正文 / 菜单）**恒定 scale 1 / translate 0 / 零旋转**，与变换彻底解耦；
  - 要「看起来像整页在动」，就**另起一层纯视觉层**：
    ```ts
    // 视觉层：满尺寸 + 自己承担几何动画 + 不吃交互
    Column()
      .width('100%').height('100%')
      .backgroundColor(this.paperColor)        // 与内容层同源底色 ⇒ 起手零跳变
      .opacity(this.paperOpacity)
      .rotate({ x: 0, y: 1, z: 0, angle: this.flipDeg, centerX: 0, centerY: '50%' })
      .animation({ duration: FLIP_DURATION_MS, curve: Curve.Friction })   // 纯属性动画
      .hitTestBehavior(HitTestMode.None)       // ← 关键：点击必须落到内容层
    ```
  - 效果：即使该动画**一帧都没跑**，退化为**视觉瑕疵**（一块纸面没翻走），
    **绝不是静默致瘫** —— 这是"结构性修法"与"调参数"的分水岭。
  - 官方 `BookFlipLongTakeTransition` 正是这么做的（变换挂封面 `Image`，**从不包裹内容子树**）。
- **⚠️ 纯视觉层的必备保险丝（连带的第二条）**：
  若该视觉层是**满屏不透明**的（如"铺满的纸面"），它的"播完/翻走"就是**内容重新可见的唯一动作**。
  一旦起手信号（布局回调 / 尺寸测量）不达 ⇒ **纸面永久盖住内容**（用户"什么都看不见"）。
  ⇒ 摆上该层时**同时挂一根兜底定时器**（`setTimeout(() => play(), FALLBACK_MS)`，
  `FALLBACK_MS` 取远大于正常信号延迟、又短到读不出卡顿的档，如 120ms），
  到点无条件执行；两条路径共用同一个**幂等**入口（`if (played) return`）。
  最坏情况由"永久遮挡"降级为"晚一拍翻走"。另在 `aboutToDisappear` 里 `clearTimeout`。
- ⚠️ **`@Builder` 调用不可链式加属性**：`this.flightCover(x).scale(...)` 不合法，
  属性必须写在 **builder 内部的根节点**上。
- ⚠️ **第三次复发（2026-10-02，见 LSN-034 A）**：删干净几何变换后**仍然点不动** ——
  根因换成了**包裹层**（对接 SDK 级重组件时，组件与页面根之间**每多一层容器都是一个独立变量**，
  不论它是否参与变换）。⇒ 两条铁律要**同时**满足：**零变换**（本条）+ **零包裹层**（LSN-034）。
  只做其中一条，症状会原样复发 —— 这正是「修了两次还点不动」的完整解释。
- **口诀**：**"改几何的修饰符不碰内容层；要动就另起一层，加 None 加保险丝"**
  （补充：**"对接 SDK 重组件时，包裹层本身也不能有 —— 视觉层也不行"**）

---

### LSN-033 `preferences` 的 string 上限 = **8192 字节** ⇒ 图片/长文本必须落沙箱文件

- **场景**：2026-10-02 Icey-Reader。用户报「**自定义壁纸好像失效了**」。
- **⚠️ 死因是官方硬约束，不是概率问题**：
  > **`preferences` 的 Value 为 string 时长度不得超过 8192 字节**（UTF-8）
  > 超长 `putSync` 直接抛 `Parameter error. The type of 'value' must be ValueType.`

  而上一个实现把 **720w JPEG 的 base64 data URI** 直接 `putSync`：
  `720w JPEG q80 ≈ 30~80 KB` → base64 膨胀 4/3 ⇒ **40~110 K 字符** ⇒ **必然超限**。
- **⚠️ 极具欺骗性的表现（这是最坑的地方，别去翻显示链路）**：
  | 时刻 | 现象 |
  |---|---|
  | 选完图**当次运行** | 内存态 + AppStorage 有值 ⇒ **壁纸显示完全正常**（"看起来能用"） |
  | **重进 App** | `getSync` 读回空串 ⇒ 槽位空 ⇒ **壁纸消失** |

  ⇒ 排查「X 失效 / 重启就没了」时，**第一步先确认值到底有没有存下来**（读回 + 看日志有没有
  `putSync failed`），而不是去逐文件对比渲染层 —— 渲染层往往一点没坏。
- **✅ 修法**：图片字节落**沙箱文件**，`preferences` 只留一行 `file://` URI（≈120 字节）。
  ```ts
  // 写：<filesDir>/bg/wallpaper_<slot>.jpg
  const data: ArrayBuffer = await packer.packing(pm, { format: 'image/jpeg', quality: 80 });
  // ⚠️ 必须带 TRUNC：新图比旧图小则不截断，会把上一次的尾部字节留在文件里 ⇒ JPEG 尾部垃圾
  out = fileIo.openSync(filePath,
    fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
  fileIo.writeSync(out.fd, data);
  // 存：官方 API，别手拼 'file://' + path（含空格/中文路径不稳，也不符合 file://bundleName/path）
  const displayUri = fileUri.getUriFromPath(filePath);
  ```
  显示侧**零改动** —— `Image()` 与 `image.createImageSource()` 都直接吃 `file://` URI。
  ⇒ 不需要 `FilePermission` 持久化，也不需要 `onForeground` 重新 activate（沙箱文件无外部权限依赖）。
  清除时**先删文件、再清槽位**（顺序反了就只能靠约定路径兜底）。
- **✅ 并加显式长度预检**（让这类问题不再静默）：
  ```ts
  if (typeof value === 'string' && value.length > MAX_PREF_STRING_BYTES /* 8192 */) {
    AppLogger.error('SettingsManager',
      `save(${key}) 值过长被拒：${value.length} 字符 —— preferences 放不下，应改落沙箱文件后只存路径`);
    return;   // 写不进去的东西再 flush 也没用
  }
  ```
- **铁律**：`preferences` 只放**轻量标量** —— 开关 / 档位 / 短字符串 / 路径 / `file://` URI。
  **图片、长 JSON、二进制一律落沙箱文件**，只存路径。
- ⚠️ **换实现时的代价要说清**：旧链路的字节在 catch 分支里就被丢弃了 ⇒
  修复**无法恢复用户已设的那张图**，需让用户**重新选一次**（此后永久有效）。
- **口诀**：**"preferences 只放标量，图长二进一律落文件"**

---

### LSN-034 SDK 级组件「点不动」的第三类根因 = **包裹层**；以及「无限 loading」的三条机制

> 来源：2026-10-02 Icey-Reader 第十一轮。用户原话：
> 「**还是点不动阅读页 我怀疑是不是全屏的问题导致的？要不还原下 然后就是 如果我短时间多次返回进入
> 会出现一致显示正在排版的问题 请优化**」

#### A. 「点不动」第三次复发 ⇒ 根因换成了**包裹层**（与 LSN-032 并列的第三条）

- **排错的第一步是排除法，不是继续加保护层**：
  | 假设 | 判据 | 结论 |
  |---|---|---|
  | 窗口级全屏导致 | `git show HEAD:` 里 `setWindowLayoutFullScreen(true)` + `SafeArea.set(...)` **本来就存在** | ❌ 排除（HEAD 时可交互） |
  | 几何变换（LSN-032） | 已删干净，仍点不动 | ❌ 排除 |
  | **包裹层** | HEAD 的结构是「组件**直挂**页面根 Stack」，改动后变成「组件 ← 容器 ← 自定义组件 ← 页面根」 | ✅ **真根因** |

- **判据来源（写在项目里的对照实验结论，比任何推理都硬）**：
  > SDK 的内部视图控制器（`readKitViewController`）**只在「系统组件直挂真·路由页的页面根 Stack」**
  > 这种形态下可靠建立；放进 `NavDestination` → `readKitViewController is empty` → 整页白屏。
  > 「刻意不套 `Navigation`，是为了**不重新引入『被包裹』这个变量**」。

  ⇒ **推广成通用判据**：对接 SDK 级重组件（Reader Kit / Map / Camera / 各种 XComponent 类）时，
  组件与页面根之间**每多一层容器都是一个独立变量**，且**不论该层是否参与几何变换**
  （LSN-032 只管"变换"，本条管"层数"，两者会叠加成同一个症状 ⇒ 修了变换仍复发）。

- **✅ 修法（用户口径「还原下」= 回到 HEAD 形态，而不是继续加层）**：
  1. 内核 `build()` 一律 **`this.pageRoot()` 直挂**，删掉一切中间容器 / 自定义组件；
  2. 需要状态栏避让时，**不给组件本体加 `padding`**（真机实证：padding 会让 SDK 的仿真翻页动画
     在**组件内容盒内**合成，padding 区成硬裁切线、动画上下被裁切）
     ⇒ 用 **`组件自身 height + 顶部 margin`**：
     ```ts
     ReadPageComponent({ ... })
       .height(this.textH())            // '100% - <safeTop>vp'
       .margin({ top: this.safeTop })   // ⚠️ margin 不计入自身高 ⇒ 真实高仍 == 上报 SDK 的 viewPortHeight
     ```
     两者**严格同源**（都是 `viewH - safeTop`），否则表现为「最后一行显示不全」；
  3. 配 `Stack({ alignContent: Alignment.Top })`：默认 `Center` 会先垂直居中**再**被 margin 推下 ⇒ 底部溢出半屏；
  4. `safeTop` 首帧为 0 属**安全方向**（只是暂时偏上，不裁内容），且它只 `0 → 真值`、不回退
     （反方向才会"底部被切"）。

- **⚠️ 撤掉视觉层后的必然收尾（容易漏）**：那种「一镜到底 / 飞行层」通常由**中继静态类 + 起手/消费两个端点**组成，
  撤掉消费端点（组件）后，**起手端点还在写、另一个端点还在读**（如用它决定「是否关掉整页转场」）
  ⇒ 变成「起了手但没人播动画 → 转场被关掉 → **硬切**」，比不做还差。
  ⇒ 撤销必须**整条链路一起做**：调用点 + 判定点 + 中继文件 + 消费者组件，并用 `grep` 复核零引用后再删文件。
  ⇒ 同时**核验"同名但不同机制"的另一个 id**别误删：本项目里 `heroIdOf`（`geometryTransition` 配对 id，
  服务「书架→详情页」的**独立** hero，保留）与 `heroNodeIdOf`（组件 `.id()`，仅供 `getRectangleById`，
  随通道撤除）是两回事 —— **删除前先 grep 出两条 id 各自的使用点逐个判定**。

#### B. 「快速多次返回进入 → 永远显示正在排版」= 三条机制叠加

| # | 机制 | 为什么 |
|---|---|---|
| 1 | **释放被延迟到转场之后 ⇒ 释放掉了新会话** | 退出时把 `release()` 排进 `setTimeout(..., 转场时长+60)`。而**SDK 控制器在新旧会话之间是同一个实例**（进程/组件级，非页面私有）⇒ 用户 ~50ms 内重进、新会话已 `start()`，旧页面在 T+420ms 才执行 `releaseBook()` ⇒ **从外部释放掉新会话** ⇒ `pageShow` 永不回调 ⇒ 无限 loading |
| 2 | **`on(type, cb)` 是追加语义** | 重试 / 重进每次都 `on` ⇒ 叠加 N 层回调（处理函数跑 N 遍：重复计数、重复落盘、重复 load，**完全不报错**）|
| 3 | **loading 只靠外部事件收起** | `pageShow` 是**外部事件**，可能永不到达 ⇒ 无超时出路就是永久 loading |

- **✅ 修法**：
  1. `release()` **立即执行**（释放 native 资源**不是耗时操作**，留在延迟批次换不来任何流畅度收益，
     却制造真实竞态）；延迟批次只留**真正耗时的**（全库 JSON 序列化落盘 / 跨进程窗口调用 / 统计结账）；
  2. 注册即替换 —— **先 `off(type)` 再 `on`**（官方 `off(type)` 省略 callback = 注销该类型**全部**回调）；
  3. 加「等外部事件」**看门狗**，与「等组件挂载」看门狗**分开计时**：
     | 门 | 管什么 | 档位 |
     |---|---|---|
     | `readyWatchdog` | 组件挂载前（回调不来） | 8s |
     | `pageWatchdog` | `startPlay` 成功后的**外部**事件 | 6s（明显大于正常耗时、又短于前者）|
     超时**强制收起 loading + 渲染可见错误态（带重试）**，绝不留在无限转圈；
  4. 入口加**防重入守卫**（已启动过则先释放再重启），回调处理器加 `disposed` 守卫
     （SDK 持有的注册可能在页面销毁后仍触发一次 ⇒ 会对已销毁组件写 `@State`）。

- **口诀**：**"SDK 重组件直挂根，多一层就是变量；释放立刻、注册替换、等外部事件必须看门狗"**

---

### LSN-035 共享元素（`geometryTransition`）的**三个成对约束**：视觉同源 / 两端都绑 / 抽组件要补绑

- **场景**：2026-10-03 Icey-Reader。用户要求「**列表的封面和到处的详情之类的封面实现效果要统一
  （非自定义 默认绘制的情况下）**」⇒ 把「无封面书的默认绘制」从两套实现（书架的实体书封
  `@Builder` vs 详情页/弹窗的灰褐渐变色块）收敛成一个 `@Component BookCover`。

- **⚠️ 约束 1：两端必须"视觉同源"，否则插值必断层**
  官方明文：*"源组件和目标组件应尽量使用相似的样式，否则系统生成的过渡动画会出现视觉断层"*。
  本工程的**旧做法是"反向妥协"**——因为两端本来就不同源，所以干脆**两端都不绑**
  （`hasCover(b) ? heroIdOf(url) : ''`）。★ 这条"为了不断层而放弃动画"的取舍**本身是错的信号**：
  它说明默认绘制该统一了。统一后这条分流**必须整体删除**（两端恒绑）。

- **⚠️ 约束 2：`@Builder` 调用挂不了属性 ⇒ 用 `@Builder` 画封面时那一支**根本没绑 hero**
  ```ts
  // ❌ 旧：无封面分支调 @Builder，无法链式挂 geometryTransition
  } else {
    this.plainBookCover(b)
  }
  ```
  **抽成 `@Component` 后**，必须**再外包一层 `Stack`** 才能挂属性；若漏掉 ⇒ 详情页单边绑定
  ⇒ 一个 id 只绑一个组件 ⇒ 系统找不到配对对象；而 `pop(false)` 已关掉系统转场 ⇒
  **返回直接硬切**（比不做 hero 更差）。★ **判据**：grep 两端 `geometryTransition`，
  数一数"有封面 / 无封面"两个分支各自的绑定点 —— **每个分支都要有，缺一支就是单边**。

- **⚠️ 约束 3：hero 的 `@Builder` 层要"只含共享元素本身"**
  宫格外层 `Stack` 里还叠着书脊 / 页缘 / scrim / 书名信息层 ⇒ **不能**把 hero 挂外层
  （会把书名文字一起"搬"到目标页，读作断层）。外包的那层 Stack **只放默认书封**。

- **⚠️ 配套：置位（`heroBackArmed`）与两端绑定条件必须同一口径**
  返回方向若由"置位 + `pop()` 内统一消费"实现，则该置位条件**必须与两端 `geometryTransition`
  的绑定条件严格一致**（本轮同步改为"恒 true"）。不同源 ⇒ 单边注册 ⇒ 静默不播放 + 硬切。

- **口诀**：**"两端不同源就先统一绘制，别用'不绑'来遮断层；抽了组件记得补绑 —— 每个分支都要有"**

---

### LSN-039 共享元素「一镜到底」**禁止与 `bindContentCover` 混用** —— 唯一正确形态是路由页 push/pop

- **场景**：2026-10-12 BiliDownload-Harmony。图片全屏预览用「缩略图 → 全屏」的
  `geometryTransition` 共享元素转场，容器却是 `bindContentCover` 全屏覆盖层。
  **症状固定为**「关闭时黑底连图片一起瞬间消失，看不到图片飞回」——
  反复调 `modalTransition: NONE` / `transition: IDENTITY` / 黑底两段式淡出 /
  给覆盖层显式透明背景，**七八版都修不动**。

- **★ 根因（一句话）**：`bindContentCover` 一收起就**立刻拆掉整棵覆盖层子树** ⇒
  共享元素的"目标侧"在转场一开始就没了 ⇒ **没有回程可飞**。
  这不是参数问题，是**两种机制的结构冲突**。

- **★ 判据（先数官方示例，别先调参数）**：去官方 `transitions-collection`
  （DevEco 示例合集「实现转场动效功能合集」）里各数一遍：
  ```bash
  B=<transitions-collection>/entry/src/main/ets
  grep -rn "geometryTransition" --include=*.ets "$B" | wc -l   # → 6，全在 push/pop 场景
  grep -rn "bindContentCover"  --include=*.ets "$B"            # → 2 处，**没有任何一处**配 geometryTransition
  ```
  ⇒ **官方从来不混用**。`geometryTransition` 的正确容器只有一种：
  **`Navigation` 的 push/pop**（`NavDestination` 页面）。

- **✅ 正确形态**（逐行照抄 `ImageLongTakeTransition/ShowLargeImageWithGesture`）

  **① 预览层 = 一条真正的路由页**（不是覆盖层）
  ```ts
  @Component
  export struct CoverPreviewDestination {
    private pathStack: NavPathStack = new NavPathStack();
    @State url: string = '';
    @State geometryId: string = '';

    private popPreview(): void {   // 关闭：必须在 animateTo 里 pop
      this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseIn }, () => {
        this.pathStack.pop(false);          // ← false = 不要系统转场
      });
    }

    build() {
      NavDestination() {
        CoverPreview({ url: this.url, geometryId: this.geometryId,
                       onRequestClose: () => { this.popPreview(); } })
      }
      .hideTitleBar(true)
      .mode(NavDestinationMode.DIALOG)      // ← 全屏态
      .transition(TransitionEffect.opacity(0.99))
      .onBackPressed(() => { this.popPreview(); return true; })
      .onReady((ctx: NavDestinationContext) => {
        this.pathStack = ctx.pathStack;
        const p = ctx.pathInfo?.param as Record<string, Object> | undefined;
        if (p === undefined) return;
        this.url = p['url'] as string;      // ⚠️ 逐字段重建（ArkTS 禁整对象 as）
        this.geometryId = p['geometryId'] as string;
      })
    }
  }
  ```

  **② 注册在路由分发器里**（`Index.navDestinationBuilder`）——
  ⚠️⚠️ **绝不能把它当普通子节点挂在页面树上**：`NavDestination` 一旦脱离 push/pop
  会**立即渲染**（实测：首页就出现了预览层的「保存至图库」按钮）。
  ```ts
  } else if (name === ROUTE_COVER_PREVIEW) {
    CoverPreviewDestination()      // ← 由 push 触发时才开始渲染
  }
  ```

  **③ 源页打开 / 关闭 —— 全部发生在 `animateTo` 里**（官方 `PageOne` / `PageTwo`）
  ```ts
  // 打开
  private openCoverPreview(): void {
    this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseIn }, () => {
      this.coverPreviewOn = true;                       // 源侧缩略图让位（见下）
      this.pathStack.pushPath({ name: ROUTE, param: p }, false);   // false = 不要系统转场
    });
  }

  // 关闭（由预览页回调）—— **同一个 animateTo 里"复位让位标志 + pop"**
  private closeCoverPreview(): void {
    this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseIn }, () => {
      this.coverPreviewOn = false;                      // 缩略图回到树上，才有"回程落点"
      this.pathStack.pop(false);
    });
  }
  ```

  **④ 源侧缩略图必须"让位"**（官方 `isFirstPageShow = false`）：
  打开时把缩略图隐去、关闭时恢复，**否则"源"与"目标"同时在场，共享元素不知道跟谁**：
  ```ts
  .opacity(this.coverReady && !this.coverPreviewOn ? 1 : 0)
  ```
  ⚠️ 让位标志要**每个缩略图一个**（封面 / 头像各一个）——共用一个的话，
  「点封面」会把头像也一起隐掉。

  **⑤ 两侧 `transition` 取值是反的**（官方 `MyComponent` vs `PageOne`）：
  | 侧 | 值 |
  | --- | --- |
  | **源侧缩略图** | `TransitionEffect.opacity(0.99)`（恒近不透明，把视觉让给共享元素） |
  | **目标侧大图** | `TransitionEffect.OPACITY`（真淡入淡出，与黑底同一条时间线） |
  | 目标侧容器（`NavDestination`） | `TransitionEffect.opacity(0.99)` |
  抄反 ⇒ 收起时目标侧不淡出 ⇒ 读作"被一起清掉"。

- **⚠️ 关闭回调要走"登记"而非"预览页自己 pop"**：预览页不知道"谁是源页、该复位哪个标志"。
  开预览前由**源页**把自己的关闭方法登记到一个静态宿主（`PreviewHost.setCloser`），
  预览页的**任意**关闭路径（关闭钮 / 返回键 / 手势）统一回调它；
  源页 `aboutToDisappear` 里 `clearCloser()` 防止回调打到已销毁的组件上。

- **口诀**：**"几何转场只跟 push/pop 走；覆盖层收起会拆树 —— 数官方示例，别调参数"**

---

### LSN-038 给 SDK 高级组件传「变长数组」当参数 ⇒ P0 真机闪退（2026-10-07 Icey-Player-Harmony）

- **场景**：用 `SegmentButton` 做详情页的「歌曲 / 专辑」分段切换。为了让"2 项 / 3 项"
  共用一份构造代码，写成"先组装数组、补齐到 4 个元素、短位填 `undefined`"：
  ```ts
  const b2 = buttons.length > 2 ? buttons[2] : undefined;   // ← 2 段时是 undefined
  return SegmentButtonOptions.tab({ buttons: [b0, b1, b2, b3] });   // 编译通过
  ```
  ⇒ **点进详情页直接闪退**（进程被杀）。

- **★ 真机堆栈（锁死根因，非猜测）**：
  ```
  Reason:TypeError
  Error message:Cannot read property icon of undefined
    at SegmentButtonItemOptions (segmentbutton.js:283)
    at SegmentButtonItemOptionsArray (segmentbutton.js:302)
    at SegmentButtonOptions (segmentbutton.js:417)
    at tab (segmentbutton.js:455)
    at buildOptions entry (entry/.../SegmentTabs.ets:90)
  ```

- **★ 机理（可迁移）**：`CommonSegmentButtonOptions.buttons` 的类型是
  **`SegmentButtonItemTuple` = 定长元组**：
  ```ts
  declare type ItemRestriction<T> = [T, T, T?, T?, T?];   // SDK d.ts:712
  ```
  段数只能 **2~5**，**必须按实际个数构造元组**。SDK 内部 `SegmentButtonItemOptionsArray`
  会**逐元素访问字段**（这里是 `item.icon`，为兼容 icon 型 / icon+text 型统一读）
  ⇒ 数组里出现 `undefined` 就抛 `TypeError` ⇒ `Kill Reason:Js Error` ⇒ 应用被杀。

- **正解**：**按段数分派**，各分支写**长度精确匹配**的元组字面量：
  ```ts
  if (b.length === 3) return SegmentTabs.buildOptions3(b[0], b[1], b[2]);
  if (b.length === 4) return SegmentTabs.buildOptions4(b[0], b[1], b[2], b[3]);
  // buildOptions3 内：buttons: [a, b, c],
  ```
  ⚠️ **别写 `as SegmentButtonItemTuple`**：那是三路联合类型
  （`ItemRestriction<Text> | ItemRestriction<Icon> | ItemRestriction<IconText>`），
  断言后反而报 `Type 'SegmentButtonItemTuple' is not assignable to type
  'ItemRestriction<SegmentButtonTextItem>'`。**直接传元组字面量**，ArkTS 自会选支。

- **⚠️⚠️ 三条「编译绿但真机错」的姊妹坑（同一个组件，一起记）**：
  | 写法 | 结果 |
  |---|---|
  | `buttons` 传变长数组（含 `undefined`） | **真机闪退**（本条的坑），编译器**不报** |
  | `.height(43)` / `.width()` / `.margin()` 写在 `SegmentButton` 上 | **静默无效**（SDK 原文 "does not support universal attributes"） |
  | `onItemClicked` / `enableStateAnimation` 链式点调用 | **编译错** `Property 'xxx' does not exist on type 'void'`（它们是**构造参数**） |
  | 想调高度 | 唯一旋钮 = `buttonPadding`；圆角要与高度配套（药丸半径 = 药丸高/2 + 0.5，否则读作"圆头方块"） |

- **★ 通用判据**：**看到 SDK 类型里 `T?` 结尾的元组（`[T, T, T?, T?, T?]`）就要警觉** ——
  它的语义是"最多 5 个、但**必须按实际个数**给"。传变长数组 + 占位 = 真机崩。
  ⇒ **「能编译过」对 SDK 高级组件的「结构约束」没有说明力**（只对类型约束有效）：
  断言能绕开长度校验、通用属性选了不存在的旋钮也不报错、内部字段读取更是编译期不可见。
  **这类组件必须真机跑一次目标路径**，别拿「编译绿」当验证。

- **口诀**：**"定长元组按个数给，别补 undefined；SDK 高级组件不支持通用属性，别把它当普通容器调"**

---

### LSN-037 多级设置页的卡片间距/内边距必须「一套组件一个口径」；分档即泄漏（2026-10-06 Icey-Player-Harmony）

- **场景**：用户连着报两轮 —— ① 「设置页和子页的两张卡片之间的间距是不是不统一？」
  ② 「卡片的内边距应该也是不统一吧？同样以设置页的为准」。本工程有两套分组卡片组件：
  `SettingsGroup`（设置主页专用，项带图标）与 `SettingsGroupCard`（7 个子页共用，项无图标）。

- **★ 判据（可迁移）**：**「不统一」类反馈要拆成两类，不要一刀切**——
  - **必须严格一致**：卡间距、卡片内边距、圆角、阴影/材质档位。这些是**跨页面同一视觉语言**。
  - **允许不同**：任何「**对齐自己那一侧内容**」的缩进/缩进类值。
    本例中 Divider 左缩进 主页 52 / 子页 12 **是正确的**（项带 32vp 图标 vs 无图标），
    把它一起「统一」反而会让分割线跟文字列错位。**改之前先问「这个数值在跟什么对齐」。**

- **两个真实缺口（都是「单看合理」型）**：
  | 项 | 主页（基准） | 子页（原） | 症状 |
  |---|---|---|---|
  | 卡间距 | `margin({bottom:16})` | 原 `margin({left:16,right:16,top:12})` | 子页实际间距 12 ⇒ 整体更紧 |
  | 卡片内边距 | 恒定 `6/6/1/1` | **按有无标题分档**：有标题 `3/3`、无标题 `6/6` | 带标题的卡上下比主页窄 3vp |

  ⚠️ **两个坑的形态不同**：
  - 卡间距那个是「**缺一个维度**」型（子页无 bottom ⇒ 全靠下一张卡的 top 隔开）——
    **子页卡片若既无 `margin.bottom` 又把 `top` 写小于主页，永远比主页紧**。这类缺口只在两页对比时才显形。
  - 内边距那个是「**聪明过头**」型：当初为「有标题时少留白更紧凑」分档，
    实际 3vp 恰好落在**肉眼可辨**的量级（< 2vp 不可辨，> 4vp 明显）。
    **教训：给同一个视觉元素做「按场景微调」前，先算这个差值能不能被看见；能看见就不该分档。**

- **正解**：
  ```ts
  // SettingsGroupCard —— 取消分档，一律与主页看齐
  .margin({ left: 16, right: 16, top: 16 })
  .padding({ top: 6, bottom: 6, left: 1, right: 1 })
  // Divider 保持本组件自己的 12（对齐无图标的文字列），不跟主页的 52 统一
  ```
  ⚠️ **改前先确认没有覆写**：本例 7 个子页共用该组件且无覆写 ⇒ **一处改全生效**；
  但若某页自己传了 `margin/padding`，改组件不会生效，**必须 grep 消费点数一遍**。

- **⚠️ 排查姿势（通用）**：用户说「看起来不统一」而页面里搜不到这些数值时，
  **它们全封在组件里** ⇒ `grep -rn "<组件名>" --include=*.ets` 列出定义与消费点，
  对比两个同类组件的 `margin` / `padding` / Divider 三处。差异通常就是 1 个数字，
  且**必须在组件里改，页面里改无效或只改一处**。

- **口诀**：**"跨页同一视觉语言必须同口径；对齐自己那侧内容的缩进允许不同；给同一元素分档前先算差值能不能被看见"**

---

### LSN-036 「空集合不可表达」⇒ 那个功能必然是假的；破局靠给它一个持久化落点（2026-10-03 Icey-Reader）

- **场景**：用户要求「加一个分组的页面 里面可以管理和**新增**」。旧实现在弹窗里只有「重命名 / 解散」，
  且**刻意写了注释"不做新建空分组"** —— 因为分组只是**书的字符串字段**（没有独立表），
  `groupNames()` 只能从现存书里收集 ⇒ **空分组根本不可表达**，新建出来的组重启即消失。

- **★ 判据（可迁移）**：**当一个功能"实现不了"时，先问它的数据模型能不能表达这个状态。**
  - 能新建但存不住 ⇒ 假功能；能存但没有独立落点 ⇒ 下次启动丢。
  - 「刻意不做」的那条注释往往**不是偷懒，是当时的数据模型不支持** —— 读到这种注释要警觉。

- **破局**：给"只有名字、没有内容"的集合一个**显式持久化落点**：
  ```ts
  private static emptyGroups: string[] = [];              // 空分组名清单
  const KEY_EMPTY_GROUPS = 'groups_json';                 // 与书库同一个 preferences 文件
  ```
  `groupNames()` / `countInGroup()` / `renameGroup()` / `deleteGroup()` **全部纳入这个集合**：

- **⚠️ 四条必须成套改（漏一条就语义不自洽）**
  1. **读取合并去重**（先建空组、再往组里放书 ⇒ 两边都有该名）；
  2. **改名要连带改空组名** —— 否则改完名字，那个 0 本的组会"复活"成旧名；
  3. **解散要连带清登记** —— 不清的话组名仍在 `groupNames()` 里，用户看到的解散是**没生效**的；
  4. **落盘与主数据同一次 flush** —— 分开写会出现「书落盘了、空组没落盘」的中间态（重启后分组忽隐忽现）。
     ```ts
     await pref.put(KEY_BOOKS, ...);
     await pref.put(KEY_EMPTY_GROUPS, ...);   // 同一份"分组视图"的两半
     await pref.flush();
     ```

- **⚠️「0 成员的组」不该弹确认框**：确认文案写的是"N 本书将移到「未分组」"，N=0 时**自相矛盾**，
  且操作本身无破坏性 ⇒ 直接删 + toast。（生成确认文案前先算 N，为 0 就走另一条路。）

- **⚠️ 静态类的集合变更不响应 UI**：`BookRepo.groupNames()` 是**普通 function**，改完不触发重渲染。
  自增一个 `@State version`（`this.version++`）驱动重建 —— 与项目既有的"版本号信号 ≠ 布尔状态"（LSN-008）同源。

- **口诀**：**"状态存不住就是假功能；先给集合找落点，再把读/改/删/flush 四处一起接上"**

---

## 7. 自查清单

### 动手前（每次改动）
- [ ] 已定位模板/工程真实路径并验证存在（§0）
- [ ] 已读 `Index.ets` + 目标文件全貌，而非凭记忆改
- [ ] 已 grep 同模式引用，明确改动范围边界
- [ ] 方案已向用户描述（改哪个文件 / 哪一处 / 改成什么 / **不动什么**），模糊指令不脑补

### 写完后
- [ ] 前台串行构建通过（禁止并行；hvigor safe-delete → 清 `CompileArkTS` 缓存）
- [ ] 真机跑一遍 + hilog 看对应 TAG
- [ ] 走一遍 §2 铁律表中与本次改动相关的条目
- [ ] 新增文件中所有硬编码尺寸/颜色是否替换成 `ThemeManager.colors` / `SafeArea.*`

### 提交通道前
- [ ] 版本号如需更新：同步 `AppScope/app.json5`（versionCode/versionName）+ `rawfile/changelog.txt`
- [ ] `ChangelogManager` 靠 versionCode 判「每次更新弹一次」——**改了日志别忘了 versionCode +1**
- [ ] 若基于模板发布了新版本，回头更新本 Skill：LSN / 坑点速查表 / version + changelog

---

## 附录 A：AppStorage 全局键表

| 键 | 类型 | 写入方 | 读取方 | 语义 |
|---|---|---|---|---|
| `safeAreaTop/Bottom/Left/Right` | number | EntryAbility → `SafeArea.set` | 所有页面 | 全屏后的系统区高度（vp） |
| `windowWidth/windowHeight` | number | App.ets 窗口监听 | 一多布局、SheetContainer | 窗口 vp 尺寸 |
| `windowIsLandscape` | boolean | App.ets | SheetContainer 限高 | 横竖屏（布尔单独广播，避免宽高 set 竞态） |
| `themeIsDark` | boolean | ThemeManager.bumpVersion | 任意 | 当前是否深色 |
| `themeColorsVersion` | number | ThemeManager.bumpVersion | **全部颜色消费者** | 版本号，+1 触发重建 |
| `dataLoaded` | boolean | EntryAbility.startupReady | 列表页 | 数据恢复完成标记（防启动闪空态） |
| `appInBackground` | boolean | Ability onBackground/onForeground | 动画/轮询 | **状态**（true=在后台） |
| `appBackgrounded` | number | Ability onBackground | AppSheet | **事件版本号**，只增不减 |
| `settings_*` | any | SettingsManager.fillAppStorage | UI `@StorageLink` | 持久化设置的 UI 镜像 |
| `settings_customBgUri` | string | （主项目背景模块） | GlassCard/SettingsGroup/Scaffold | 有无自定义背景 → 毛玻璃 or 实色 |
| `sheetReopen` | number | 外部 | AppSheet | 强制弹窗先关再开（被系统 picker 顶掉时） |

## 附录 B：目录结构

### B1. Skill 自身（可移植，整体拷走即可在其它机器使用）

```
harmony-app-template/
├── SKILL.md                         # 主文件（铁律/工作流/坑点/LSN）
├── references/
│   ├── workflows.md                 # W1~W8 可复制代码
│   └── file-map.md                  # 文件职责全图 + AppStorage 键表
└── assets/
    ├── TEMPLATE_MANIFEST.md         # 内置副本清单 / 排除项 / 同步约定
    └── template/                    # ★ 模板工程完整副本（79 文件 / 1.2MB）
        └── ...（结构见 B2）
```

### B2. 模板工程（= `../assets/template/`，复制出去后即新工程根）

```
HarmonyAppTemplate/
├── AppScope/app.json5                     # bundleName / versionCode / versionName / 图标 / 应用名
├── build-profile.json5                    # compatibleSdkVersion / targetSdkVersion（书写格式随 API 级别分界，见 LSN-021）
├── entry/
│   ├── build-profile.json5                # apiType: stageMode
│   ├── oh-package.json5
│   └── src/main/
│       ├── module.json5                   # 沉浸光感元数据、权限、Ability 配置
│       ├── resources/base/{element,media,profile}/
│       ├── resources/rawfile/changelog.txt
│       └── ets/
│           ├── App.ets                    # @Entry 根：窗口广播/主题初始化/返回手势
│           ├── entryAbility/EntryAbility.ets
│           ├── layout/Index.ets           # HdsNavigation + HdsTabs + 子页分发
│           ├── pages/{HomeTab,SettingsTab}.ets
│           ├── pages/subPages/{HomeDetailPage,SettingsSubPage,AboutPage}.ets
│           ├── model/{AppRouter,SafeArea,SettingsManager,ThemeManager,TitleBarStyles}.ets
│           ├── services/{AppGlobalContext,AppLogger,ChangelogManager,FilePermission,
│           │             FormatUtils,SheetManager,WindowHelper}.ets
│           └── components/                # 每个组件一个独立目录
```

## 附录 C：模板已知缺陷（v1.0.0 待修，动手前先确认是否已修）

> 以下为通读工程时实证发现的问题，**复用模板前建议先修**：

| # | 现象 | 位置 | 修法 |
|---|---|---|---|
| D1 | 编译失败：`'getInstance' does not exist` | `EntryAbility.ets` L43/69/89/197、`SettingsTab.ets` L76/96、`SettingsSubPage.ets` L43/58 | 要么给 SettingsManager 加 `getInstance()`，要么把 8 处调用改成静态直调（推荐后者，与 AppLogger/ChangelogManager 范式统一） |
| D2 | 编译失败：`Cannot find name 'WindowHelper'` | `EntryAbility.ets` L220 使用了 WindowHelper 但未 import | 加 `import { WindowHelper } from '../services/WindowHelper';` |
| D3 | handedness / materialLevel 重启回默认值 | `SettingsManager.init()` 只读了 exampleSwitch 与 themeMode | 补上两个 key 的 `getSync` 读回（见 LSN-003） |
| D4 | App 图标可能不显示 | `entry/src/main/resources/base/media/layered_image.json` 引用 `$media:background`/`$media:foreground`，但这两个 png 只存在于 `AppScope/resources/base/media/` | 把 png 复制到 entry 模块的 media 目录，或删除 entry 级 layered_image.json 让解析回落到 AppScope |
| **D5** | **构建直接失败（连编译都没进）**：`hvigor ERROR 00306042 Specification Limit Violation — the value of compileSdkVersion/compatibleSdkVersion/targetSdkVersion must be string, Example: '5.0.0(12)'` | `build-profile.json5` 的 `compatibleSdkVersion` / `targetSdkVersion` —— **版本号书写格式与本机 SDK 的 API 级别不匹配** | ⚠️ **本条已按 SDK 版本修正（2026-09-17）**：格式**按 API 级别分界**——<br>· **API < 26** → 旧式 `x.y.z(api)`，如 `"6.1.1(24)"`（此前模板值 `"26.0.0"` 缺后缀即报 00306042，**但那是因为当时 SDK 是 API 24**）<br>· **API ≥ 26** → **点分制纯数字三段式** `major.minor.patch`，如 `"26.0.0"`。此时补 `(26)` 后缀反而报 **00308018**「api version parameter is illegal」<br>**做法**：先 `cat <DevEco>/sdk/default/sdk-pkg.json` 读 `apiVersion` + `platformVersion`，再按上面分界选格式。本项目 SDK 已升级为 HarmonyOS 26.0.0 / API 26 → 用 `"26.0.0"`。详见 **LSN-020** |
| **D6** | 编译失败：`Cannot find name 'HdsNavigationTitleBarOptions'` + `'opts.content' is possibly 'undefined'` | `layout/Index.ets` 的 `private homeTitleBar(): HdsNavigationTitleBarOptions` —— 该类型只在 `TitleBarStyles.ets` 里 import 过；且 `content` 是可选字段 | ① Index.ets 补 `import { HdsNavigationTitleBarOptions } from '@kit.UIDesignKit';`；② 写 menu 前先取局部判空：`const content = opts.content; if (content !== undefined && ...) { content.menu = {...}; }` |
| **D7** | 编译失败：`10905210 In an '@Entry' decorated component, the 'build' method can have only one root node` + `10505001 Cannot find name 'bindSheet'`（报错点与真实元凶无关，极易误判） | `pages/subPages/AboutPage.ets`：`SubPageScaffold({...}) { ... }.bindSheet(...)` —— **自定义组件调用后不能链式挂属性**，尤其在其后还有尾随 lambda 时 | 把 `bindSheet` 移到内容里的**原生组件**（如 `List`）上：`SubPageScaffold({...}) { List(){...}.bindSheet(...) }`。这也天然满足铁律 #30（bindSheet 挂原生组件） |
| **D8** | 编译失败：`10905201 The 'Blank' component can only be nested in the 'Row,Column,Flex' parent component` | 模板各页 `ListItem() { Blank().height(...) }`（`HomeTab` / `SettingsTab` / `AboutPage` 的顶部与尾部留白） | 换成空 `Row` 占位：`ListItem() { Row() {}.height(SafeArea.top + 64).width('100%') }`（空容器写法与 `AppSheet` 里 `Stack() {}.width(1).height(1)` 同源） |
| **D9** | 静默失效：背景图变化时子页不重新淡入 / 弹窗退后台不自动关 | `SubPageScaffold.ets` 的 `@StorageLink('settings_customBgUri') @Watch(...)`、`AppSheet.ets` 的 `@StorageLink('appBackgrounded') @Watch(...)` 与 `@StorageLink('sheetReopen') @Watch(...)` —— **@Watch 写在状态装饰器之后** | 按 LSN-012 调换顺序：`@Watch('cb') @StorageLink('k') x`。模板自身就踩了这条，抄代码时务必一并改 |
| **D10** | **运行时**（编译通过、最容易漏）：启动恢复够快时列表页永久停在「加载中…」 | ① `App.ets` 的 `aboutToAppear` **无条件** `AppStorage.setOrCreate('dataLoaded', false)`；② `EntryAbility.ets` 的恢复链路用 `AppStorage.set('dataLoaded', true)`（键不存在时静默落空） | 两侧都改，缺一不可：① App 侧改为**仅在键不存在时**初始化；② EntryAbility 侧改用 `setOrCreate`。详见 **LSN-018** |
| **D11** | 观感问题（不报错、真机才看得出）：**弹窗卡片底边贴住手势条被压 / 横屏时左右被挖孔压** —— 用户表述为「弹窗的卡片边距不大对」 | 弹窗容器（如 `SheetContainer`）的卡片边距写成**死值** `margin({left:24,right:24,bottom:24})`，而页面内容普遍有 `SafeArea.bottom + 80` 尾部留白 ⇒ **弹窗卡片是全局唯一漏掉安全区的边距** | 卡片边距改为 **`24 + SafeArea.*`**（左右 + 上下底部），顶部保持 24（bindSheet 不在屏幕顶，加顶部安全区会把内容整体下推）。**连带两处必须同步**：① 标题行的横向 padding（与卡片左右缘对齐）；② 卡片外底栏的左右 padding（否则横屏与卡片错位）。`cardMaxHeight()` 的净空扣除本就含安全区，不用改。**这是 LSN-014「横向内缩只由卡片自身提供」的同族坑**：边距语义只在容器一处定义时，务必连安全区一起定义 |

> ⚠️ **结论：内置副本「原样复制 + 只修 D1~D4」仍然编不过。**
> v1.1.5 实测：完整跑通一次 `assembleHap` 至少需要修 **D1、D2、D5、D6、D7、D8**（6 项）。
> 建议新建项目后直接按本表从上到下全扫一遍再构建，避免"改一处、编一次"的来回。

## 附录 D：反馈通道

本 Skill 由 HarmonyAppTemplate 工程实践沉淀。使用中遇到：
- 模板里某条规则不适用 / 与实测不符
- 新增工作流希望加入 W 系列
- 发现新的平台坑点

→ 请直接反馈给工程维护者，并附：**做了什么 + 期望什么 + 实际得到什么 + 涉及文件路径**。
每次都要同步更新：本 Skill 的 `version` + `changelog` + LSN 库 + 坑点速查表。

---

## 版本历史

## ✅ 模板健康状态（2026-09-17 修复，assembleHap 全绿）

模板的 **23 个既有编译错误已全部修复**，当前 `assembleHap` 构建通过，可直接用模板源码起工程。
修复的错误模式本身就是高频真实坑，记录如下（全部机械可修）：
- `SettingsManager.getInstance()` ×8 —— 模板 SettingsManager 是**静态方法**风格，
  调用方却写成实例单例风格 → 改为直接类名静态调用
- `Blank()` 直接嵌在 List/Stack 中 ×7 —— **Blank 只能嵌在 Row/Column/Flex 内**；
  列表占位改 `Row() {}.height(...).width('100%')`（AssetTab 有现成写法）
- 缺 import ×4（`WindowHelper`；`HdsTabsBarChangeMode` / `HdsNavigationTitleBarOptions`
  ——后两者是 `@kit.UIDesignKit` **合法导出**，只是没写进 import 块）
- `.bindSheet(...)` 链在**自定义组件**上 ×1 —— bindSheet 是原生组件方法，
  包一层 `Stack` 把链挪到 Stack 上（`SubPageScaffold` 场景实证）
- `AboutPage` build 括号残缺 ×1；`opts.content` possibly undefined ×1（可选字段**先判空**再赋值）

**教训**：模板/工程每次大改后必须跑一次完整 `assembleHap` —— **资源错误（CompileResource）
在 ArkTS 编译之前**，资源坏了会掩盖后面所有错误；本次先修 `$media:tab_music` 才暴露出这 23 个。

---

| 版本 | 日期 | 变更 |
|------|------|------|
| **v1.3.12** | 2026-10-12 | 新增 **LSN-039**（**共享元素「一镜到底」禁止与 `bindContentCover` 混用 —— 唯一正确形态是路由页 push/pop**）+ 坑点速查表 +1 行。来源：BiliDownload-Harmony 图片全屏预览，`geometryTransition` 挂在 `bindContentCover` 覆盖层里，**症状固定为「关闭时黑底连图片一起瞬间消失、看不到飞回」**，反复调 `modalTransition: NONE` / `transition: IDENTITY` / 黑底两段式淡出 / 覆盖层显式透明背景，**七八版都修不动**。★ 根因 = **结构冲突**（覆盖层一收起就立刻拆掉整棵子树 ⇒ 共享元素目标侧没了 ⇒ 没有回程可飞），不是参数问题。★ 破局判据 = **去官方 `transitions-collection` 里各数一遍**：`geometryTransition` 6 处**全在 push/pop 场景**；`bindContentCover` 2 处、**没有任何一处**配几何转场 ⇒ 官方从来不混用。✅ 正解 = 预览层改成**真正的路由页**（`NavDestination` + `.mode(DIALOG)` + `.hideTitleBar(true)`，注册进 `navDestinationBuilder`；⚠️ **不可当普通子节点挂**，否则 `NavDestination` 脱离 push/pop 会**立即渲染**——实测首页就冒出了预览层的按钮）；开 = 源页 `animateTo({250,EaseIn}, pushPath(…, false))`、关 = `animateTo({300,EaseIn}, pop(false))`；源侧缩略图**打开时让位 / 关闭时在同一个 animateTo 里复位**（官方 `isFirstPageShow` 同义，否则「源与目标同时在场」共享元素不知道跟谁）；两侧 `transition` **取值相反**（源侧缩略图 `opacity(0.99)` / 目标侧大图 `OPACITY`）。附「关闭回调走静态登记（`PreviewHost.setCloser`）而非预览页自己 pop」的解法 |
| **v1.3.11** | 2026-10-07 | 新增铁律 **12** + **LSN-038**（**给 SDK 高级组件传「变长数组」当参数 ⇒ P0 真机闪退**）。来源：用 `SegmentButton` 做详情页分段切换，为让「2 项/3 项」共用一份构造代码，写成「补齐到 4 个元素 + 短位填 `undefined`」⇒ **点进详情页直接闪退**，真机堆栈锁死：`TypeError: Cannot read property icon of undefined` @ `segmentbutton.js:283 SegmentButtonItemOptions`。机理：`buttons` 是 **`SegmentButtonItemTuple` = 定长元组**（`ItemRestriction<T> = [T, T, T?, T?, T?]`，SDK d.ts:712），段数只能 2~5 且**必须按实际个数构造**；SDK 内部 `SegmentButtonItemOptionsArray` **逐元素读字段**（`item.icon`）⇒ 遇 `undefined` 即抛。正解 = 按段数分派到 `buildOptions2/3/4/5`（各写长度精确匹配的元组字面量）；⚠️ **别写 `as SegmentButtonItemTuple`**（三路联合类型，断言反而报 `not assignable`）。★ 通用判据：**看到 `T?` 结尾的元组就要警觉 —— 「能编译过」对 SDK 高级组件的结构约束没有说明力**；同组件的兄弟坑一并收录（不支持通用属性、`onItemClicked` 是构造参数、高度唯一旋钮 `buttonPadding`）。坑点速查表 +1 行 |
| **v1.3.10** | 2026-10-06 | 新增铁律 **11** + **LSN-037**（**多级设置页的卡片间距/内边距必须一套组件一个口径**）。来源：用户连报两轮「设置页和子页的卡片间距不统一」「内边距也不统一，以设置页的为准」。两个缺口形态不同：**卡间距** = 子页卡片无 `margin.bottom`、全靠下一张卡的 `top` 隔开，而那个 `top` 比主页小 ⇒ 永远更紧；**内边距** = 子页组件按「有无标题」分了档（有标题 3/3、无标题 6/6）⇒ 带标题的卡上下窄 **3vp**，恰在肉眼可辨量级。判据要点：**必须严格一致的是「跨页同一视觉语言」（间距/内边距/圆角/材质档位）；允许不同的是「对齐自己那一侧内容」的缩进** —— 本例 Divider 左缩进主页 52（项带 32vp 图标）vs 子页 12（无图标）**是正确的**，一起统一反而错位。⚠️ **给同一元素做「按场景微调」前先算差值能不能被看见**（<2vp 不可辨、>4vp 明显 ⇒ 不该分档）。⚠️ 排查姿势：数值封在组件里 ⇒ `grep -rn "<组件名>" --include=*.ets` 下钻对比 `margin/padding/Divider`，并先确认没有页面覆写。坑点速查表 +1 行 |
| **v1.3.9** | 2026-09-30 | 新增 **LSN-031**（**Canvas 自绘正文「长按划选」+ 功能面横向铺开**）。来源：Icey-Reader 用户要求「照着 legado 把该做的功能都做了」——阅读页**一轮补齐** 书签 / 笔记 / 划选 / 书内搜索 / 阅读统计 / 书架分组 / 排版扩展，全部**用鸿蒙特性（沉浸光感 / 符号 / 系统组件）**实现。核心坑五条：<br>① **Canvas 字符命中**（最易写错）：**禁比例估下标**，走**三层收敛** —— `localX/px2vp − 页边距` ⇒ 页内容区；按行 y 区间定位行（`行高 = 字号 × lineSpacing`，**标题行字号 +2**）；行内找**最后一个左缘 ≤ cx** 的字形、过其右缘中点 +1 ⇒ 章内偏移 `line.charStart + idx`。★ **排版期必须存每行 `charStart`**，交互期无法反推。<br>② **划选与翻页同一手势分流**：复用既有 `PanGesture`（`selecting` 态改作 `extendSelect`，否则翻页），❌ 不要新增第二个 Pan / 手势组（会争抢成"想选字却翻页"）；进入划选用 `LongPressGesture({repeat:false,duration:400})`，退出后**直接 return 不再触发翻页**。<br>③ **划选底衬逐行画**：选中区间是**章内偏移**、绘制在**当前页**坐标系 ⇒ 求行 ∩ 区间的交集后逐行 `fillRect`（accent alpha≈0.22，叠在文字之下）；直接拿 `selStart/selEnd` 当 x/y 会跑到页外。<br>④ **跨页返回先问 `has`**：管理页可能从**书架→详情页**进入，栈里没有阅读页 ⇒ 一律 `pop()` 退到错页；正解 `AppRouter.has(ROUTE_READER) ? pop() : push(ROUTE_READER, bookUrl)`。多个入口**共用一条 `@StorageLink` 信号**，`@Watch` 消费后**立即清空**。<br>⑤ **功能面横铺三必查**：`$r('sys.symbol.xxx')` 先核 `id_defined.json`（写错**不报错只渲染空白**，本轮实测存在 `bookmark`/`bookmark_fill`/`bookmark_notepad`/`magnifyingglass`/`timer`/`folder`/`trash` 等，**不存在** `bookmark_square`/`note_text`/`highlighter`/`chart_bar`/`text_quote`/`pencil`）；单文件同模块**只写一行 import**（拆两行视同重复声明）；**新成员写到 struct 的 `}` 之后会引发几十条级联假错误**（`Property 'xxx' does not exist` + `UI component 'Column' cannot be used in this place`），元凶在报错点之外 ⇒ 扫「独占一行的 `}`」定位提前闭合处（实证 615 行），**别逐条改**。<br>坑点速查表 +3 行。附：划选浮动条/长按菜单**只放文字项**、破坏性红色（§2 UI 口径） |
| **v1.3.8** | 2026-09-30 | 新增 **LSN-030**（**存 URI 不复制文件 ⇒ 每次启动必须重新 `activatePermission`**）+ **修正 LSN-023 的误导性表述**。🔴 极难定位，症状 = 「**导入当次完全正常、杀进程重开就白屏**」，代码零报错、画布只剩一层底色。机理：① 本地书/音乐不拷进沙箱 ⇒ 仓库存**原始 URI**，靠 fileShare 持久授权直读；② `persistPermission` **跨重启不自动生效**，必须每次启动逐 URI `activatePermission`（LSN-023 旧文「picker URI 自带永久授权、persist/activate 仅作保险」**只在本次进程内成立**，已就地改正）；③ 漏掉 ⇒ `openSync` 抛 `13900001 EPERM` ⇒ catch 静默 return ⇒ 渲染层拿空内容 ⇒ 纯色白屏。<br>**正解（双保险）**：启动链路（`EntryAbility.startupReady`，数据仓库 init **之后**）`await BookRepo.activatePermissions()` + 读取路径 `FilePermission.ensureActive(uri)`。参考实现 `Icey-Player-Harmony/services/MediaScanner.ets:540`（注释原文「存原始 URI，重启后通过 activatePermission 恢复访问，不复制文件」，`:152/:624` 分批激活）。⚠️ 剪裁模板时「删掉没被引用的服务」极易把 `services/FilePermission.ets` 连带删掉，**务必保留**。<br>**配套确立「绝不静默失败」**：凡「内容读到空 ⇒ 界面整片空」的路径（记录缺失 / 目录为空 / **正文 0 字** / 排版 0 页 / 读文件抛异常）都必须落到 `@State loadError` + **可见错误态 + 重试入口**。这次白屏拖了两轮才定位，根因就是失败被静默吞掉。<br>坑点速查表 +2 行。来源：Icey-Reader 阅读器两次报白屏，前几轮误判在 canvas 尺寸 / 排版口径 / px2vp，真因是剪裁模板时漏抄权限激活 |
| **v1.3.7** | 2026-09-29 | 新增 **LSN-029**（`.gitignore` 签名约定）+ **修正内置模板** `../assets/template/.gitignore`：其第 13 行原为**裸 `signing/`** ⇒ 整个签名目录被忽略，仓库里没有 p7b/cer/p12/csr，`git status` 里也永远看不见（极易漏提交）。后果 = 新机器 clone 后构建不出可安装包（`unsigned.hap` / 安装报 `9568320 no signature file`），签名类问题（`00303074`）无法复现。<br>**定案规则**：签名材料**必须进仓库**，只忽略 `/signing/material/` 与 `/signing/debug/material/`（hap-sign-tool 哈希命名中间缓存，可重建）。⚠️ 两条都要写 —— 参考项目（Icey-Player-Harmony）只写了 `/signing/material/`，漏掉 `signing/debug/material/`。⚠️ 验证口径：`git check-ignore <目录>` 对目录判定**不可靠**，一律用 `git status --porcelain` + `git ls-files \| grep material`。<br>坑点速查表 +1 行。来源：Icey-Reader 照抄模板导致签名被整体忽略，用户复核 commit 时纠正「不用 ignore 签名 / material 是要忽略的」。<br>**⚠️ 2026-10-17 终版反转**：material **不提交**（换设备重输密码后重新生成，v1.4.1 的「material 必须进仓库」作废）；并补**跨应用复用**口径——换应用只换 p7b，cer/p12/csr 跨 Icey 系通用；明文密码绝不记录（build-profile 里只有密文）。终版全文见 LSN-029 |
| **v1.3.6** | 2026-09-18 | 扩充 **LSN-025**（实色大卡改多卡光感），补两条"改版后才暴露"的规则：<br>① **只读内容块（备注 / 说明正文）同样要"承载"**：玻璃卡面上直接铺一段正文，深浅两色下都可能不够清晰 ⇒ 应套一层与输入框**同款容器**（`surface` 底 + `borderRadius 12` + `0.5vp colors.fieldBorder` 发丝描边）。附带好处："同一份内容在表单页是 `TextArea`、在详情页是同款承载"，视觉语言一致、切换无割裂。<br>② **详情 / 只读页的字段为空时不要整块隐藏**：`if (hasNote) { 备注卡 }` ⇒ 用户**分不清"没填"还是"不支持"**。本工程实证：详情页备注卡原为"无备注不渲染"，用户随即报「详情页要能显示备注」。正解 = 字段卡**常驻** + 空值占位文案（「暂无备注」）——"这一栏存在"本身要被表达出来。⚠️ 与表单/编辑页**相反**：表单页空字段不渲染更清爽，因为没有"这一栏存在与否"的疑问。<br>坑点速查表 +1 行（只读页空字段） |
| **v1.3.5** | 2026-09-18 | 新增 **LSN-028**（**同一组件「点击 + 长按」+ 详情页自动刷新**）。三个坑都**编译全绿、仅真机暴露**：<br>① **`.onClick` 与 `.gesture(LongPressGesture)` 并存 ⇒ 双跳**：长按命中后抬手又触发点击 ⇒ 路由栈连进两页（用户看到"长按后莫名跳转"）。正解 = **互斥手势组** `GestureGroup(GestureMode.Exclusive, LongPressGesture({duration:500}).onAction(...), TapGesture({count:1}).onAction(...))`（独占模式"先满足条件者胜出"）；❌ 不要 `GestureMode.Parallel`（两个都触发）、❌ 不要叠两个 `.gesture()`。<br>② **子页"外部数据变更后不刷新"**：把重算结果放**普通字段缓存**、在 `build()` 里读 ⇒ 刷新链尾段变成"父组件重渲染**会不会顺带重跑 `@Builder`**"这一**不确定行为**；症状 = 编辑保存返回仍是旧值、**退出重进才对**（极易被误判为"没问题"）。正解 = **`@State` 持有视图模型 + `@Watch` 驱动重算**（`@Watch` 必须写在状态装饰器**之前**，LSN-012），并**入参只取 id、不持有快照**（页面永远 `repo.find(id)`；返回 `null` ⇒ 渲染「记录不存在」兜底卡，**不要在 build 里 pop**）。视图模型可以是页面内私有 class（同 `SegmentsParams` 范式），但**不许复算业务**（口径仍归 model，LSN-015）。<br>③ **`ForEach` 的 key 只写"身份"不写"值"** ⇒ "项还在、值变了"（如明细行的"已使用 / 目标成本 / 已存金额"）**key 不变 ⇒ 复用既有节点、不重跑 `@Builder`** ⇒ 永远停在旧值，是三者中最隐蔽的。正解 = key 带上会变的值（`kv_${label}_${value}_${accent}_${isLast}`）；列表页 key 再带 `_${this.assetsVersion}` 作双保险。<br>坑点速查表 +3 行（点击+长按 / 子页刷新 / ForEach key）。来源：AssetDailyCost「卡片改为长按编辑」后紧接着「点击卡片可以查看详情」，一轮内三坑齐现 |
| **v1.3.4** | 2026-09-18 | 新增 **LSN-027**（**长按手势**）：把「点击」改成「长按」时，`Stack` / `Column` 等容器**没有 `.onLongPress` 修饰符**——写 `.onLongPress(() => {...})` 报 `10505001 Property 'onLongPress' does not exist on type 'StackAttribute'`（换 `Column` 报 `'ColumnAttribute'`）。正确写法 = **`LongPressGesture` 描述符 + 容器根节点 `.gesture(LongPressGesture({ duration: 500 }).onAction(() => {...}))`**。⚠️ 连环坑：`LongPressGesture` 是 ArkUI **全局声明、无需 import**，试图 `import { LongPressGesture } from '@kit.ArkUI'` 会报 `10311006 'LongPressGesture' is not exported from Kit '@kit.ArkUI'`。含：挂载点选择（根容器；`hitTestBehavior(HitTestMode.None)` + `enabled(false)` 的材质承载层不拦截手势）、`.gesture()` 默认 `GesturePriority.Normal` 与宿主 `List` 滚动手势共存的原理（"按住不动"与"位移"判定互斥）、`repeat: true` 适用场景。并给出**「点击改长按」口径变更规范**：`.onClick` 整段替换为 `.gesture(...)`、回调属性**同步改名**（`onCardTap` → `onLongPress`）让调用点漏改即编译失败、复用组件把回调做成**带默认空实现的可选属性**（不传零副作用）。坑点速查表 +1 行（素材来源：AssetDailyCost 列表卡改长按编辑，连报两种编译错误后定稿） |
| **v1.3.3** | 2026-09-18 | 扩充 **LSN-023**（自定义壁纸）——补「**两组载体各自的蒙版来源**」对照表与排查细节。用户口语「**白色蒙版**」= 壁纸之上还有两层不透明底：① **主界面** `Index` 的 `HdsNavigation.backgroundColor = colors.background`（壁纸时 = `#B3F1F3F5` ≈70% 白，**整屏压暗**）；② 首页标题栏 `buildHomeTitleBar` 的滚动蒙层 `#CCFFFFFF`（**80% 白块**）/深色 `#CC000000`。**子页两条链默认已透明**（`SubPageScaffold` 的 `customBgUri ? Color.Transparent : …` + `buildSubPageTitleBar(..., transparentScrollMask = true, ...)`）⇒ 只剩主界面发白，极易漏。修法：主界面同口径条件透明 + 给 `buildHomeTitleBar` 加 `transparentScrollMask` 形参。⚠️ 两个排查细节：`HdsNavigation` 属性链上 **`backgroundColor` 可能被写了两次（后写生效）**，改透明要改最后那次；根 `Stack` 底色在壁纸 `Image` **之下**（自身底色先于子节点绘制），应**保留不透明**作解码兜底。坑点速查表 +1 行 |
| **v1.3.2** | 2026-09-18 | 新增 **LSN-026**（**沉浸光感必须有「可采样底层」**）：材质采样的对象是**组件背后的窗口内容**，若页面背景是**纯色**（无壁纸 / 无内容）⇒ 材质与毛玻璃都无信息可采，卡片退化成**「与页面同色的灰玻璃」**（浅色下只剩一圈模糊边，比原来的实色白卡更差）。修法：① 把「有底层」做成 `materialActive(forceOn, backdrop)` 的**第二形参**（与 `forceOn` 同规则，必须由调用方传订阅值；漏改任一调用点即编译失败，避免静默漏改）；② 无底层时**不下发材质**并回落实色卡底（`cardBg`：浅色 `#FFFFFF` / 深色 `#212121`）+ **去掉模糊**（模糊无内容可采）；③ 同源控件一律同步（hero 卡回**不透明渐变**、chips 回实色、弹窗卡片回实色且弹窗底改**不透明**）；④ `materialDiagnostics()` 增加「底层=自定义壁纸 / 无」一档。坑点速查表 +1 行 |
| **v1.3.1** | 2026-09-18 | 新增 **LSN-025**（实色大卡改多卡光感的三件事）：① **卡内控件可辨性**——卡片由实色 `cardBg` 换成光感材质/毛玻璃后，控件原有的 `surface(#F5F5F5)` 浅填充与卡面几乎同色 ⇒「输入框 / 开关行 / 分段控件」看不出边界（编译全绿、只有真机截图能发现），修法为加 **`0.5vp` `colors.fieldBorder` 发丝描边**（保留实色填充 ⇒ 文字对比度不受材质影响）；**次级按钮同理且更隐蔽**——`surface` 填充按钮直接贴页面背景在浅色下几乎不可见 ⇒ **操作区必须留在卡片内**；② **属性链位置**：修饰符须写在**内层容器 `}` 之后、外层自定义组件 `}` 之前**，写成 `}`→`}`→`.width()` 报 `10505001 Declaration or statement expected` + `Cannot find name 'width'`（报错点比真实元凶低一层，与附录 D7 同源）；③ **分卡边界直接取原 `sectionTitle` 锚点**（一个标题 = 一张卡，`if (分支)` 内可放多个 ListItem，卡标题统一 14/Medium/textPrimary）。坑点速查表 +2 行（实色卡换光感卡 / 插卡片边界） |
| **v1.3.0** | 2026-09-17 | ★ **沉浸光感材质 + 自定义壁纸 双能力沉淀**。<br>① **光感**：模板内置 `services/SystemMaterial.ets`（惰性构造 `ImmersiveMaterial`——模块级求值低版本闪退 / 三档缓存：静态带影·静态无影·可交互按流光色 / `applyMaterialCarrier` / `pressLightColor` / `fallbackSurface` / `materialDiagnostics` 诊断）+ `components/MaterialCard/`（`MaterialCardLayer` 承载层——**仅 `ToggleType.Button` 可承载整块矩形材质**，五条属性缺一不可；`MaterialCard` 外壳 + 降级毛玻璃）。新增 **LSN-022**（四条层级规则 / `attributeModifier` 必须方法调用 / `interactive+空 lightEffect` 不渲染 / 三件事降级 / 卡片·hero沾色·弹窗·chips 四形态接入）。坑点速查表 +3 行。<br>② **壁纸**：`PhotoViewPicker` 全流程（**字段是 `photoUris`** / options 显式类型 / URI 自带永久授权）+ `ThemeManager.setCustomBg` 半透明背景（**不动深浅模式**）+ **三链路状态重放**。新增 **LSN-023**。<br>③ **模板修复**：`compatibleSdkVersion 6.1.0(23)→26.0.0`（光感是 API 26 能力）；修复 `startWindowIcon` 残留引用 `$media:tab_music` 资源缺失 → `$media:layered_image`；新增 **LSN-024**（资源引用与文件不成对，报错指向 build 中间产物）。<br>✅ **模板 23 个既有编译错误全部修复**（getInstance 漂移×8 / Blank 嵌套×7 / 缺 import×4 / bindSheet 挂自定义组件 / 括号残缺 / 可选字段未判空），`assembleHap` 构建通过（见「模板健康状态」） |
| **v1.2.0** | 2026-09-17 | ★ **图标体系换代 + SDK 版本书写规范修正**。<br>① **图标**：按用户要求**弃用自研 SVG 图标组件、统一改用鸿蒙官方符号**——`SymbolGlyph($r('sys.symbol.xxx')).fontSize(22).fontColor([color])`。理由：零资源文件（原 28 个 SVG）、随系统字体缩放、系统自带 `xxx`/`xxx_fill` 选中态配对、`.fontColor([...])` 支持分层多色。同步迁移内置模板：`SettingItem` 的 `icon: string` → `iconSymbol: Resource \| null`（非装饰成员）、`SettingsGroupEntry.iconSymbol?: Resource` + 透传 `?? null`、`Index.ets` 的 Tab 与 `HomeTab`/`SettingsTab`/`HomeDetailPage` 各页图标；**删除 `components/SFIcon/` 与 28 个失效 SVG**。新增 **LSN-020**（选名方法 / `$r` 编译期字面量约束 / 组件 API 变形 / 易错点 / 符号映射表 / **"符号名写错不报错只是空白 ⇒ 必须截图验证"**）。<br>② **SDK**：新增 **LSN-021** 并**修正 D5**——SDK 版本号格式**按 API 级别分界**：API < 26 用 `x.y.z(api)`（`"6.1.1(24)"`），**API ≥ 26 用点分制 `major.minor.patch`（`"26.0.0"`）**。依据：hvigor 源码 `FIRST_DOT_API_VERSION = 26` + `DOT_API_VERSION_PATTERN`，与官方文档「从 API 26.0.0 开始配置统一」互证。错误码对照：26 前漏 `(api)` → `00306042`；26 加 `(26)` → `00308018`；**升 SDK 改半截（compatible 改 26、target 仍 24）→ IDE sync 报 `00303015`**（校验实现在 `one-sdk-validator.js`，规则 `compatible ≤ target ≤ compile`；`compileSdkVersion` 由 IDE 解析的 SDK 决定，故 **CLI 构建可能不报、必须另跑 `--sync` 验证**）。原 D5 结论（一律补 `(API)` 后缀）**对 API 26 SDK 已不成立**。Q11 改为「以 sdk-pkg.json 实测为准」。<br>坑点速查表 +4 行（图标、SDK 版本写法、升 SDK 三字段联动、能力清单/W6/Q7 同步改写） |
| **v1.1.11** | 2026-09-17 | 新增 LSN-019：**`@Builder` 按值传参不刷新** —— 改了值界面不变、但保存后重开又对了。ArkUI 明文规则：按值传参时状态变量改变**不刷新** Builder 内部，只有传**对象字面量**（按引用）才会刷新。含 ① **同文件对照实验确诊法**（同一状态机制下「内联 `Row` 正常 / 走 `@Builder` 异常」⇒ 唯一差异即元凶）；② 三种修法（内联 `build()` 首选 / 对象字面量按引用传参 / 子组件 `@Prop`）；③ 同根因的其余受害者（分段控件 `selected` 高亮不动、开关行 `isOn` 不回显、随状态变化的 `fieldLabel` 文案）；④ **极易骗人的验证姿势警告**：别用"保存 → 重开 → 看值对不对"验证（值本来就对，会误判为无 bug），必须**停留在当前页**看 UI 是否即时刷新。**实测来源：新增资产表单改购买日期后文本不动**（同页分类/目标日期/到期时间因内联而正常）。坑点速查表 +1 行 |
| **v1.1.10** | 2026-09-17 | 新增 LSN-018：**启动竞态导致列表页永久「加载中…」**（编译零报错、恢复越快越必然复现）。双重根因——① `AppStorage.set()` 对**不存在的键静默落空**（恢复链路 34ms 跑在 `App.aboutToAppear` 建键 55ms 之前）；② `App.aboutToAppear` **无条件** `setOrCreate('dataLoaded', false)` 覆写已置的 `true`；两者叠加使结果**顺序敏感**。给出三处协同修法（写入方恒 `setOrCreate` / 建键方仅缺键时初始化 / 300ms 就绪自愈兜底）+ 仓库 `isReady()` 约定 + 验证姿势（`launch fallback` 告警数须为 0）。★ 同步修复内置模板 → 附录 C 新增 **D10**（模板 App.ets 与 EntryAbility.ets 原样自带此缺陷）；坑点速查表 +1 行 |
| **v1.1.9** | 2026-09-17 | 新增 LSN-017：**签名与安装三连坑**（真机交付链路上最耗时的一环）——① `signingConfigs` **声明 ≠ 使用**，product 缺 `"signingConfig": "default"` 就产出 `-unsigned.hap`，安装报 `error:9568320 no signature file`；② 改 `bundleName` 后 `.idea/.deveco/project.cache.json` 缓存 `BUNDLE_NAME` 导致日志仍 `Launching <旧包名>`，必须 Sync 并重申请绑定新包名的 p7b；③ **签名判定方法论**：本 SDK 下既找不到 `Hap Signature Block` 魔数，signed/unsigned 的 zip 条目也**完全相同**，唯一可靠判据是解包检索 kebab-case 的 `bundle-name`/`app-identifier`/`debug-info`。含 `hdc` 真机验证标准动作（`bm get --udid` 核白名单 → `install -r` → `bm dump -a` 核 appIdentifier）；铁律 +2 条（#38/#39）、坑点速查表 +2 行 |
| **v1.1.8** | 2026-09-16 | 新增 LSN-016：**跨组件传 `@Builder` 会丢 this**——菜单能展开、点菜单项才崩（`TypeError: undefined is not callable`）。含三步闭锁定性法（列号落到成员名 ⇒ this 是"有对象但缺成员"即被重绑 / 同文件找"只调模块级导入的 builder"作反证 / 反推 `.selected()` 打钩静默失效，必须两个症状一起收）。确立规范：通用组件收菜单一律走**「`@Prop` 数据 + 普通函数属性回调」配置化**，禁止塞 `@BuilderParam`；并明确**同组件内 `bindMenu(this.xxxMenu)` 是安全的**，只有跨组件才触发。★ 同步修复内置模板 `SettingItem`（`@BuilderParam menu` → `menuOptions`/`menuSelected`/`onMenuPick`，`Menu` 由组件内 `ForEach` 构建）；坑点速查表 +2 行 |
| **v1.1.7** | 2026-09-16 | 新增 LSN-015：跨组件只传**展示型数据类**——`@Prop` 深拷贝不保证类方法存活（传 `AssetItem[]` 后调实例方法＝运行时炸弹），叠加"视图层不做业务计算"既有约定，共同指向同一架构：**算都在 model，UI 只排版**，比例/百分比宽度/说明文案全部预聚合。判别口诀"要过 @Prop 的类，一个方法都别加"；坑点速查表再 +2 行（ListView 子项里的横向滚动条必须显式 `.height()`，否则高度不确定会塌成 0 或撑高整行；给子组件传列表数据用纯数据类） |
| **v1.1.6** | 2026-09-16 | 新增 LSN-014：`width('100%')` 与横向 `margin` 不可同挂——margin 在尺寸之外，总占位 = 父宽 + 2×margin，右端越界被 `List` 裁切成直角（用户描述为「显示不全」）。含**截图逐像素取证法**（左内缩 ≈16vp / 右内缩 = 0 / 右上角无圆角 ⇒ 确诊）与孪生反例（List padding + 卡片 margin = 双倍内缩 32vp）；确立规范：**横向内缩只由宿主 List 的 padding 提供，卡片只留纵向 margin**；坑点速查表新增「卡片左右内缩」行 |
| **v1.1.5** | 2026-09-16 | ★ 附录 C 扩充 D5~D9：`targetSdkVersion "26.0.0"` 格式非法导致 hvigor 直接拒绝构建（00306042）、`HdsNavigationTitleBarOptions` 未 import + `opts.content` 可选判空、自定义组件后链式 `bindSheet` 触发"build 只能有一个根节点"、`Blank` 不能直接作 `ListItem` 子组件、`AppSheet`/`SubPageScaffold` 的 `@Watch` 顺序写反；新增 LSN-013「内置副本 compile-ready 校验，原样复制后必须全表扫一遍」；坑点速查表同步 +6 行；明确"只修 D1~D4 仍编不过，至少需修 D1/D2/D5/D6/D7/D8" |
| **v1.1.4** | 2026-09-08 | 新增 LSN-012：`@Watch` 装饰器必须写在状态装饰器之前（写反被 SDK 静默忽略 → `@State` 缓存只算一次永不更新）；跨 Tab 信号驱动 UI 优先走「父组件 build 引用信号→整树级联」（对齐主题 themeColorsVersion 已验证通路），列表计算在 build 内直接重算绕开 @Watch 陷阱 |
| **v1.1.3** | 2026-09-08 | 新增 LSN-011：日期选择用官方 `showDatePickerDialog` 替代手写滚轮（onDateAccept 只回公历 Date、lunarSwitch 建议关闭由外部口径 chip 单一事实源控制）；坑点速查表新增「日期选择」行 |
| **v1.1.2** | 2026-09-08 | 新增 LSN-010：HdsTabs 底栏中央「+」标准方案（5 页签占位 + onContentWillChange 拦截 + onTabBarClick 弹窗，自绘底栏方案被用户否决的实证）；坑点速查表新增「底栏中央大按钮」行；铁律 #37 补强 hvigor UP-TO-DATE 强制重编完整解法（删 cache + .hvigor + intermediates/loader* + touch 源文件） |
| **v1.1.1** | 2026-09-07 | 铁律 #16 修正补强：明确区分 Hds 自有枚举（可退数值）与系统 ArkUI 枚举（必须用枚举名）；新增真机实证——`NavigationMode` 数值 1=Split 非 Stack（整页压左半屏）、`TabsCacheMode.CACHE_BOTH_SIDE=0` |
| **v1.1.0** | 2026-09-07 | 内置可移植模板副本 `../assets/template/`（79 文件 / 1.2MB），换机器开箱即用；§0 改为三级定位（内置副本优先）；新增铁律 #00；新增 `../assets/TEMPLATE_MANIFEST.md`（清单/排除项/同步约定）；W1 增加「先修 D1~D4」前置步骤 |
| v1.0.0 | 2026-09-07 | 初始版本：8 条工作流、37 条铁律、15 行坑点速查表、9 条 LSN、模板缺陷清单 D1~D4 |

---

*鸿蒙 App 模板基建 v1.3.12 | 内置模板，换机即用 | 读模板 → 按工作流剪裁 → 按铁律改代码 | 改前先看 §2，改后先过 §7，新建工程先扫附录 C*
