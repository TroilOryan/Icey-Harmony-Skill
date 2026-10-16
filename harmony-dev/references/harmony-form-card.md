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

## 5.5 卡片 API 白名单：权威核查方法（别靠记忆猜）

卡片能用的组件/属性**不由文档决定，由本地 SDK 白名单文件决定**——文档写「支持部分组件」但不给清单，
猜错就是编译期 `11706006 can't support form application.`（报错只给文件行号，不给"该用什么替代"）。

**权威判据路径（DevEco 自带，离线可用）**：

```
<DevEco>/sdk/default/openharmony/ets/build-tools/ets-loader/form_components/*.json
```

- 目录下**每个 json 文件名 = 一个卡片可用组件**（`text.json` / `image.json` / `marquee.json` / `row.json` …）；
  文件里 `attrs` 数组 = 该组件在卡片可用的属性**白名单**。
- 查某属性能不能用：找到对应组件 json，看 `attrs` 里有没有它。
- ⚠️ **属性在白名单 ≠ 该属性的所有枚举值都能用**（见下 MARQUEE 坑）——枚举值须以实际编译结果验证。

## 6. 卡片组件能力坑

- 🚫 **卡片上不要用跑马灯（`Marquee` 组件），已验证会造成整卡数据不刷新**。
  两条独立的坑：
  1. **编译层**：`TextOverflow.MARQUEE` **不被卡片支持**，编译报 `11706006`
     `'MARQUEE' can't support form application.`（`textOverflow` 属性在 `text.json` 白名单里，
     但 `MARQUEE` 这个**取值**被单独拒绝）。
  2. **运行时层（更隐蔽、更致命）**：改用白名单里独立的 `Marquee` 组件（`marquee.json`）能编译通过，
     但 `Marquee` 的文本 `src` 是**组件构造参数**（`Marquee({ start, src })`）——
     **ArkUI 的构造参数在 `@LocalStorageProp` 收到新值时不重新求值**（`Text(content)` 的文本内容
     有响应式特化，`Marquee` 没有）。后果：`formProvider.updateForm` 推了新数据、卡片进程也收到了新的
     `@LocalStorageProp` 值，但 `Marquee` 的 `src` 仍锁在首帧旧值 → **表现为"切歌、播放/暂停全都不更新"**
     （排查极易误判为宿主没推 / formId 注册丢失，实际卡在卡片渲染层）。
     系统另有明文限制：卡片上跑马灯**只滚动一次**（`marquee.d.ts`：
     "Regardless of the value, the marquee scrolls only once on an ArkTS widget"）。
  ⇒ **正解：卡片长文本用 `Text` + `maxLines(1)` + `textOverflow({ overflow: TextOverflow.Ellipsis })`**
  （属性都在 `text.json` 白名单内），长文本以省略号收尾，不要追求滚动。
- ⚠️ **通用铁律：卡片里优先用"内容型"组件 + 属性绑定，慎用"构造参数型"组件**。
  只有 `Text` 这类把内容作为 `Text(content)` 传入的组件，其内容会被 ArkUI 重算；
  任何把动态数据放进**构造参数**的组件（`Marquee({src})`、`Gauge({value})` 等）在
  `@LocalStorageProp` 更新后都不会重算构造参数 → 数据"锁死"。卡片里要让动态数据显示，
  首选 `Text` / `Image(src)`（`Image` 用 `memory://key` 变 key 触发重载，见铁律 1）。
- ⚠️ **卡片文字/图标颜色要跟随背景深浅时，不要在卡片里 import 取色服务**：卡片跑在独立进程、
  受 API 白名单约束，带 `effectKit`/`image` 的服务（如 `CoverColorExtractor`）不能进卡片上下文。
  正解 = **宿主侧算好颜色字段再推**（与 `imageColorHex` 同模式）：宿主内联复刻亮度 + 混色两个纯函数
  （`0.299R+0.587G+0.114B` 判深浅、基色 `#1A1A1A`/`#F5F5F5` 与主色混 15%），推 `textColorHex` /
  `textColorSecondaryHex`（`#B3` + 一级色）/ 强调色；卡片端只消费字段，零计算零依赖。
  半透明承载块（如 20% 白圆底）在浅封面上"白上白"看不见 ⇒ 推一个 `overlayBaseHex`
  （浅背景 `000000` / 深背景 `FFFFFF`），卡片端 `'#33' + this.overlayBaseHex` 自行拼 alpha，
  不必为每种透明度各推一个字段。

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

