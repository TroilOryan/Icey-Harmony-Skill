---
name: harmony-app-template
description: >
  [MANDATORY] 基于 HarmonyAppTemplate 基建模板快速搭建与扩展鸿蒙 App（HarmonyOS / ArkTS / ArkUI）。
  触发词：鸿蒙/鸿蒙App/HarmonyOS/ArkTS/ArkUI/ETS/Stage 模型；
  新建项目/脚手架/模板工程/初始化/开工；
  新建页面/新增子页/加个Tab/HdsTabs/HdsNavigation/路由跳转/push/路由栈；
  设置页/设置项/持久化开关/preferences/存本地/存盘；
  弹窗/底部弹窗/bindSheet/确认弹窗/AppSheet/宽屏dialog；
  主题/深浅色/暗色模式/自定义背景/毛玻璃/GlassCard；
  安全区/状态栏/全屏/挖孔/SafeArea/标题栏；
  图标/SFIcon/加个图标、运行日志/AppLogger/更新日志；
  hvigor 报错/safe-delete/编译不过/改了没生效
version: 1.3.6
changelog: "v1.3.6: 扩充 **LSN-025**（实色大卡改多卡光感）——补两条『改版后才暴露』的规则：① **只读内容块（备注 / 说明正文）同样要承载**：玻璃卡面上直接铺正文在深浅两色下都可能不清晰，应套一层与输入框同款容器（`surface` 底 + `borderRadius 12` + `0.5vp colors.fieldBorder` 描边），好处是『同一份内容表单页是 TextArea、详情页是同款承载』，视觉语言一致。② **详情/只读页字段为空时不要整块隐藏**：`if (hasNote) { 备注卡 }` ⇒ 用户分不清『没填』与『不支持』（本工程实证：详情页备注卡原为『无备注不渲染』→ 用户随即报『详情页要能显示备注』）；正解 = 字段卡**常驻** + 空值占位（『暂无备注』）⇒ 详情/只读页与表单页**相反**（表单页空字段不渲染更清爽，因为没有『这一栏存在与否』的疑问）。坑点速查表 +1 行；v1.3.5: 新增 **LSN-028**（**同一组件「点击 + 长按」+ 详情页自动刷新**，三坑皆『编译全绿、仅真机暴露』）：① `.onClick` 与 `.gesture(LongPressGesture)` **并存** ⇒ 长按命中后抬手**又触发点击** ⇒ 连跳两页（进编辑页又跳详情页）；正解 = **互斥手势组** `GestureGroup(GestureMode.Exclusive, LongPressGesture, TapGesture)`（『先满足条件者胜出』；❌ 不要 Parallel）。② 子页要在『外部数据变更后』刷新时，**别把重算结果放普通字段缓存**——刷新链尾段是『父重渲染会不会顺带重跑 @Builder』这一**不确定行为**，症状 = 编辑保存返回仍是旧值、退出重进才对；正解 = **`@State` 视图模型 + `@Watch` 驱动重算**（`@Watch` 写在状态装饰器**之前**，LSN-012）+ **入参只取 id、不持快照**（`repo.find(id)` 为 null ⇒ 渲染『记录不存在』兜底卡，不在 build 里 pop）。③ **`ForEach` 的 key 只写『身份』不写『值』** ⇒ 项还在、值变了 ⇒ 复用既有节点、不重跑 `@Builder` ⇒ 永远停在旧值；正解 = key 带上会变的值。坑点速查表 +3 行；v1.3.4: 新增 **LSN-027**（**长按手势**）：`Stack`/`Column` 等容器**没有 `.onLongPress` 修饰符**（写 `.onLongPress(...)` 报 `10505001 Property 'onLongPress' does not exist on type 'StackAttribute'/'ColumnAttribute'`）；正确写法 = **`LongPressGesture` 手势描述符 + 容器根节点 `.gesture(LongPressGesture({ duration: 500 }).onAction(...))`**，且 `LongPressGesture` 是 ArkUI **全局声明、无需 import**（`import { LongPressGesture } from '@kit.ArkUI'` 会报 `10311006 ... is not exported from Kit '@kit.ArkUI'`）。含挂载点选择（根容器 + `hitTestBehavior(None)` 承载层不拦截）、与宿主 `List` 滚动手势共存原理、`repeat` 适用场景，以及「点击改长按」时的**口径变更规范**（`.onClick` 整段替换 + 回调属性同步改名让调用点漏改编译失败 + 复用组件回调做带默认空实现的可选属性）。坑点速查表 +1 行；v1.3.3: 扩充 **LSN-023**（自定义壁纸）——补『**两组载体各自的蒙版来源**』对照表：主界面 = `Index` 的 `HdsNavigation.backgroundColor`（`colors.background`，壁纸时 ≈70% 白，整屏压暗）+ `buildHomeTitleBar` 滚动蒙层 `#CCFFFFFF`（80% 白块）；子页 = `SubPageScaffold` 条件透明 + `buildSubPageTitleBar(..., true, ...)`。子页默认已透明、**主界面极易漏**（本模板即出现『子页干净、主界面发白』）。附两处排查细节：`HdsNavigation` 属性链上 `backgroundColor` **可能写了两次（后写生效）**；根 `Stack` 底色在壁纸 `Image` **之下**，应保留不透明作解码兜底。坑点速查表 +1 行；v1.3.2: 新增 LSN-026（**沉浸光感必须有「可采样底层」**：材质采样的是组件背后的窗口内容，页面背景若是**纯色**（无壁纸/无内容）⇒ 材质/毛玻璃无信息可采，卡片退化成『与页面同色的灰玻璃』，浅色下只剩一圈模糊边。修法：把『有底层』做成 `materialActive(forceOn, backdrop)` 的**第二形参**（漏改即编译失败），无底层时**不下发材质**并回落实色卡底（`cardBg` 白/深灰）+ 去掉模糊；hero 卡回不透明渐变、chips 回实色、弹窗底改不透明。诊断串加『底层』一档）；坑点速查表 +1 行；v1.3.1: 新增 LSN-025（**实色大卡改多卡光感的三件事**：① 卡内控件可辨性——卡片从实色 cardBg 换玻璃后 `surface` 浅填充与卡面几乎同色导致『输入框消失』，须加 0.5vp `colors.fieldBorder` 发丝描边（保留实色填充 ⇒ 文字对比度不受材质影响）；`surface` 次级按钮直接贴页面背景同理几乎不可见 ⇒ 操作区须留在卡片内；② **属性链必须写在内层容器 `}` 之后、外层自定义组件 `}` 之前**，写成 `}`→`}`→`.width()` 会报 `10505001 Declaration or statement expected` + `Cannot find name 'width'`（报错点比真实元凶低一层，与附录 D7 同源）；③ 分卡边界直接取原 `sectionTitle` 锚点，`if (分支)` 内可放多个 ListItem，标题样式统一为卡片标题规格）；坑点速查表 +2 行；v1.3.0: ★ 沉浸光感材质 + 自定义壁纸 双能力沉淀。①【光感】模板内置 services/SystemMaterial.ets（惰性构造 ImmersiveMaterial / 三档缓存 / applyMaterialCarrier / pressLightColor / fallbackSurface / materialDiagnostics 诊断）+ components/MaterialCard（MaterialCardLayer 承载层——仅 ToggleType.Button 可承载整块矩形材质，五条属性缺一不可；MaterialCard 卡片外壳 + 降级毛玻璃）；坑点速查表 +5 行（承载层写法 / 不显示四排查 / photoUris 字段 / 资源引用成对检查）。新增 LSN-022（光感四条层级规则 / 承载层五条属性 / 三件事降级 / 四形态接入）、LSN-023（壁纸 photoUris + 三链路重放）、LSN-024（资源引用报错指向中间产物）。②【模板修复】compatibleSdkVersion 6.1.0(23)→26.0.0（光感为 API 26 能力）；修复 startWindowIcon 残留引用 $media:tab_music 资源缺失；**修复全部 23 个既有 ArkTS 编译错误，模板 assembleHap 构建通过**（getInstance 漂移 / Blank 嵌套 / 缺 import / bindSheet 挂自定义组件 / 可选字段未判空——错误模式已登记「模板健康状态」）。v1.2.0: 图标体系换代 + SDK 版本书写规范修正。①【图标】按用户要求**弃用自研 SVG 图标组件、统一改用鸿蒙官方符号** `SymbolGlyph($r('sys.symbol.*'))`——零资源文件、随字体缩放、`.fontColor([...])` 支持分层多色；同步迁移内置模板（SettingItem 的 `icon:string`→`iconSymbol:Resource`、SettingsGroupEntry 同改、Index 的 4 个 Tab 与各页图标）并**删除 SFIcon 组件与 28 个失效 SVG**；新增 LSN-020（含选名方法、`$r` 编译期字面量约束、组件 API 变形、易错点、本项目符号映射表、以及『符号名写错不报错只是空白 ⇒ 必须截图验证』）。②【SDK】新增 LSN-021 并**修正 D5**：SDK 版本号格式**按 API 级别分界**——API < 26 用 `x.y.z(api)`，**API ≥ 26 用点分制 `major.minor.patch`**（读 hvigor 源码 `FIRST_DOT_API_VERSION = 26` + 官方文档双重确认）；给 26 加 `(26)` 报 00308018、26 前漏 `(api)` 报 00306042；坑点速查表 +3 行；v1.1.11: 新增 LSN-019「@Builder 按值传参不刷新——改了值界面不变、但重开又对了」。含同文件『对照实验』确诊法（同一状态机制下，内联 Row 正常 / 走 @Builder 异常 ⇒ 唯一差异即元凶）、三种修法（内联 build / 对象字面量按引用传参 / 子组件 @Prop）、同根因的其余受害者（分段控件 selected 高亮、开关行 isOn 回显、动态 fieldLabel 文案），以及**极易骗人的验证姿势警告**：别用"保存后重开看值对不对"验证（值本来就对，会误判为无 bug），必须停留在当前页看 UI 是否即时刷新。坑点速查表 +1 行；v1.1.10: 新增 LSN-018「启动竞态：AppStorage.set 对不存在的键静默空操作 → 列表页永久加载中」，含双重根因分析（写入落空 + 无条件建键覆盖）、三处协同修法、isReady() 约定与验证姿势；同步修复内置模板（附录 C 新增 D10）；坑点速查表 +1 行；v1.1.9: 新增 LSN-017「签名与安装三连坑」——① signingConfigs 声明≠使用（product 必须显式 signingConfig 才产出 signed hap，否则 9568320 no signature file）；② 改 bundleName 后 IDE 缓存 .idea/.deveco/project.cache.json 仍用旧包名，必须 Sync；③ 签名无法靠「Hap Signature Block 魔数」或「条目 diff」判定，唯一可靠判据是解包检索 kebab-case 的 bundle-name/app-identifier/debug-info（含 hdc 真机验证标准动作）；铁律 +2 条（#38/#39）、坑点速查表 +2 行；v1.1.8: 新增 LSN-016「跨组件传 @Builder 会丢 this——菜单能弹出、点一下才崩（undefined is not callable）」，含三步闭锁定性法 + 配置化替代方案（@Prop 数据 + 普通函数属性回调）；坑点速查表 +2 行；同步修复内置模板 SettingItem 的 @BuilderParam menu 缺陷；v1.1.7: 新增 LSN-015「跨组件只传展示型数据类」（@Prop 深拷贝会丢方法 + 视图层禁止重算业务值，两条约束指向同一架构）；坑点速查表再 +2 行（ListView 子项里的横向滚动条必须显式设高、给子组件传列表数据要用纯数据类）；v1.1.6: 新增 LSN-014「width('100%') 与横向 margin 不可同挂」（卡片右端被 List 裁切成直角，用户报「显示不全」；含截图逐像素取证法 + 横向内缩统一归宿主 List padding 的规范写法）；坑点速查表新增「卡片左右内缩」行；v1.1.5: 新增附录 C 缺陷 D5~D9（模板原样复制后 4 处必然编译失败：targetSdkVersion 格式非法 / HdsNavigationTitleBarOptions 未 import / 自定义组件后链式 bindSheet / Blank 直接作 ListItem 子组件）；新增 LSN-013 模板缺陷清单与坑点速查表同步；v1.1.4: LSN-012 @Watch 顺序与跨 Tab 级联"
---

