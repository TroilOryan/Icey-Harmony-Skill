---
name: harmony-form-card
description: HarmonyOS/ArkTS 桌面服务卡片（Form Kit，form_config.json + FormExtensionAbility）的开发与调试方法：数据注入（静态卡片 @LocalStorageProp / 独立进程读不到 AppStorage）、卡片点按路由（FormLink）、卡片尺寸与字号换算、卡片样式与应用内组件保持一致的做法、卡片透明背景（背板透明开放能力）。当要新建/修改桌面卡片、卡片数据不刷新、卡片点击无反应、卡片与应用内样式不一致、想调卡片背景透明度时使用。
agent_created: true
---

# HarmonyOS 桌面服务卡片（Form Kit）开发要点

## 先分清卡片类型（决定一切限制）

| | 静态卡片 | 动态卡片 |
|---|---|---|
| `form_config.json` | `"isDynamic": false` | `true` |
| 点击交互 | **只能 `FormLink` 包裹**（不支持 `postCardAction`） | `postCardAction` |
| 数据 | 宿主 `formProvider.updateForm(formId, formBindingData)` 推送 | 可用 ArkTS 逻辑 |
| 背景透明 | 可以（需开放能力） | 可以 |

**HML(JS) 卡片**（`uiSyntax: "js"`）能力远低于 **ArkTS 卡片**（`"arkts"`）——自定义组件、动效只在 ArkTS 卡片可用
（`@Component` / `@Entry` 自 API 9 起支持在 ArkTS 卡片中使用）。

## 铁律 1：卡片跑在独立进程，读不到宿主的 AppStorage

`FormExtensionAbility` 与主 Ability **不同进程**。宿主内存里的 `AppStorage` 卡片一概看不见。

解法只有两条，按优先级：
1. **字段注入**（首选）：宿主把值放进 `FormBindingData`（一个字段=卡片里一个
   `@LocalStorageProp('同名字段')`）。**字段名必须与 payload 属性名逐字相同**，否则永远拿到默认值。
   多个模板统一推**超集字段**（`onUpdateForm(formId)` 只给得到 formId，拿不到模板名）。
2. **读同一份落盘 Preferences**：`preferences.getPreferencesSync(ctx, {name:'xxx'})`。
   固定套路：① 先 `AppStorage.get<T>(key)`（宿主进程里是最新值）→ ② 取不到（卡片进程）读**同名落盘键**
   → ③ 再兜底默认值。`themeMode` / `dark` 就是这么走的。

宿主把持设置改完**必须主动推**：`formProvider.getPublishedRunningFormInfos()` 拿桌面上现存实例
（按自己的模板名白名单过滤，否则更新别人的卡片报 `16501003`）→ 逐个 `updateForm`。
不推就只能等定时刷新（`scheduledUpdateTime` / `updateDuration`）或下一次事件变更。

## 铁律 2：卡片样式与应用内保持一致的做法

卡片**不能 import App 内组件**：① 那些组件常常 import 了 ThemeManager/preferences，卡片有 API 白名单；
② App 页面也不能实例化卡片的 `@Entry` 组件。⇒ 只能**镜像**（手抄样式）。

把镜像面**收敛到最少、并写成显式契约**：
- 数据侧：让 App 侧预览与卡片走**同一条装配函数**（如 `WidgetData.buildFrom(events, dark)`，
  卡片侧 `build(ctx)` 读落盘后也调它）⇒ 预览显示的就是卡片真正会收到的字段值，
  永不出现"预览和桌面不一样"。
- 视觉侧：每个镜像文件头写死「**本文件镜像 XXX.ets，改一必须改 N**」，并列出镜像清单。
- 换算原则：**按卡宽收档，不逐像素照搬**。例：App 卡 360vp 宽、数据块 112 → 桌面 155vp 宽卡
  数据块 66、数字 22 自适应 13 → 18 自适应 12。字号随卡高同档收窄。

## 铁律 3：卡片尺寸与 vp

- `form_config.json` 的 `window`：`designWidth: 720` + **`autoDesignWidth: true`**
  → designWidth 被忽略、基准宽自适应 ⇒ 代码里的 `fontSize(13)` 就是 **13vp**，不用自己换算。
- 常用档位（360vp 宽机型）：2 列（1x2/2x2）= **155vp 宽**，1 行 ≈ 76vp，2x2 = 155×155，
  4x4 = 320×320 上下。设计时按此估算可用宽度，别照抄 App 的满宽数值。
- 高度用 `height('100%')`（卡片根由系统给尺寸），不要在卡片里写死根高。

## 铁律 4：卡片里的常见坑

- **`Row` 的 `space` 会作用到所有子项**：想「A|B 紧贴、只有 C 与它们留白」时必须把 A、B 包进
  一个**无 space 的内层 Row**（外层 space 会往 A、B 之间也塞间隙）。
- **`layoutWeight` 的方向随父容器**：在 `Row` 里是横向权重，在 `Column` 里是**纵向**。
  `Text` 的自适应字号（`maxFontSize/minFontSize`）需要**有宽度约束**：放 Row 里 + `layoutWeight(1)`。
- **满高色块 + 垂直视觉补偿**：Bold 数字字形重心偏上 → 给**文字** `offset({y:2})`，
  **绝不能 offset 色块本身**（背景跟着动 → 顶缝 + 底裁）。
- 圆角裁切靠父容器 `.borderRadius(16) + .clip(true)`（贴边色块才会被裁齐）。
- 先设 `"transparencyEnabled": true` 也别指望卡片能透（见下）。

## 卡片背景透明 = 开放能力，不是代码问题

官方《ArkTS 背板透明卡片》：**API 22 起**才有该能力，三道硬门槛都过才生效：
① 在 **AGC「开放能力管理」申请「背板透明卡片」**（申请原因 + **UI 设计释义附件必填**，审核 1-3 工作日）；
② **手动签名**，且签名 Profile 携带该能力（自动签名不生效）；③ 官方示例 `isDynamic: true` + 接反色字体
（`FormParam.HOST_BG_INVERSE_COLOR_KEY`）。
`form_config.json` 的 `transparencyEnabled`（schema 默认 false）**只是一句声明**，没有 ①② 系统直接忽略。

**未接入时的表现**（别往错方向调）：系统在卡片底下画一层**默认背板**（浅色白 / 深色黑）——
把卡片自己的 `backgroundColor` alpha 调到 0，露出来的**是那层系统白板、不是壁纸** ⇒ 白叠白、肉眼零变化。
遇到"调透明度没反应"先问"开放能力申请了吗"，不要反复改代码。

## 调试顺序（避免瞎猜）

1. 卡片数据不对 → 先在宿主确认 payload 字段名与 `@LocalStorageProp('x')` **逐字相同**，
   再确认推送调用真的执行了（`updateForm` 的 catch 里打日志）。
2. 卡片样式不对 → 确认改的是**卡片页**还是 **App 内同款**（镜像两份，容易只改一份）。
3. 改完卡片布局 → **桌面上已存在的卡片要删掉重新添加**才吃新代码（静态卡片缓存旧布局）；
   `form_config.json` 的变更对已存在卡片同样不生效。
4. `FormLink` 的 `params` 是宿主能拿到的路由参数（如 `eventId`），宿主在 `onCreate/onNewWant`
   里从 `want.parameters` 取。