## 8. 应用内「会员身份卡 + 自定义卡片背景」接入清单（2026-10-16，Icey-Reader 三轮白屏换来的）

> 适用场景：任意 Icey 系应用要接「开通后显示身份卡，且卡背景图可由用户自定义（浅/深双槽 + 模糊）」。
> 参考实现：Icey-Player-Harmony `components/VipIdentityCard.ets`（base64 data URI 版）、
> Icey-Reader 同名组件（`file://` 沙箱文件版）。**两边踩的坑不重叠，都读。**

### 8.1 数据链（三键 + 一派生）
- 槽位：`settings_vipCardBgEnabled` / `LightUri` / `DarkUri` / `Blur`（持久化）；
- **派生键** `settings_vipCardBgUri`：`resolveEffectiveVipCardBg()` 按「开关开 + 当前深浅模式对应槽」解析写入，
  **不落盘**，每次启动/切模式/换图重解析；卡片组件只读派生键，不自己判槽位。
- 触发点收口：开关切换 / 任一槽位写入 / `applyColorMode` 尾部，**三处都要调 resolve**。

### 8.2 卡片层序（player 定案，勿改动顺序）
根 Stack：① `#111111` 黑金底（**常驻不切换**）→ ② 背景图层（有图才渲染）→ ③ 内容 Column（恒透明）。
- 内容层**永远是最后一个子节点**且不参与条件渲染——混在 if 里会在状态翻转时整棵重建、内容偶发不挂载（「卡上啥都没有」的历史根因）。
- 文字色：**有图且解码成功 → 跟当前深浅模式**（浅图深字/深图浅金字）；无图 → 恒金色。
- 背景层双层结构：下层**同图实心**托底 + 上层 `.blur`——`.blur` 在图片边界按透明加权，单层必有四周缝隙。

### 8.3 ⚠️ 三条铁律（每条都是真机实锤，违反必复现）
1. **背景层尺寸兜底只能用常量**：`constraintSize({minWidth:300, minHeight:144})`。
   ❌ 实测值回喂（`onAreaChange` → `@State cardH` → `minHeight: cardH`）= 正反馈，
   卡片无限增高——指纹：`[AREA]` 日志**逐帧 +2**。`matchParent`×2 做主路径即可。
2. **禁用 `.key()`**（测试专用 API，非测试目录行为未定义）；「换图强制刷新」靠
   版本号 bump ⇒ `@StorageLink` 触发组件 rerender ⇒ `Image.create(uri)` 重读 src。
   消费方页面 `aboutToAppear` bump 一次（`file://` URI 异步解码不随节点重建重发）。
3. **宿主 List 禁挂 `fadingEdge`**：离屏渐隐遮罩会吞掉首屏「实底+图+blur」卡片的
   **底色与背景层**（布局树全对但像素不画）。症状指纹：「布局树节点全对但不绘制」。
   双向对照实验（撤属性/回挂各跑一轮真机）是唯一可信判据。

### 8.4 排查顺序（会员卡「不显示/不刷新/变高」）
1. 先看 `resolve` 日志：`effectiveLen=0` ⇒ 查开关/当前模式对应槽位是否为空（**别查渲染**）；
2. `[AREA]` 是否逐帧上涨 ⇒ 正反馈，删掉一切「实测值 → 布局尺寸」的回流；
3. `[AREA]` 从不打印 ⇒ 宿主布局未完成（条件渲染分支里的 ListItem），用常量兜底尺寸；
4. 节点在、bounds 对、像素不画 ⇒ 查宿主 List 的 `fadingEdge`（本册 8.3-3）。

### 8.5 接入步骤（新应用从零接，按序做完即等价 player/reader 现状）
1. **SettingsManager 加六键 + 解析器**（照 Icey-Reader `SettingsManager.ets:119-135`）：
   槽位三键（Enabled/LightUri/DarkUri）+ Blur + **派生键**（Uri，不落盘）+ **版本键**
   （UriVersion，写槽位 +1，供 `.key()` 强制重建 Image）；
2. **resolve 函数**：`resolveEffectiveVipCardBg()` —— 开关开 ⇒ 读当前模式对应槽 ⇒
   写派生键 + 记日志（`effectiveLen=` 是排查锚点，必须打）；
3. **三个触发点全部接**：开关切换 / 槽位写入 / `applyColorMode` 尾部（或深浅切换回调）。
   漏一处 = "切模式背景不换"或"选图没反应"；