# 鸿蒙 App 模板基建 v1.3.6

> 📦 **本 Skill 自带模板工程副本**（`assets/template/`，79 文件 / 1.2MB）——
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

改动必须以真实模板为准，**禁止凭记忆写代码**。**本 Skill 自带模板副本**（`assets/template/`），
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

**内置副本内容清单与排除项**见 `assets/TEMPLATE_MANIFEST.md`。

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

**完整文件职责表见** `references/file-map.md`。

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
| **07** | 顶部留白硬编码 `112` | 换机型/折叠屏错位 | `Blank().height(SafeArea.top + 64)`（状态栏 + MINI 标题栏 56 + 8） |
| **08** | 内容顶部加固定空白 Column 做避让 | 内容被滚动模糊带压住 | List **视口顶到屏幕顶**，留白放**第一个 ListItem**，内容自然滑进模糊带 |
| **09** | List 尾部不预留 | `barOverlap` 悬浮底栏遮住最后几项 | 末 ListItem `Blank().height(SafeArea.bottom + 80)`（子页 +40） |
| **10** | 卡片用 `width('100%')` 同时又给 margin | 溢出 → 边距不生效 | 左右间距交给**父容器 ListItem padding** 或 GlassCard 自带 margin |

### 标题栏渐变模糊（**四处配套，缺一不可**）

