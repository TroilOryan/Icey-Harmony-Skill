# HarmonyOS App 模板工程

生产项目实战基建沉淀的通用模板：新建项目直接复制本工程改名，即获得
HDS 导航/标题栏/弹窗/设置组件/日志/持久化/主题/路由/安全区等全部基建，不再反复操心基础表现。

> 目标 SDK：API 26 (HarmonyOS 6.1.0)，compatibility 23。DevEco Studio 打开后按提示
> 关联 SDK 即可构建。

## 一、开箱即用清单

### 导航与页面结构
| 基建 | 文件 | 说明 |
|---|---|---|
| HdsNavigation + HdsTabs 主布局 | `layout/Index.ets` | 底部悬浮导航（miniBar 占位可删）、tab 瞬时切换、预加载全 tab、逐层透明透出背景 |
| 滚动渐变模糊标题栏 | `model/TitleBarStyles.ets` | `buildHomeTitleBar`（主页大标题）/ `buildSubPageTitleBar`（子页返回）——GRADIENT_BLUR + ADAPTIVE 材质 + 主题色文字 |
| 子页脚手架 | `components/SubPageScaffold/` | HdsNavDestination + 标题栏 + 自定义背景 + 宽屏 embedded 模式，一行代码建子页 |
| 全局路由 | `model/AppRouter.ets` | 单例 NavPathStack，任意深层组件 push/pop，重复页面拦截 |
| 安全区 | `model/SafeArea.ets` | 全屏布局后手动避让（含挖孔合并 TYPE_CUTOUT、旋转/avoidAreaChange 动态更新） |

### 组件库
| 组件 | 说明 |
|---|---|
| `SettingItem` | 设置项：圆形彩底图标 + 标题/副标题 + 右侧开关/值/箭头/加载态 |
| `SettingsGroup` | 设置分组卡（圆角 20 + 项间分隔线左缩进 52，对齐官方 NavigationSettings）——**主页导航组**用 |
| `SettingsGroupCard` | **带分组标题**的子页卡片（标题在卡片上方 13pt 次级色；项间分隔线由调用方手动插 Divider 0.5/左缩进 12）——**子页内容组**用 |
| `AppSwitch` | 自绘开关（系统 Toggle 滑块渲染偏移 bug 规避） |
| `GlassCard` | 毛玻璃卡片（自定义背景时透出，无背景实色） |
| `AppSheet` | 统一弹窗宿主：手机 bindSheet / 宽屏(≥600vp 或平板)自动切窗口级居中 dialog；同 group 互斥；退后台自动关 |
| `SheetContainer` | 弹窗内容容器（标题 + 卡片 + 横竖屏限高 + Scroll） |
| `ConfirmSheet` | 二次确认弹窗（CustomContentDialog，danger 红色按钮） |
| `OptionSheet` | 选项列表弹窗（@CustomDialog + 勾选态） |
| `EmptyState` | 空状态占位（图 + 主/副文案） |
| `MarqueeText` | 跑马灯文本（超宽才滚） |
| `SFIcon` | SVG 图标组件（`$r('app.media.<name>')` + fillColor 动态变色；加图标 = 放 svg + 加 SFIcons 常量） |

### 服务层（非 UI）
| 服务 | 文件 | 说明 |
|---|---|---|
| 设置持久化 | `model/SettingsManager.ets` | preferences 增量写 + 300ms 防抖 + saveNow 双保险；AppStorage 响应式回填 |
| 运行日志 | `services/AppLogger.ets` | 内存环形缓冲 500 条 + hilog 透传 + 调试模式实时落盘 Download/<包名>/logs/ + 导出 picker |
| 全局 Context | `services/AppGlobalContext.ets` | UIAbilityContext 全局持有（service 层/后台任务用） |
| 系统栏/窗口 | `services/WindowHelper.ets` | 状态栏/导航条字色、常亮、沉浸显隐、屏幕圆角 |
| 弹窗管理 | `services/SheetManager.ets` | 弹窗注册表：同组互斥、退后台统一关闭 |
| 更新日志 | `services/ChangelogManager.ets` | versionCode 判定每次版本更新弹一次；内容外置 rawfile/changelog.txt |
| 文件授权 | `services/FilePermission.ets` | fileShare 持久化/激活（分批 200 条 + 部分失败明细处理） |
| 格式工具 | `services/FormatUtils.ets` | 时间格式化/百分比钳制等纯函数 |

### 工程配置
- `module.json5`：全屏沉浸元数据（UIMaterial.state）、auto_rotation_restricted 旋转、FILE_ACCESS_PERSIST 权限
- `build-profile.json5`：targetSdk 26 / compatibleSdkVersion 6.1.0(23)
- 图标字体 `rawfile/fonts/sficons_harmony.ttf`（SF Symbols 码位移到 BMP 私用区，10MB，可按需删除）
- App 图标 layered_image（占位，自行替换）

## 二、新建项目步骤