4. **选图管线**：`CustomBgManager.pickVipCardBg(ctx, slot)` —— PhotoViewPicker 选 1 张 →
   `FilePermission.persist+activate`（重启仍可读）→ **缩到 720 宽 → JPEG → 落沙箱文件**
   （别存相册 URI：跨重启会失效）；清槽 = **先删文件再清槽位**（顺序不能反，幂等）；
5. **共享组件** `VipIdentityCard`（数据组件自取，调用方只传展示参数）；
   设置页与会员页**挂同一份**，禁止两处内联（player 三轮教训）；
6. **会员门禁在生效侧再判**：UI 置灰不够，会员过期后槽位数据仍在 ⇒ resolve 前判
   `isVip`（与 UI 层同源），非会员强制走默认卡；
7. **云同步**：把四槽键（Enabled/Light/Dark/Blur）加进 `SYNC_SETTING_KEYS`；
   派生键/版本键**必须排除**（见第 9 章 9.4）。

### 8.6 两端参考实现的差异（按自家数据量选型）
| | player 版 | reader 版 |
|---|---|---|
| 槽位 URI 形态 | base64 data URI 存 preferences | `file://` 沙箱文件（720 宽缩图落盘） |
| 适用 | 卡片背景图小（几百 KB 内） | 图可能大；preferences 单值 8192 字节上限敏感 |
| 已知代价 | preferences 膨胀 | 需 FilePermission.persist + 文件生命周期管理 |
其余（六键结构 / resolve / 版本键 / 层序 / 文字色口径）**两端完全同构**，照抄即可。

## 9. 应用内「设置云同步」接入清单（2026-10-16，Icey-Reader 从 rustdesk 移植 + player/reader 双端落地）

> 适用场景：任意 Icey 系应用要接「设置项跨设备云备份与恢复」（会员功能）。
> 参考实现：Icey-Reader `services/CloudSyncService.ets`（状态机 ~800 行）+
> `CloudSyncSnapshotStore.ets`（快照 IO）+ `CloudSyncTask.ets`（错误/trace 类型）+
> `CloudSyncBridge.ets`（解环注册表）+ `SettingsBackupService.ets`（载荷编解码）+
> UI 层 `CloudSyncCard.ets`。**移植来源 rustdesk 的迁移评估文档
> `docs/cloud-sync-migration-assessment.md` 是最值钱的一份，先读它。**

### 9.1 架构（五文件分层，照抄即可）
- `CloudSyncService` —— 状态机主服务（上传/下载/裁决/恢复，全部可靠性机制在这）；
- `CloudSyncSnapshotStore` —— 快照 IO（UUID 追加命名、sha256、回读比对）；
- `SettingsBackupService` —— 载荷编解码（`{format, schemaVersion, contentTime, sha256, content}` 信封）；
- `CloudSyncBridge` —— **解环注册表**（见 9.3）；
- `CloudSyncCard` —— UI 卡（挂会员中心已开通区；状态机三态 Idle/Syncing/Restoring）。

### 9.2 冲突语义与可靠性机制（R 编号 = rustdesk 评估文档编号，**一个都不能删**）
- **整包替换 + 墙钟 LWW，不是 merge**——设置项"每项独立、用户逐项调"，LWW 可接受；
  要真 merge 的范本是 `ApiBookSync.ets`（逐项三方合并）。
- R5 epoch 世代计数丢弃过期异步结果（每个 await 边界断言）；
- R6 localRevision 丢弃被本地并发改动作废的结果（仍存基线但报 pending，**不谎报成功**）；
- R7 单飞锁 + 请求合并（同 actionKey 返回同一个 promise）；
- R9 还原后回读校验实际写入条数，不符报错而非成功；
- R10 崩溃安全：基线只在系统确认完成后才推进（崩了下次重新裁决）；
- **R13 空态防丢数据**：新设备不许上传空 / 云端空不许静默还原——
  "全新安装的空本地状态"永远不能覆盖云端（**这是防丢数据的关键设计**）；
- 两阶段恢复：预览铸造 ticket（仅内存）→ 确认时四重校验（ticket/epoch/revision/内容逐字节）。

### 9.3 ⚠️ 接线三要点（漏一个 = 静默失败）
1. **初始化顺序**：`SettingsManager.init` **必须最先**（EntryAbility onCreate 各模块独立
   try-catch）；`CloudSyncService.init(ctx)` 在其后（注册桥），**不能在设置写入之前**——
   否则 save() 经桥触发 markLocalChanged 时服务未就绪；
