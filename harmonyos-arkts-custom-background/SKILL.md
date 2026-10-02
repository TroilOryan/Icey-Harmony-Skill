---
name: harmonyos-arkts-custom-background
description: HarmonyOS/ArkTS 应用接入自定义背景（壁纸）：深浅色双槽位壁纸、背景模糊度滑块、PhotoViewPicker 选图后**落沙箱文件 + 存 file:// URI**（⚠️ 绝不能存 base64，preferences 有 8192 字节上限）、壁纸透出的半透明背景机制、卡片毛玻璃化、弹窗不透底。触发词：自定义背景、壁纸、背景图、customBg、背景模糊、深浅色分别设置、毛玻璃、opaqueBackground、PhotoViewPicker 取消后界面变白、**壁纸失效/重启后壁纸没了**。
agent_created: true
---

# HarmonyOS ArkTS 自定义背景（双槽位壁纸 + 模糊度）接入

适用：给 HarmonyOS（ArkTS/ETS，DevEco）应用接入「自定义背景图」功能，要求深浅色分别设置 + 模糊度可调。

参考实现（成熟版）：Icey-Player-Harmony `services/CustomBgManager.ets` + `model/SettingsManager.ets` + `model/ThemeManager.ets`。
移植范例：Icey-Days（倒数日），2026-09-13 接入。

## 一、数据模型（四键一开关）

| 键 | 语义 |
|---|---|
| `settings_customBgEnabled` | 开关（默认 false） |
| `settings_customBgLightUri` | 浅色模式壁纸 |
| `settings_customBgDarkUri` | 深色模式壁纸 |
| `settings_customBgBlur` | 模糊度 0-100（默认 50） |
| `settings_customBgUri` | **派生键 = UI 唯一消费键** |

**核心设计：派生键**。`resolveEffectiveCustomBg()` 按当前 `ThemeManager.isDark` 从对应槽位取值（开关关则空串）写入 `settings_customBgUri`，UI 显示层（背景图渲染、卡片毛玻璃判断）只读这一个键 —— 一处判断，全应用统一，不用每处都写 `enabled && slot` 逻辑。

**模糊度换算**：`0-100 → 0 ~ MAX_BLUR_RADIUS(32vp)`，`0` 直接返回 `0`（不给"不模糊"付全屏高斯开销）。

## 二、壁纸透出机制（关键，别给每页加图）

不要给每个页面单独加背景 Image。正确做法：**自定义背景生效时把 `ThemeManager.colors.background` 改成半透明**（深 `#B3000000` / 浅 `#B3F1F3F5`，约 70% 主题色覆盖），只在这两处放 Image：

1. 外壳根 Stack 最底层（Index / App.ets）—— 全屏 Cover。
2. 子页脚手架（SubPageScaffold 之类）—— 带 `.key('subpage_custom_bg')` 保证组件重建时 Image 复用不重新解码。

其余页面本来就写 `backgroundColor(ThemeManager.colors.background)` → **零改动自动半透明透出壁纸**。

### 三个必须处理的坑

1. **`colors.background` 是 static 非响应式**：它变了 UI 不会自己刷新。开关/槽位/深浅任一变更后，除了重算值还必须广播（`AppStorage.set('themeColorsVersion', +1)` 之类）触发全应用重建。
2. **`opaqueBackground` 必须恒实色**（弹窗 / 输入区 / "防露白"外层容器）。这些地方若用 `colors.background`，自定义背景一开弹窗就跟着半透明透底。定义：`isDark ? '#000000' : '#F2F3F4'`。
3. **`customBgEffective()` 直接读 AppStorage**，不要 import SettingsManager —— SettingsManager 通常已 import ThemeManager，反向 import 会成环。

## 三、卡片毛玻璃（否则壁纸被整片实色卡挡死）

卡片容器统一两行：

```ts
.backgroundColor(ThemeManager.cardBgOrTransparent(hasCustomBg))   // 生效 → Color.Transparent
.backgroundBlurStyle(ThemeManager.cardBlurStyle(hasCustomBg))     // 生效 → BlurStyle.COMPONENT_REGULAR，否则 NONE
```

需要毛玻璃化的典型位置：设置分组卡、用户卡、列表/宫格事件卡、各 Tab 的卡片容器、详情页信息卡。

**卡片组件加 `@Prop glassOn: boolean = true`**：弹窗内的预览卡传 `false` —— 弹窗底是实色，玻璃化会改变弹窗观感。

## 四、选图链路（Copy 可用）

```
PhotoViewPicker.select → photoUris[0]
  → fileIo.openSync(uri, READ_ONLY) 拿 fd
  → image.createImageSource(fd)
  → getImageInfo() 取原图尺寸
  → createPixelMap({ desiredSize: {720, 等比} })
  → image.createImagePacker().packing(pm, { format: 'image/jpeg', quality: 80 })   // 返回 ArrayBuffer
  → 写沙箱文件 <filesDir>/bg/wallpaper_<slot>.jpg
     （openSync 必须带 TRUNC：新图比旧图小则不截断会留旧尾部字节 → JPEG 垃圾）
  → fileUri.getUriFromPath(filePath) 得 'file://xxx'（约 120 字符）写槽位
  → resolveEffectiveCustomBg()
```

内存注意：`packer.release()` / `pm.release()` / `source.release()` + `finally` 里 `fileIo.closeSync`。

### 🔴 绝不能存 base64（2026-10-02 P1 事故：用户报「自定义壁纸失效」）

