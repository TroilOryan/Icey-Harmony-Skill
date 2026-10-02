# 模板文件全图（harmony-app-template）

> 路径简写：
> - `<ETS>` = `entry/src/main/ets`
> - 模板工程根：优先用 **Skill 内置副本** `<skill>/assets/template/`（可移植，换机器即用）；
>   扩展已有 App 时则指用户当前工程根。
> - 目标 SDK：API 26（HarmonyOS 6.1.0），compatibleSdkVersion 6.1.0(23)

## 1. 工程配置

| 文件 | 职责 | 改这个项目要动哪里 |
|---|---|---|
| `AppScope/app.json5` | bundleName / vendor / versionCode(N) / versionName / 图标 / 应用名 | 新建项目必改 |
| `build-profile.json5` | targetSdkVersion 26、compatibleSdkVersion `6.1.0(23)`、runtimeOS | 一般不改 |
| `entry/build-profile.json5` | `apiType: stageMode` | 不改 |
| `entry/src/main/module.json5` | Ability 配置、`ohos.arkui.UIMaterial.state=enable`（沉浸光感材质）、`pages: $profile:main_pages`、`orientation: auto_rotation_restricted`、`FILE_ACCESS_PERSIST` 权限 | 加权限/加 Ability 时改 |
| `entry/src/main/resources/base/profile/main_pages.json` | 路由页清单（当前只有 `"App"`；子页走 NavPathStack 不在此登记） | 加二级独立 @Entry 页才改 |
| `hvigor/hvigor-config.json5`、`hvigorfile.ts`、`entry/hvigorfile.ts` | 构建插件接入（不能被修改） | 不改 |

## 2. 骨架层（只允许放全局装配逻辑）

| 文件 | 行数 | 职责 |
|---|---|---|
| `<ETS>/App.ets` | 114 | @Entry 根：`windowWidth/Height/IsLandscape` 广播、主题初始化、系统栏字色、返回手势（顶层=最小化） |
| `<ETS>/entryAbility/EntryAbility.ets` | 227 | 初始化链路（各 init 独立 try-catch）、全屏窗口、SafeArea 计算与刷新、`startupReady`（UI 优先不阻塞）、前后台信号、onConfigurationUpdate |
| `<ETS>/layout/Index.ets` | 227 | HdsNavigation + HdsTabs 布局、`navDestinationBuilder` 子页分发、标题栏菜单、根级 AppSheet |

## 3. model 层（状态/数据）

| 文件 | 行数 | 职责 | 关键 API |
|---|---|---|---|
| `model/AppRouter.ets` | 78 | 全局 NavPathStack 单例 | `getInstance()` / `setPathStack` / `push(name, param?)` / `pop` / `popTo` / `replace` / `getLastParam()`，含重复页拦截 |
| `model/ThemeManager.ets` | 106 | 深浅色主题 + 色板 | `ThemeManager.colors.*`、`isDark`、`opaqueBackground`、`applyThemeMode(themeMode, sysCM, hasCustomBg, bgIsLight)`、`bumpVersion()` |
| `model/SettingsManager.ets` | 173 | preferences 持久化 | `init/waitReady/saveNow`、`setExampleSwitch/setHandedness/setMaterialLevel/setThemeMode`、`applyColorMode` |
| `model/SafeArea.ets` | 40 | 安全区读写 | `SafeArea.top/bottom/left/right`、`set/init` |
| `model/TitleBarStyles.ets` | 167 | 标题栏配置工厂 | `buildHomeTitleBar(title, materialLevel)`、`buildSubPageTitleBar(title, transparentScrollMask, maskExtraHeight, scrollEffect, backIconColor)`、`buildDetailTitleBar(icon, onAction, backIconColor)` |

`ThemeColors` 色板字段：`background / surface / textPrimary / textSecondary / accent / tabBarBg / tabBarActive / tabBarInactive / divider / cardBg / placeholderBg / fieldBorder`。

## 4. pages 层

| 文件 | 行数 | 说明 |
|---|---|---|
| `pages/HomeTab.ets` | 97 | Tab 页范本：加载中/空态/内容三分支、root Column `layoutWeight(1)`、首 ListItem 顶部留白 |
| `pages/SettingsTab.ets` | 121 | 设置主页范本：SettingsGroup 导航组 + GlassCard 开关组 + 值选择组；`aboutToAppear` 复位 scroller |
| `pages/subPages/SettingsSubPage.ets` | 113 | **子页标准模板**：SubPageScaffold + SettingsGroupCard + 手动 Divider + 三类设置项 |
| `pages/subPages/AboutPage.ets` | 114 | 关于页：版本号（bundleManager）、更新日志入口、运行日志弹窗（AppLogger.subscribe） |
| `pages/subPages/HomeDetailPage.ets` | 96 | 详情页演示（子组件 pop 返回） |

## 5. components 层（每个组件独占一个目录）