2. **写入口收口**：`markLocalChanged()` 的触发点**唯一** —— `SettingsManager.save()` 统一调
   （比"每个写入方各自调用"安全：一个入口漏不掉）。**循环依赖用 `CloudSyncBridge`
   解**（依赖倒置注册表：Bridge 不 import 任何服务，恒为依赖树叶；ArkTS 循环 import
   下静态初始化顺序不保证，直接互调会拿到 undefined）；
3. **自动同步时机**（对齐 player）：`onForeground` ⇒ `syncNow`（回前台对账，LWW 裁决
   不会误判）；`onBackground` ⇒ `upload`（退后台上传，防旧快照覆盖别设备新备份）。
   两者都 catch 静默——UI 卡有手动入口，系统层不该打扰用户。

### 9.4 ⚠️ 同步白名单（`SYNC_SETTING_KEYS`）三条纪律
- **排除派生键**（`settings_customBgUri` / `settings_vipCardBgUri`）——同步它反而会把
  本机沙箱路径写到另一台设备的槽位（文件不存在）；
- **排除事件版本号键**（`xxxVersion`）——纯本机刷新信号；
- URI 槽位键（`file://` 沙箱路径）**仍同步**：恢复侧填 AppStorage 后走 `resolveEffective*`，
  无效路径只会让背景回落默认不会崩——与"开关/模糊值"保持同一份备份的完整性优先。
- 白名单是**上传/恢复唯一依据**（`exportAll`/`applyAll` 双侧校验同一份 Set）；
  未创建的键跳过、**不写默认值**（把"对方没设过"误当"显式设成默认"语义不同）。

### 9.5 ⚠️⚠️ CloudDisk 快照存储的两个坑（原项目实测，"简化"掉必复现）
1. **CloudDisk 上 rename 覆盖已有名字返回 EINVAL（实测 13900020）**——
   天真的"写临时文件 + rename 覆盖固定名"本地测试通过、真机失败（最难查的静默失败）。
   正解 = **追加式 UUID 命名 + 拒绝覆盖 + 旧定名文件保持可读**
   （`cloud-sync-v2-<时间戳>-<UUID>.iceysync`；快照 ID 严格 basename 防路径穿越）；
2. **损坏的"最新"快照绝不静默回退到旧快照**——静默回退可能把用户已删除的设置"复活"
   （用户关掉自定义背景、恢复后又被打开）。宁可报错让用户选历史版本。
- 其余：短写检测/回读比对/sha256（写入完整性）；**fsync 只对本地镜像做，不对云目录做**
  （云盘虚拟文件系统不需要且有兼容风险）。

### 9.6 能力授权（不是 permission）
`context.cloudFileDir` 为空 = 用户未开系统「云盘同步」/ 未授权云空间——**应用无法自己授予**
（官方行为）。判定后 UI 降级（卡片灰态 + 说明文案），不要报错误。

### 9.7 UI 铁律（CloudSyncCard，同 player）
- 同步期间**不阻塞**（`syncNow` 异步，UI 先切"同步中"再 await）；
- 状态文案**区分 pending 与 failed**：超时/被作废/等确认 ⇒ 中性色"待处理"语气
  （`result.pending`——**不是失败**，别显示成红色错误）；真失败才用错误色；
- "进行中"态最短可见 420ms（服务快速返回时没有它 Syncing→Idle 同帧完成，"进行中"永不显示）；
- 危险操作（恢复覆盖本机）走两阶段：预览列明"将恢复 N 项设置"→ 用户确认才写入。

### 9.8 需替换的"每应用常量"清单（移植时 grep 一遍）
| 常量 | reader 值 | 说明 |
|---|---|---|
| `CLOUD_FOLDER_NAME` | `Icey Reader` | 每应用云目录是共享的，必须自己划一块 |
| `CLOUD_FILE_NAME` | `cloud-sync-v1.iceysync` | v1 定名文件（读取兼容位） |
| `SNAPSHOT_FORMAT` | `IceyReaderCloudSnapshot` | 信封格式串（变更 = 破坏跨版本兼容） |
| 后缀 | `.iceysync` | `.srdsync`→`.iceysync`（对照 rustdesk） |
| `SYNC_SETTING_KEYS` | 本应用白名单 | 上传/恢复唯一依据 |
| trace 出口 | `AppLogger`（`CloudSyncTrace.setSink` 注入） | 别用 console.*（进不了导出日志） |
