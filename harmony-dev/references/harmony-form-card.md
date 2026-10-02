> **分册：`harmony-form-card`（合并版）** ｜ 由原独立技能 `harmony-form-card` 与 `harmonyos-arkts-form-card` 合并，2026-10-03 并入 `harmony-dev`。
> 第一部分是「铁律 / 判定口径」，第二部分是「三件套 / 数据注入 / 刷新 / 点击」的实操清单。

# HarmonyOS 桌面卡片（Form Kit）开发与调试

> **第一部分：铁律与判定口径** ｜ 下面至下一个「第一部分/第二部分」标记之间的章节都属于本部分。

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

## 第二部分：三件套 / 数据注入 / 刷新 / 点击（实操清单）

> 下面至文末的 7 节都属于本部分。

适用：给 HarmonyOS（ArkTS/ETS，DevEco）应用加桌面卡片、加卡片模板、或修「数据变了卡片不更新」。

## 1. 卡片三件套（必须齐全）

| 文件 | 作用 |
|---|---|
| `entry/src/main/resources/base/profile/form_config.json` | 卡片模板表（name / src / dimension / isDynamic / updateEnabled …） |
| `entry/src/main/module.json5` → `extensionAbilities[type=form]` | 注册 FormExtensionAbility，metadata 指向 `$profile:form_config` |
| `entry/src/main/ets/widget/pages/*.ets` | 卡片 UI，`@Entry(storage)` + `@LocalStorageProp` 承接宿主推送字段 |
| `entry/src/main/ets/formability/EntryFormAbility.ets` | `onAddForm` / `onUpdateForm` 返回或推送数据 |

新增模板：form_config.json 加一条（`src` 指向新页面、`defaultDimension`/`supportDimensions` 写尺寸如 `4*4`），并在 `base/element/string.json` 加 `displayName`/`description` 字符串。**卡片页不需要进 main_pages.json。**

## 2. 尺寸语义

`2*2` / `2*4` / `4*4` = 桌面格子数，`2*4` 是**宽扁**卡（4 宽 × 2 高，横向排两列没问题），`4*4` 是近方形大卡。

## 3. 静态卡片数据注入（isDynamic: false）

- 卡片页面用 `@LocalStorageProp('key')` 承接字段；普通 `@State` 不参与 FormBindingData 映射。
- 宿主推送：`formBindingData.createFormBindingData(payload)` + `formProvider.updateForm(formId, msg)`。
- payload 必须是**显式类实例**（ArkTS `arkts-no-untyped-obj-literals`），字段只放 string/number/boolean。
- 多条目（列表/网格）不要塞多个平行字段，塞**一个 JSON 字符串**（如 `list`），卡片侧用纯数据类 + `JSON.parse` 还原；解析类放在**零 Kit 依赖**的文件里（卡片对可调用 API 有白名单限制，别让卡片间接 import ArkData）。

## 4. 卡片不刷新（高频问题）——根因与正解

卡片是**拉取式**渲染：数据落盘变了，卡片不会自己知道。三条刷新路径：

1. **定时**：form_config 里 `updateEnabled: true` + `updateDuration`（单位为 30 分钟）+ `scheduledUpdateTime`。
2. **数据变更实时刷新（正解）**：在**唯一的数据写入出口**（如 `Store.save()`）调用：
   ```ts
   const payload = WidgetData.build(ctx);                 // 与 FormAbility 共用的装配函数
   formProvider.getPublishedRunningFormInfos()            // API 20+，非系统接口、无需权限
     .then((infos: formInfo.RunningFormInfo[]) => {
       for (const info of infos) {
         if (!FORM_NAMES.includes(info.formName)) continue;  // ⚠️ 必须过滤：可能含其它应用的卡片，更新会报 16501003
         formProvider.updateForm(info.formId, formBindingData.createFormBindingData(payload)).catch(...)
       }
     })
   ```
   好处：`onUpdateForm(formId)` 只给 formId、拿不到模板名 → **统一推送超集字段**，不再需要 formId→模板名 映射表，也不用持久化 formId。
   注意 context 要先注入（`EntryAbility.onCreate` 里 `FormRefresh.init(this.context)`，放在 Store.init **之前**，因为 Store 恢复/迁移可能立刻触发一次刷新）。