| # | 组件/位置 | 必须做的配置 | 缺了会怎样 |
|---|---|---|---|
| **11** | 标题栏配置对象 | `avoidLayoutSafeArea: true` | 标题文字被状态栏压住 |
| **12** | HdsNavigation / SubPageScaffold | `.ignoreLayoutSafeArea([0], [0])`（SYSTEM=0/TOP=0） | 状态栏后面是一条白/黑带 |
| **13** | 根 Stack | `.expandSafeArea([SYSTEM],[TOP,BOTTOM])` + `.backgroundColor(ThemeManager.colors.background)` | 顶部露出裸白条 |
| **14** | 滚动蒙层高度 | `maskExtraHeight: 28`（内容短的页调小） | 模糊带盖住卡片顶部 |

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

> 完整可复制代码见 `references/workflows.md`，此处只给决策要点。

| 编号 | 场景 | 涉及文件 | 关键点 |
|---|---|---|---|
| **W1** | 从模板新建项目 | 复制 `assets/template/` → `build-profile.json5`、`AppScope/app.json5`、string.json、Index.ets | **先按附录 C 修 D1~D9（否则编不过）** → 改 bundleName → **targetSdkVersion 对齐本机 sdk-pkg.json 的 apiVersion** → DevEco 关联 SDK → 按裁剪清单删模块 |
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
| 顶部避让标题栏 | `Blank().height(112)` | `Blank().height(SafeArea.top + 64)` |
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
| 列表顶部/尾部留白 | `ListItem() { Blank().height(SafeArea.top + 64) }`（**编译失败**：Blank 只能嵌在 Row/Column/Flex） | `ListItem() { Row() {}.height(SafeArea.top + 64).width('100%') }` |
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
| 给卡片加沉浸光感 | 直接给卡片 `.backgroundBlurStyle(Thin)` 或给外壳 `backgroundColor` 设材质 | 卡片外壳 = `Stack{ MaterialCardLayer + Column{内容} }`（模板 `components/MaterialCard`）。**承载层只能用 `ToggleType.Button`**（Checkbox 未适配；Switch 只覆盖开关本体），五条属性缺一不可：`LayoutPolicy.matchParent`（百分比会顶大卡片）/ borderRadius 同外壳 / `backgroundColor(Transparent)` / `enabled(false)+focusable(false)+accessibilityLevel('no')+hitTestBehavior(None)` / `attributeModifier` 放链**末**。应用级前置 `module.json5` metadata `ohos.arkui.UIMaterial.state="enable"`（模板已自带，改后须重装）。⚠️ 材质**不报错不失效提示**，必须真机截图验证（见 LSN-022） |
| 光感材质画出来了但不刷新/不显示 | ① `attributeModifier` 写成内联对象字面量（拨开关后已画卡片不更新）② 外壳/承载层有**不透明底色**（材质层级在 backgroundColor 之下，被盖住）③ `interactive:true` 配**空 `lightEffect:{}`**（材质完全不渲染）④ `bindSheet` 不设透明底（默认白底整块盖住） | ① modifier 写成**方法调用**并读订阅变量；② 材质开时底色一律 `Color.Transparent`，关闭时回实色；③ 无流光色时**省略** lightEffect 字段；④ `bindSheet(..., { backgroundColor: Color.Transparent })`。材质不可用时降级：**半透明底色 + `backgroundBlurStyle(Thin)`**，缺半透明底色则模糊被盖住（见 LSN-022） |
| 加自定义壁纸（选图作背景） | ① `result.uris`（**PhotoSelectResult 没有 uris 字段**，直接编译报错）② 对象字面量不标类型（`arkts-no-untyped-obj-literals`）③ 改了壁纸但重启后背景变回不透明 | 正确写法：`const opts: photoAccessHelper.PhotoSelectOptions = {...}`（显式类型）→ `result.photoUris[0]`（字段名 **photoUris**，class 定义在 openharmony 侧 `@ohos.file.photoAccessHelper.d.ts`）→ `SettingsManager.setCustomBgUri(uri)` 联动 `ThemeManager.setCustomBg`。picker 返回的 URI **自带永久授权**（persist 仅保险）。⚠️ **三处链路必须重放壁纸状态**：App 启动 / `onConfigurationUpdate`（updateFromConfig 重算 colors 会打回不透明）/ 设置变更（见 LSN-023） |
| 把实色卡片换成光感 / 玻璃卡 | 卡内控件仍用 `surface` 浅填充 → 与玻璃卡面几乎同色，「输入框 / 开关行 / 分段控件」看不出边界；`surface` 次级按钮直接贴在页面背景上 → 浅色下 `#F2F3F4` vs `#F5F5F5` 几乎看不见按钮 | 控件加 **`0.5vp` 发丝描边**（复用 `colors.fieldBorder`，实色填充保留 ⇒ 文字对比度不受材质影响）；**次级按钮留在卡片内**（见 LSN-025） |
| 给已有嵌套组件插卡片边界 | 内层容器与外层组件两个 `}` 都写完了才写 `.width()/.padding()` → `10505001 Declaration or statement expected` + `Cannot find name 'width'`，**报错点比真实元凶低一层** | 修饰符写在**内层容器 `}` 之后、外层自定义组件 `}` 之前**（自定义组件闭括号后不能再挂属性链，与附录 D7 同源）（见 LSN-025） |
| 设了自定义壁纸，但页面/顶部仍发白（用户口语「白色蒙版」） | 壁纸之上还有两层无色**不透明底**在盖：① 主界面 `HdsNavigation.backgroundColor = colors.background`（壁纸时 ≈70% 白，整屏压暗）② 首页标题栏滚动蒙层 `#CCFFFFFF`（80% 白块）。子页两条链默认已透明 ⇒ 只有主界面发白 | 改成与子页同口径：`HdsNavigation.backgroundColor` 条件透明（注意属性链上 **`backgroundColor` 可能写了两次，后写生效**）+ `buildHomeTitleBar(..., transparentScrollMask = true)`（见 LSN-023） |
| 材质下方是**纯色背景**（无壁纸 / 页面无内容） | 材质/毛玻璃无信息可采 → 卡片退化成**「与页面同色的灰玻璃」**（浅色下只剩一圈模糊边，比原来的实色白卡更差）；不报错 | 把「有底层」做成 `materialActive(forceOn, backdrop)` 的**第二形参**；无底层时**不下发材质** + 回落实色 `cardBg`（浅色白 / 深色 #212121）+ **去掉模糊**（见 LSN-026） |
| 修改模板/工程里的资源引用（$media/$color/$string） | 引用写对了名字但 `resources/base/media/` 里没有对应文件 → 构建报 `The resource reference '$media:xxx' is not defined`，且报错指向 **build 中间产物**，难以定位源头 | 引用与资源**成对检查**：改完先 `grep -rn '\$media:' --include="*.json5"` 列出全部引用，再 `ls resources/base/media/` 核对。⚠️ 报错路径是 `entry/build/.../module.json`（中间产物），**真实源头在 `src/main/module.json5`**（见 LSN-024） |
| 给卡片/列表项做「长按」交互 | 写 `.onLongPress(() => {...})` 挂在 `Stack`/`Column` 上 → 报 `10505001 Property 'onLongPress' does not exist on type 'StackAttribute'`；再改成 `import { LongPressGesture } from '@kit.ArkUI'` → 报 `10311006 ... is not exported from Kit '@kit.ArkUI'` | **`LongPressGesture` 是 ArkUI 全局声明、无需 import**，写法 = 容器根节点 `.gesture(LongPressGesture({ duration: 500 }).onAction(() => {...}))`。内部"不吃手势"的承载层（`hitTestBehavior(None)` + `enabled(false)`）不拦截。改交互时回调属性**同步改名**让调用点漏改编译失败（见 LSN-027） |
| 同一组件既要「点击」又要「长按」（如列表卡：点击看详情 / 长按编辑） | `.onClick(...)` + `.gesture(LongPressGesture(...))` **并存**（两个独立手势）：长按命中后抬手**又触发点击** ⇒ 连跳两页（进编辑页又跳详情页）。编译全绿、只有真机暴露 | 绑成**互斥手势组**：`.gesture(GestureGroup(GestureMode.Exclusive, LongPressGesture({duration:500}).onAction(...), TapGesture({count:1}).onAction(...)))` —— 独占模式"先满足条件者胜出"。❌ 不要 `GestureMode.Parallel`（两个都触发）（见 LSN-028） |
| 子页需要「外部数据变更后自动刷新」（编辑保存返回详情要显示新值） | 把重算结果放**普通字段缓存**、在 `build()` 里读 ⇒ 刷新链尾段是"父组件重渲染**会不会顺带重跑 `@Builder`**"这一**不确定行为** ⇒ 返回后仍是旧值、退出重进才对 | 用 **`@State` 持有视图模型 + `@Watch` 驱动重算**（`@Watch` 写在状态装饰器**之前**，LSN-012）；入参**只取 id、不持快照**，页面永远 `repo.find(id)`，取到 `null` 渲染「记录不存在」兜底卡（见 LSN-028） |
| `ForEach` 里的数值变了但界面不更新（编辑后明细行还显示旧值） | key 只写"身份"：`(r) => \`kv_${r.label}\`` ⇒ 项还在、值变了 ⇒ **key 不变 ⇒ 复用既有节点、不重跑 `@Builder`** | key 里**带上会变的值**：`\`kv_${r.label}_${r.value}_${r.accent}_${r.isLast}\``。同理列表页 key 带上 `_${this.assetsVersion}` 做双保险（见 LSN-028） |
| 详情/只读页的某个字段为空 | 整块隐藏（`if (hasNote) { 备注卡 }`）⇒ 用户**分不清"没填"还是"不支持"**（本工程实测：详情页备注卡「无备注不渲染」，随即被用户报「详情页要能显示备注」） | **详情/只读页的字段卡常驻**，空值给占位文案（「暂无备注」）——"这一栏存在"本身要被表达出来。表单/编辑页相反：空字段不渲染更清爽（没有"存在与否"的疑问）。备注等正文块要用与输入框同款承载（`surface` + 0.5vp `fieldBorder` 描边），别直接铺在玻璃上（见 LSN-025） |

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
- **口诀**：横向内缩归 List，卡片只留纵向间距

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
  ③ SDK 文档注明 picker 返回的 URI **自带永久授权**——`FilePermission.persist/activate` 仅作保险
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

**口诀**：**"玻璃要看得见，背后先得有东西；没有底层就回实色，别把纯色糊一遍"**

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

### B2. 模板工程（= `assets/template/`，复制出去后即新工程根）

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
| **v1.1.0** | 2026-09-07 | 内置可移植模板副本 `assets/template/`（79 文件 / 1.2MB），换机器开箱即用；§0 改为三级定位（内置副本优先）；新增铁律 #00；新增 `assets/TEMPLATE_MANIFEST.md`（清单/排除项/同步约定）；W1 增加「先修 D1~D4」前置步骤 |
| v1.0.0 | 2026-09-07 | 初始版本：8 条工作流、37 条铁律、15 行坑点速查表、9 条 LSN、模板缺陷清单 D1~D4 |

---

*鸿蒙 App 模板基建 v1.3.3 | 内置模板，换机即用 | 读模板 → 按工作流剪裁 → 按铁律改代码 | 改前先看 §2，改后先过 §7，新建工程先扫附录 C*