| 目录 | 行数 | 组件 | 用法要点 |
|---|---|---|---|
| `SubPageScaffold/` | 95 | 子页脚手架 | `{ title }` + content；`embedded: true` 用于一多宽屏右栏（不渲染 NavDestination 壳） |
| `AppSheet/` | 209 | 统一弹窗宿主 | 窄屏 bindSheet / 宽屏居中 dialog；props：`show`(@Link)、`group`、`dismissible`、`detents`、`showClose` |
| `SheetContainer/` | 123 | 弹窗内容容器 | `{ title, titleExt?, plain?, titleEditIcon? }`；内置横竖屏限高（横 0.55×窗高 / 竖 0.75×窗高，最小 180） |
| `ConfirmSheet/` | 86 | 二次确认（@ComponentV2 + CustomContentDialog） | `show / title / message / confirmText / danger / onConfirm / onDismiss` |
| `OptionSheet/` | 72 | 选项列表（@CustomDialog） | 配 `CustomDialogController` 使用；推荐 open 前重建 controller |
| `SettingItem/` | 160 | 单行设置项 | `title/subtitle/icon/iconBg/isSwitch/switchValue/value/loading/hasChevron/withMenu/isSelected/vipIcon/vipDisabled` |
| `SettingsGroup/` | 57 | **主页**导航分组卡（无标题，项间自动 Divider 左缩进 52） | `{ entries: SettingsGroupEntry[], selectedId?, onEntryTap }` |
| `SettingsGroupCard/` | 39 | **子页**分组卡（标题在卡片上方，项间分隔线由调用方插） | `{ title }` + content |
| `GlassCard/` | 26 | 毛玻璃卡片（有自定义背景时透出） | content 插槽，自带 `margin({left:16,right:16,top:12})` |
| `AppSwitch/` | 49 | 自绘开关（规避系统 Toggle 滑块偏移） | `{ isOn, onToggle }`，46×26 |
| `EmptyState/` | 42 | 空态占位（图 + 主副文案） | `{ message, subMessage?, imgSize?, fill?, paddingTop? }` |
| `MarqueeText/` | 63 | 跑马灯（超宽才滚） | — |
| `SFIcon/` | 21 + 27 | SVG 图标渲染 + 名常量表 | `SFIcon({ name: SFIcons.sf_xxx, fontSize, fontColor })` |

## 6. services 层（非 UI，纯函数/静态类）

| 文件 | 行数 | 职责 |
|---|---|---|
| `services/AppLogger.ets` | 285 | 环形缓冲 500 条 + hilog 透传 + 调试模式实时落盘 `Download/<包名>/logs/` + 导出 picker + subscribe 实时刷新 |
| `services/WindowHelper.ets` | 96 | 状态栏/导航条字色、常亮、沉浸显隐、屏幕圆角 |
| `services/SheetManager.ets` | 72 | 弹窗注册表：`register/unregister/closeGroup/closeAll/openCount` |
| `services/AppGlobalContext.ets` | 20 | 全局 UIAbilityContext 持有（service 层/后台 intent executor 用） |
| `services/ChangelogManager.ets` | 84 | 更新日志：`init/shouldShow/markSeen/currentVersion/changelogEntries`；按 versionCode 每次版本更新弹一次；内容来自 `rawfile/changelog.txt` |
| `services/FilePermission.ets` | 166 | fileShare persist/activate（分批 200 + 13900001 明细处理）；`setActivateDonePromise/waitActivateDone` |
| `services/FormatUtils.ets` | 82 | 时间格式化等纯函数 |

## 7. 资源

```
AppScope/resources/base/media/       # background.png / foreground.png / layered_image.json（App 图标）
entry/src/main/resources/base/
├── element/color.json               # start_window_background = #F2F3F4
├── element/string.json              # module_desc / EntryAbility_desc / EntryAbility_label
├── media/                           # 26 个 *.svg + empty.png + layered_image.json
└── profile/main_pages.json
entry/src/main/resources/rawfile/
└── changelog.txt                    # 更新日志正文（每行一条，空行与 # 注释跳过）
# fonts/sficons_harmony.ttf         # ~9.5MB，Skill 内置副本中已排除（代码零引用，不影响构建）
```

## 8. AppStorage 全局键（权威清单）

| 键 | 类型 | 写 | 读 |
|---|---|---|---|
| `safeAreaTop/Bottom/Left/Right` | number | EntryAbility → SafeArea.set | 所有页面 |
| `windowWidth/windowHeight` | number | App.ets | 一多布局、SheetContainer |
| `windowIsLandscape` | boolean | App.ets | SheetContainer |
| `themeIsDark` | boolean | ThemeManager | 任意 |
| `themeColorsVersion` | number | ThemeManager.bumpVersion | **所有取色处** |
| `dataLoaded` | boolean | startupReady | 列表页（防闪空态） |
| `appInBackground` | boolean | Ability 前后台 | **状态**查询（动画/轮询） |
| `appBackgrounded` | number | Ability onBackground | AppSheet（**事件版本号**，只增） |
| `settings_exampleSwitch/handedness/materialLevel/themeMode/customBgUri` | bool/num/str | SettingsManager.fillAppStorage | UI `@StorageLink` |
| `customBgLoaded` | boolean | （主项目背景模块） | SubPageScaffold 淡入判定 |
| `sheetReopen` | number | 外部触发 | AppSheet 先关再开 |

## 9. 编码规范（模板自身遵守）

- 每个模块顶部用 `///` 写职责说明与实战注记；`const TAG = '<模块名>'` 用于 hilog
- 中文注释允许出现在 .ets 中；**禁止**在 JSON/JSON5 之外做任何中文硬编码资源（文案应走 $r）
- 所有 Manager / Helper 为**纯静态类**（`Cls.staticFn()` 调用），只有 `AppRouter` 用 `getInstance()` 单例
- 颜色禁止硬编码 → 一律 `ThemeManager.colors.*`；尺寸禁止硬编码留白 → 一律 `SafeArea.*`
- 组件单文件建议 < 300 行，超出即拆子组件