1. 复制整个目录到新工程目录，改 `AppScope/app.json5` 的 `bundleName` 和 `AppScope/resources/base/element/string.json` 的 `app_name`
2. DevEco Studio 打开 → 自动关联 hvigor/SDK → build
3. 删掉不需要的部分：
   - 无播放条 → `Index.ets` 删除整个 `miniBar` 配置块和 `miniBarPlaceholder()`
   - 无自定义背景 → 删 `GlassCard`/`SettingsGroup` 里的 `customBgUri` 判定（保留实色分支即可）
   - 无更新日志 → 删 ChangelogManager + AboutPage 对应项 + changelog.txt
4. 在 `EntryAbility.startupReady` 里写你的数据恢复；在 `SettingsManager` 按注释三步加设置项

## 三、设置页分层逻辑（主页分组导航 → 子页具体设置）

标准两层结构（对齐系统设置/HarmonyOS NavigationSettings 规范）：

**主页（SettingsTab）**——只放分组导航 + 少量高频开关：
- `SettingsGroup`（无标题纯导航卡）：条目 id 分发 `AppRouter.push(ROUTE_XXX)` 进对应子页，
  图标 = SFIcon 圆形彩底（iconBg 每项不同色）
- 高频开关直接放主页 GlassCard（如系统设置的 Wi-Fi 开关），低频设置全部进子页

**子页（pages/subPages/，参照 SettingsSubPage.ets）**——具体设置的完整示例：
- `SubPageScaffold({ title: 'xxx' })` 承载（标题栏滚动模糊自动带上）
- 内容用 `SettingsGroupCard({ title: '分组名' })` 分组：**标题在卡片上方**（13pt 次级色），
  卡内 `SettingItem` 排列，项间手动插 `Divider().strokeWidth(0.5).color(ThemeManager.colors.divider).margin({ left: 12, right: 8 })`
- 顶部留白 `SafeArea.top + 64`；尾部留白 `SafeArea.bottom + 40`（滚到底不裁切）+
  `List.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])`
- 开关值链路：子页 `@StorageLink('settings_xxx')` 读 → `onSwitch` 调 `SettingsManager.setXxx(v)`
  → 内存 + AppStorage + 300ms 防抖落盘（重启保持）；加新设置项按 SettingsManager 注释三步
- 新增子页四步：① subPages/ 建组件（SubPageScaffold 包裹）② AppRouter 加 ROUTE_XXX 常量
  ③ Index.navDestinationBuilder 加分发 ④ 主页 SettingsGroup 加条目

## 四、必须遵守的实战铁律（违反必出 bug）

### 启动/恢复
- **UI 优先，永不阻塞**：loadContent 不等 startupReady；数据恢复后台完成，AppStorage 响应式刷新
- 各模块 init 独立 try-catch：一个失败不中断后续（SettingsManager 挂了 → 所有设置静默丢失）
- SettingsManager.init 必须最先；onBackground/onDestroy 必须 saveNow()

### 布局
- 子页 root Column 用 `layoutWeight(1)` 替代 `height('100%')`（后者溢出 ~50vp）
- 禁止 `layoutWeight(1)` + `justifyContent(FlexAlign.SpaceBetween)` 联用（子项高度异常离屏）
- List 视口顶到屏幕顶 + 第一个 ListItem Blank 留白 → 内容自然滑进标题栏模糊带

**标题栏顶部渐变模糊与让开区域（关键配套，四处缺一不可）**：
1. **标题栏配置**：`avoidLayoutSafeArea: true`（标题文字自动下移避让状态栏）+ 组件级
   `.ignoreLayoutSafeArea([0], [0])`（背景/模糊带延伸铺满状态栏区——否则状态栏后面是白条/黑条）
2. **根 Stack**：`.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])`
   让背景绘制延伸到系统栏后面 + `.backgroundColor(ThemeManager.colors.background)` 填充状态栏露出的区域
3. **页面内容让开**：List 第一个 ListItem `Blank().height(SafeArea.top + 64)`
   ——**不要硬编码 112**：公式 = SafeArea.top（状态栏，真机 ≈48，模拟器可能 0）+ MINI 标题栏 56 + 8 间距；
   动态化后换机型/折叠屏自动适配（tab 页与子页同公式，两边始终一致）
4. **滚动模糊带 maskExtraHeight**：28（向下延伸高度）——调小让内容短的页（设置）模糊带
   落在留白区不盖内容；调大则模糊带更长更明显

### HDS
- Hds 枚举用枚举名（compatibility 23 正常导出）；低 API 设备闪退时退数值：
  GRADIENT_BLUR=2、HdsNavigationTitleMode.MINI=2、HdsNavDestinationTitleMode.MINI=100、
  LayoutSafeAreaType.SYSTEM=0、LayoutSafeAreaEdge.TOP=0
- Hds 组件默认背景层会压暗透出的背景图：TabContent/HdsTabs/HdsNavigation 逐层显式透明
- 设置页 aboutToAppear 复位 scroller 到顶部：内容短不可滚时模糊带会常显