3. **卡片侧交互后**：卡片点击（FormLink / postCardAction，见第七节）拉起 Ability 时顺带刷新。

排查：日志打 `desktop=<总数> pushed=<本应用数>`；若 pushed 恒 0 且桌面确有卡片 → 该接口没返回本应用卡片，退回持久化 formId（`onAddForm` 存、`onRemoveForm` 删）。

## 5. 卡片点击交互：静态卡片必须用 FormLink（高频坑）

**铁律**：`isDynamic:false` 的静态卡片**不支持** `postCardAction` —— 写了 onClick + postCardAction 编译通过但**真机点了没任何反应**（静默无日志）。静态卡片只能用 **`FormLink`** 容器包裹触发事件；动态卡片才用 postCardAction，且动态卡片**反而不能用 FormLink**。

```ts
// 静态卡片：点击区域用 FormLink 包裹（支持单个子组件，需显式给宽高）
FormLink({
  action: 'router',                 // router=拉起应用前台；message=onFormEvent 不拉起；call=后台拉 singleton Ability（需 KEEP_BACKGROUND_RUNNING）
  abilityName: 'EntryAbility',      // 可选 bundleName / moduleName；uri 与 abilityName 同给时 abilityName 优先
  params: { 'eventId': item.i },    // params 平铺进 want.parameters；只支持 string/number/boolean，别传复杂对象/状态变量
}) {
  Row() { /* 卡片内容 */ }.width('100%').height(48)
}
.width('100%')
.height(48)
```

**「点卡片任意处进应用 + 点条目进对应详情」的标准结构**：外层 `FormLink`（不带 params）包整卡兜住空白区，内层每行/每格各自 `FormLink`（带 `params:{id}`），嵌套使用；内层命中时优先走内层 params，params 为空则宿主只拉起应用。

宿主侧接收（静态卡片 router 事件）：
- 冷启动走 `UIAbility.onCreate(want)`，热启动走 `onNewWant(want)` —— **两个都要处理**（卡片 Ability 常为 singleton）。
- `want.parameters['eventId']`（params 平铺，不是 `want.parameters.params`）→ 写 AppStorage 信号 → 页面 `@Watch` 或 `aboutToAppear` 里跳转。
- ⚠️ 页面 `aboutToAppear` **绝不能** `setOrCreate('信号键', 0/'')` 归零：`setOrCreate` 是覆盖写，会抹掉 Ability 在页面构造前写入的信号（冷启动永远跳不过去）；且 `@Watch` 不对初始值触发，必须在 `aboutToAppear` 主动补一次。
- 冷启动时数据可能未恢复：跳转前做「重试到数据就绪」（如 200ms × 15）并在消费后清空信号，避免重复压栈。

## 6. 卡片组件能力坑

- ✅ 支持：Row/Column/Stack/Text/Circle/Divider/Blank/List/ListItem/ForEach/image 等（含 @Builder、@LocalStorageProp）。
- ❌ 不支持/不建议：`Grid`/`GridItem`（用 Row+Column+ForEach 自己分行）、左右滑动手势（与桌面分页冲突）、大图与复杂动画。
- `Circle().fill()` 会报 “supported since SDK version 26.0.0, compatible SDK is …”，与项目既有卡片一致即可（仅 WARN）。
- 静态卡片别用 `@State` 承接推送字段；`aboutToAppear` 只跑一次，**要随数据变化的列表在 build 里解析**（用 raw 字符串 + 缓存兜住重复 JSON.parse）。
- 卡片根容器给 `borderRadius` + 深浅两套底（`#FFFFFF`/`#000000`），宫格用浅灰/深灰格底（`#F5F5F7`/`#1C1C1E`）区分层次。

## 7. 验证（本地 CI 式）

```bash
export JAVA_HOME="/c/Program Files/Huawei/DevEco Studio/jbr"
"…/tools/node/node.exe" "…/tools/hvigor/bin/hvigorw.js" \
  --mode module -p product=default -p module=entry@default assembleHap --no-daemon
# 看 CompileArkTS 是否 0 错误（PackageHap 失败常见于本机 java.dll 注册表问题，非代码问题）
```
