---
name: harmonyos-arkts-form-card
description: HarmonyOS/ArkTS 桌面卡片（Form/Widget）开发与刷新：新增卡片模板、静态卡片数据注入、卡片点击跳转（FormLink / postCardAction 区别）、卡片与宿主共享数据、数据变更实时刷新桌面卡片、卡片组件能力白名单与常见坑。触发词：桌面卡片、服务卡片、widget、form、form_config、updateForm、卡片不刷新、postCardAction 无效、FormLink、FormExtensionAbility。
agent_created: true
---

# HarmonyOS ArkTS 桌面卡片（Form）开发与刷新

适用：给 HarmonyOS（ArkTS/ETS，DevEco）应用加桌面卡片、加卡片模板、或修「数据变了卡片不更新」。

## 一、卡片三件套（必须齐全）

| 文件 | 作用 |
|---|---|
| `entry/src/main/resources/base/profile/form_config.json` | 卡片模板表（name / src / dimension / isDynamic / updateEnabled …） |
| `entry/src/main/module.json5` → `extensionAbilities[type=form]` | 注册 FormExtensionAbility，metadata 指向 `$profile:form_config` |
| `entry/src/main/ets/widget/pages/*.ets` | 卡片 UI，`@Entry(storage)` + `@LocalStorageProp` 承接宿主推送字段 |
| `entry/src/main/ets/formability/EntryFormAbility.ets` | `onAddForm` / `onUpdateForm` 返回或推送数据 |

新增模板：form_config.json 加一条（`src` 指向新页面、`defaultDimension`/`supportDimensions` 写尺寸如 `4*4`），并在 `base/element/string.json` 加 `displayName`/`description` 字符串。**卡片页不需要进 main_pages.json。**

## 二、尺寸语义

`2*2` / `2*4` / `4*4` = 桌面格子数，`2*4` 是**宽扁**卡（4 宽 × 2 高，横向排两列没问题），`4*4` 是近方形大卡。

## 三、静态卡片数据注入（isDynamic: false）

- 卡片页面用 `@LocalStorageProp('key')` 承接字段；普通 `@State` 不参与 FormBindingData 映射。
- 宿主推送：`formBindingData.createFormBindingData(payload)` + `formProvider.updateForm(formId, msg)`。
- payload 必须是**显式类实例**（ArkTS `arkts-no-untyped-obj-literals`），字段只放 string/number/boolean。
- 多条目（列表/网格）不要塞多个平行字段，塞**一个 JSON 字符串**（如 `list`），卡片侧用纯数据类 + `JSON.parse` 还原；解析类放在**零 Kit 依赖**的文件里（卡片对可调用 API 有白名单限制，别让卡片间接 import ArkData）。

## 四、卡片不刷新（高频问题）——根因与正解

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

## 七、卡片点击交互：静态卡片必须用 FormLink（高频坑）

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

## 五、卡片组件能力坑

- ✅ 支持：Row/Column/Stack/Text/Circle/Divider/Blank/List/ListItem/ForEach/image 等（含 @Builder、@LocalStorageProp）。
- ❌ 不支持/不建议：`Grid`/`GridItem`（用 Row+Column+ForEach 自己分行）、左右滑动手势（与桌面分页冲突）、大图与复杂动画。
- `Circle().fill()` 会报 “supported since SDK version 26.0.0, compatible SDK is …”，与项目既有卡片一致即可（仅 WARN）。
- 静态卡片别用 `@State` 承接推送字段；`aboutToAppear` 只跑一次，**要随数据变化的列表在 build 里解析**（用 raw 字符串 + 缓存兜住重复 JSON.parse）。
- 卡片根容器给 `borderRadius` + 深浅两套底（`#FFFFFF`/`#000000`），宫格用浅灰/深灰格底（`#F5F5F7`/`#1C1C1E`）区分层次。

## 六、验证（本地 CI 式）

```bash
export JAVA_HOME="/c/Program Files/Huawei/DevEco Studio/jbr"
"…/tools/node/node.exe" "…/tools/hvigor/bin/hvigorw.js" \
  --mode module -p product=default -p module=entry@default assembleHap --no-daemon
# 看 CompileArkTS 是否 0 错误（PackageHap 失败常见于本机 java.dll 注册表问题，非代码问题）
```