**老版本（本技能旧版也是这样写的）把 JPEG 的 base64 data URI 直接塞进 preferences —— 这条路是死的。**
死因是官方硬约束，不是概率问题：

> **`preferences` 的 Value 为 string 时长度不得超过 8192 字节**（UTF-8）
> 超长 `putSync` 直接抛 `Parameter error. The type of 'value' must be ValueType.`

而 720w JPEG q80 ≈ 30~80 KB → base64 膨胀 4/3 ≈ **40~110 K 字符**，**必然超限**。
于是 `putSync` 每次必抛 → 被 catch 吞掉 → **槽位从未真正持久化**。表现极具欺骗性：

| 时刻 | 现象 |
|---|---|
| 选完图当次运行 | 内存态 + AppStorage 有值 ⇒ 壁纸**显示正常**（"看起来能用"） |
| 重进 App | `getSync` 读回空串 ⇒ 槽位空 ⇒ **壁纸消失** |

⇒ 排查"壁纸失效"时，**先确认值到底有没有存下来**，而不是去翻显示链路（渲染层往往一点没坏）。

**修法**：图片字节落**沙箱文件**（无长度限制、无权限依赖），preferences 里只留一行
`file://` URI。`Image()` 与 `image.createImageSource()` 都直接吃 `file://` URI ⇒ **显示侧零改动**。

此外加**显式长度预检**（`save()` 里判 `value.length > 8192` 就报 error 并放弃写入）：
让"存了却没生效"的问题在运行日志里一眼可定位，不再静默丢值。

**铁律**：`preferences` 只放**轻量标量** —— 开关 / 档位 / 短字符串 / 路径 / `file://` URI。
图片、长 JSON、二进制**一律落沙箱文件**，preferences 只存路径。

⚠️ 路径转 URI 用官方 `fileUri.getUriFromPath(path)`，**不要手拼 `'file://' + path`**
（后者在含空格/中文的路径形态下不稳，也不符合 `file://bundleName/path` 规范）。

⚠️ **事故的代价**：旧链路的字节在 catch 分支里就被丢弃了 ⇒ 修复**无法恢复用户已设的那张图**，
需让用户**重新选一次**（此后永久有效）。换实现时记得提前告知。

### 必踩的坑：picker 关闭后校正主题

`PhotoViewPicker` 是**应用内模态**（不触发 onForeground），打开/关闭可能误报 `colorMode`（报 LIGHT）→ 主题色板跳浅。现象：**取消选图后界面变白但导航栏/标题栏仍深色**。

修法：picker 返回后（无论成功/失败/取消）都用**不受 app `setColorMode` 污染**的通道读真实系统色：

```ts
context.resourceManager.getConfiguration().then((value: object) => {
  const cm = (value as Record<string, number>)['colorMode'];
  if (cm === 0 || cm === 1) {
    SettingsManager.noteSystemColorMode(cm);      // 修正系统色缓存
    /* 按 cm 重算 isDark，变了才 ThemeManager.applyThemeMode(...) */
  }
});
```

## 五、设置页 UI 结构

一个开关行 → 开关打开时追加：

- 浅色模式壁纸行 / 深色模式壁纸行：缩略图（未设置则不显示、不占位）+ 标题 + 右侧"已设置/未设置" + 下拉箭头；点整行弹菜单（更换 / 已设置时多一项清除）。
- 背景模糊行：标题 + 右侧数值（0 显示「关」，其余 `xx%`）+ 下方 `Slider({min:0,max:100,step:1, style: SliderStyle.OutSet})`（`trackThickness(4)` / `blockSize 18×18`）。

两个副作用坑：

1. **`@Builder` 按值传参非响应式**：`bindMenu` 里的缩略图 uri 必须经组件方法读 `this.xxxUri` 建立依赖，否则"设置完仍显示未设置"。
2. **`bindMenu` 必须挂原生 Row**，挂自定义组件外层点不生效。菜单 `placement` 左对齐整行时用 `BottomRight`（贴右侧值区弹出，`BottomLeft` 会离点击位置太远）。
3. **Slider 拖动实时预览、松手才落盘**：`onChange` 里直接写 `@StorageLink` 变量（立即回写 AppStorage → 各处 `.blur()` 跟随），仅 `SliderChangeMode.End` 时落盘。
4. 切换开关/槽位后需要广播重建（见二·1）。

## 六、启动与淡入

- 启动后 300ms（不阻塞首屏）把**当前槽位 + 另一槽位**各 `createImageSource → createPixelMap` 预热一次（解码结果进系统缓存），消除"首次切页背景空一拍"。
- 背景 Image 用 `.opacity(bgReady ? 1 : 0).animation({duration: 300, curve: Curve.EaseOut})` 淡入（属性动画，不与 `animateTo` 同用）；`@Watch` 监听 uri 变化时复位 `bgReady`。
- 全局标记（如 `customBgLoaded`）：根层 `onComplete` 置 true，子页 `bgReady` 初值读它 → 已加载则零淡入零闪烁。

## 七、验收清单

1. 开开关 → 选浅色壁纸 → 切浅色主题看效果；切深色主题应回落实色（该槽位空）。
2. 再选深色壁纸 → 深浅切换应两张壁纸互换。
3. 拖模糊滑块 → 拖动过程实时变化，松手后重启仍保持。
4. 取消选图 → 主题不跳色（不被误报污染）。
5. 弹窗（新增/编辑/输入昵称）底仍是实色，不透出壁纸。
6. 卡片显示为毛玻璃而非实色块（否则壁纸看不见）。