### 主题
- ThemeManager.colors 是 static 非响应式：组件 @StorageLink('themeColorsVersion') 触发重建重读
- 弹窗背景用 `ThemeManager.opaqueBackground`（colors.background 自定义背景时是半透明）
- colorMode 判深色用 `=== 0`（DARK=0，不是 2）

### 生命周期
- onConfigurationUpdate 只能放 Ability 级（@Entry 里不是标准回调不会被调）
- onConfigurationUpdate 里**禁止** setColorMode（再次触发回调 → 无限循环几百次）
- applyColorMode 调两次：onCreate（全局）+ onWindowStageCreate（窗口就绪后，否则首帧材质按错误模式解析）
- onForeground 重算 colorMode：系统 picker 打开/取消会触发 onConfigurationUpdate 误报 colorMode → 色板跳浅
- 状态栏显隐触发 avoidAreaChange 而非 windowSizeChange——SafeArea 刷新靠 avoidAreaChange 监听
- 前后台双信号并存、语义勿混用：`appBackgrounded` 版本号（+1，事件驱动 @Watch，AppSheet 关弹窗用）
  + `appInBackground` 布尔（退后台 true / 回前台 false，状态查询用，如动画暂停/恢复）。
  **版本号只增不减永不复位**——复位它会让依赖 +1 增量的 @Watch 永不再触发

### 弹窗
- bindMenu/bindSheet 配置挂原生组件外层（挂自定义组件上不生效）
- 弹窗 show=false 同步时机：onDisappear 后延迟 300ms（立即设会打断关闭动画"回弹"）；
  延迟期间用户重开（show=true）不能再设 false（竞态：刚开的弹窗被自动关）
- 宽屏窗口级 dialog 退后台不自动关：靠 appBackgrounded 信号 +1 统一关闭
- **@StorageLink 绑定不可靠的两种场景（都有实证），保险写法见括号**：
  ① 订阅 class 对象整体替换 @Watch 偶发不触发（必须并挂 number 版本号 @Watch，如 currentMediaVersion）；
  ② 演唱会/全屏模式等特殊渲染下 @StorageLink 值可能长期不更新（关键轮询不能依赖它做守卫，
  改用 media/position 等业务数据双比较快跳）
- 非 @Entry 组件的 onBackPress 不会被系统调用——返回手势统一在 App.ets 判断后广播
  AppStorage 版本号信号，目标组件 @Watch 消费
- 已知待改进（重构方案见主项目 docs/sheet-stack-rework.md）：SheetManager 目前是互斥不是栈
  （无多层返回上一级）；导入进度等状态驱动弹窗 false→true 重建会"关一下又弹出"；
  弹窗操作区规范 = 主操作（填充按钮）在上、副操作（文字按钮）在下纵向排布

### 其他
- AppStorage 是内存态全局（区别 PersistentStorage），重启即丢——持久化一律走 SettingsManager
- @StorageLink 声明未引用不触发重建——跨组件传主题版本用 @Prop 传参
- @StorageLink 初始值不触发 @Watch：组件挂载时状态已 true 的场景，数据重建入口开头链调 +
  aboutToAppear 双保险（否则精放 @Watch 留空 → 白屏）
- es2abc 老解析器对嵌套括号三元解析歧义（`a ? (b ? x : y) : z` 报 ',' expected）——
  **必须纯链式三元**（&& 拍平并列分支，分支数组禁 spread）
- hvigor Windows `[safe-delete]` 报错 = 缓存损坏（构建期间并行编辑/构建所致）——
  清 `entry/build/default/cache/default/default@CompileArkTS` 后前台串行 `--no-daemon` 重建；
  **本项目构建必须前台串行**
- 大列表（千项级）动画铁律：绝不能父级 @State + 定时器驱动整树（全量 rebuild 卡死）——
  动画下放到每条目独立子组件自驱动（组件边界=动画边界）
- WaterFlow：`layoutMode` 是构造参数不是链式方法；`itemsSameSize` 当前 SDK 不存在勿用
- Service 层必须用 AppLogger（console.* 仅 DevEco logcat 可见，不进用户导出日志）
- 自定义字体在 loadContent 回调里注册（否则页面用不上）
- 版本号信号（xxxVersion +1）优于布尔信号：同值 set 不触发 @Watch，+1 恒触发

## 五、目录结构

```
entry/src/main/ets/
├── App.ets                  # @Entry 全局宿主（窗口广播/主题初始化/返回手势）
├── entryAbility/
│   └── EntryAbility.ets     # 启动全链路（init 顺序/全屏窗口/SafeArea/startupReady）
├── layout/
│   └── Index.ets            # HdsNavigation + HdsTabs 主布局 + 子页分发
├── pages/
│   ├── HomeTab.ets          # 首页 tab 示例（列表/空态/加载态）
│   ├── SettingsTab.ets      # 设置 tab 示例（分组卡/开关/值选择）
│   └── subPages/            # 子页示例（SubPageScaffold 用法）
├── components/              # 组件库（见上表）
├── model/                   # 路由/主题/设置/安全区/标题栏样式
└── services/                # 日志/Context/窗口/弹窗管理/更新日志/文件授权/工具
```
