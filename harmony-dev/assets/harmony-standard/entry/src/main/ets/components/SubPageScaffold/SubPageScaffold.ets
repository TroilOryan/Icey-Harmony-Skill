/// 子页面脚手架（HdsNavDestination + 标题栏 + 自定义背景图）
/// 统一子页面结构：HdsNavDestination(titleBar) 内 Stack{背景图 + 内容}
/// 复用：SearchPage / MediaLibrarySettings / AppearanceSettings 等设置子页
/// 用法：SubPageScaffold({ title: '界面' }) { 内容 }
///   .bindSheet(...) // 弹窗挂在 SubPageScaffold 返回的组件上（调用方链式）
/// embedded 嵌入模式（一多宽屏右栏）：不渲染 NavDestination 壳，只渲染内容区（背景），
/// 由 Settings 宽屏右栏提供标题/容器——子页组件原样复用，窄屏全屏/宽屏嵌入两套布局共用同一份内容
import { HdsNavDestination, HdsNavigationTitleBarOptions, HdsNavigationMenuItemOptions } from '@kit.UIDesignKit';
import { ThemeManager } from '../../model/ThemeManager';
import { SettingsManager } from '../../model/SettingsManager';
import { buildSubPageTitleBar } from '../../model/TitleBarStyles';

@Component
export struct SubPageScaffold {
  @Prop title: string = '';
  @Prop embedded: boolean = false;
  @BuilderParam content: () => void;

  /// **子页层数广播（修"进子页后主页搜索框不消失"）**
  /// 主页搜索框挂在 `HdsNavigation` 的 `bottomBuilder`（**标题栏内部**），
  /// 而子页跑在 Navigation 的 `NavDestination` 里 —— 子页自己的标题栏与
  /// 主页标题栏是**两套**，故必须显式告诉 Index"有子页在栈上"⇒ 主页不渲染搜索框。
  ///
  /// ⚠️ **为什么用 AppStorage 计数、而不是在 AppRouter.push/pop 里改标志**：
  ///   ① `push` 只有 1 个入口（好办），但 **`pop` 有 13 处调用点**，还混着系统手势返回、
  ///      侧滑返回、`popToIndex` 等路径 ⇒ 手工维护必然漏；
  ///   ② `SubPageScaffold` 是**全部 15 个子页**的唯一外壳 ⇒ 在它的生命周期里计数，
  ///      覆盖率天然 100%，且与"谁 push/pop、怎么返回"完全无关。
  ///
  /// ⚠️ **必须用 `embedded` 区分**：宽屏（2in1）下右栏子页是 `embedded: true`，
  /// 它**没有独立 NavDestination 壳**、也不会盖住主页 chrome ⇒ 不能计入
  /// （否则宽屏下搜索框会被误隐藏）。
  aboutToAppear(): void {
    if (!this.embedded) {
      AppStorage.setOrCreate<number>('subPageDepth', (AppStorage.get<number>('subPageDepth') ?? 0) + 1);
    }
  }

  aboutToDisappear(): void {
    if (!this.embedded) {
      const d: number = AppStorage.get<number>('subPageDepth') ?? 0;
      AppStorage.set<number>('subPageDepth', d > 0 ? d - 1 : 0);
    }
  }

  /// **可选：标题栏底部扩展区 builder（2026-09-08 搜索页专用）**
  /// Hds 从 6.0.0(20) 起支持 titleBar content.bottomBuilder，官方对该扩展位的描述原文就是
  /// "标题栏底部区域增加搜索框、页签"。关键收益：它**位于 Navigation/NavDestination 标题栏
  /// 区域内** → 通用属性 systemMaterial 真正生效；同样的搜索框放在内容区 List 里则会打
  /// `Material inactive: out of scope`，材质从未生效（沉浸光感铁律，见 CLAUDE.md）。
  /// ⚠️ 为什么不是第二个 @BuilderParam：**尾随闭包要求组件内有且仅有一个 @BuilderParam**，
  /// 本组件已有 content 一个，再加一个会破坏其余 11 个子页 `SubPageScaffold({...}) { }` 的
  /// 尾随闭包写法——故用普通成员（构建期静态配置，不需要响应式）承载 builder 引用。
  titleBottomBuilder?: (() => void) = undefined;
  /// bottomBuilder 区域高度（vp）：必须与调用方列表顶部留空常量同值同改（搜索页
  /// TITLE_BOTTOM_SEARCH_VP = 56，媒体库 MediaLibrary TITLE_SEARCH_BAR_VP = 56）
  titleBottomHeight: number = 56;
  /// **可选：标题栏右上角标准 menu 项（2026-09-11 会员页菜单按钮）**
  /// 透传给 buildSubPageTitleBar 的 menuItems——Hds 标题栏 menu.value 数组（原生对齐，
  /// 零手工定位）；默认 undefined = 无菜单（其余子页零影响）
  titleMenuItems?: HdsNavigationMenuItemOptions[] = undefined;
  /// 子页路由栈回调（透传 HdsNavDestination onReady 的 pathStack，供需要 pop 的子页如 SearchPage 使用）
  onPathStack: (stack: NavPathStack) => void = () => {};
  @StorageLink('settings_customBgUri') @Watch('onCustomBgUriChange') customBgUri: string = '';
  /// 自定义背景模糊（0-100 无极，默认 50）：作用于子页背景图 .blur()
  @StorageLink('settings_customBgBlur') customBgBlur: number = 50;
  /// 自定义背景图是否已解码完成（淡入过渡用：见 body() 背景 Image）
  @State bgReady: boolean = AppStorage.get<boolean>('customBgLoaded') ?? false;
  /// **沉浸光感挡位（2026-09-24 接入实时）**：订阅挡位并透传 buildTitleBar —— 挡位变化触发
  /// build 重跑 → titleBar 属性重应用（与 Index 主页标题栏/底栏同机制）。此前子页标题栏
  /// 只在进页时构建一次，页面开着切挡位不实时（用户反馈"切换的时候顶部标题栏按钮没有实时更新"）
  @StorageLink('settings_materialLevel') materialLevel: number = 10;

  /// 换背景图（2026-09-15 根治白屏）：不复位 bgReady，新图直接以 opacity 1 渲染；
  /// 冷启动首帧仍走 onComplete 淡入
  onCustomBgUriChange(): void {
  }
  /// 主题版本信号：系统深浅切换（onConfigurationUpdate）时已打开的子页也要刷新背景
  /// （Index tab 页订阅了会重建，但 push 的子页是独立路由页，不随 Index 重建——必须自己订阅）
  @StorageLink('themeColorsVersion') themeColorsVersion: number = 0;

  /// 内容主体（两种模式共用：背景图 + 内容）
  /// 顶部不做固定 Blank 避让——完全对齐设置主页/媒体库方案：List 视口顶到屏幕顶，
  /// 内容滚动时自然滑进标题栏区域（透明标题栏 + 滚动模糊渐变盖住，即"自然的滚动上去"）；
  /// 初始贴顶由调用方 List 第一个 ListItem 的 Blank（embedded ? 12 : SafeArea.top+72）承担
  @Builder
  body() {
    Stack() {
      // 自定义背景图（页面内底层）。key 稳定，父重建时 Image 复用不重新加载（避免闪烁）
      if (this.customBgUri) {
        Image(this.customBgUri)
          .width('100%').height('100%')
          .objectFit(ImageFit.Cover)
          // 自定义背景高斯模糊（0-100 → 0~32vp；0 时不加模糊开销）
          .blur(SettingsManager.customBgBlurRadius(this.customBgBlur))
          // **换壁纸强制重建（2026-09-15 用户：更换自定义背景不实时更新）**：固定 key
          // 导致换 uri 时组件复用不刷新 src。全项目背景页（Index/Settings/Albums 等）
          // 均用 themeColorsVersion 跟随 key（resolveEffectiveCustomBg 换图必 +1）——
          // key 变 → Image 重建 → 读当前 customBgUri 显示新图；父重建 version 不变不乱闪。
          .key('subp_bg_' + this.themeColorsVersion)
          // **淡入过渡（2026-08-29 用户反馈"首次进子页背景闪一下"）**：冷启动首次进子页
          // 时图片要现场解码 → 解码完成瞬间出现 = 闪。onComplete 后 300ms 淡入
          // （属性动画，不与 animateTo 同用）；换背景图 → bgReady 复位重新淡入
          .opacity(this.bgReady ? 1 : 0)
          .animation({ duration: 300, curve: Curve.EaseOut })
          .onComplete(() => {
            this.bgReady = true;
          })
      }
      // 沉浸光感：由**各卡片自身的 MaterialLayer 承载层**绘制（Toggle 绕过法，内容区任意
      // 位置可用）→ 本骨架不再包裹 Tabs 宿主，全部子页（含 embedded 宽屏右栏）零改动生效。
      // API<26 时承载层不渲染，卡片自动回落毛玻璃。
      Column() {
        this.content()
      }
      // 高度 calc(100% + 10vp) 补偿负 margin：margin top -10 让 Column 上移 10vp，
      // 若高度仍 100% 则底部露出 10vp 空隙透出 NavDestination 默认背景；增高后底部贴底不露出
      .width('100%')
      .height(this.embedded ? '100%' : 'calc(100% + 10vp)')
      // 补偿 HdsNavDestination 内容区顶部偏移：真机实测子页比主页（HdsTabs）内容低约 22vp。
      // 2026-09-24 用户反馈子页首卡仍被标题栏滚动模糊带（下延 28 → 132）压顶 → 调用方 Blank
      // 同步 +8（SafeArea.top+64 → +72），内容顶 124 → 132 恰出模糊带下缘；-10 折中保持不变。
      // embedded 宽屏右栏无 NavDestination 壳，无此偏移，不加。
      .margin({ top: this.embedded ? 0 : -10 })
      .backgroundColor(this.customBgUri ? Color.Transparent : ThemeManager.colors.background)
    }
    // Stack 背景色兜底（防负 margin 边缘/自定义背景加载间隙透出 NavDestination 默认背景）
    .backgroundColor(this.customBgUri ? Color.Transparent : ThemeManager.colors.background)
    .width('100%')
    .height('100%')
  }

  /// 构建标题栏配置：默认子页统一样式；调用方传了 titleBottomBuilder 时把它挂到
  /// Hds 标题栏 content.bottomBuilder —— 只有挂在这里，搜索框的沉浸光感材质才生效。
  /// （embedded 宽屏右栏无 NavDestination 壳，此扩展位用不上）
  private buildTitleBar(): HdsNavigationTitleBarOptions {
    // 透传 this.materialLevel：读取发生在 build 内 → 挡位变化被框架追踪 → titleBar 重应用
    const opts: HdsNavigationTitleBarOptions =
      buildSubPageTitleBar(this.title, true, 28, true, ThemeManager.colors.textPrimary, undefined,
        this.titleMenuItems, this.materialLevel);
    if (this.titleBottomBuilder !== undefined && opts.content !== undefined) {
      opts.content.bottomBuilder = {
        builder: this.titleBottomBuilder,
        height: this.titleBottomHeight,
      };
    }
    return opts;
  }

  build() {
    if (this.embedded) {
      // 嵌入模式（一多宽屏右栏）：无 NavDestination 壳，纯内容
      this.body()
    } else {
      HdsNavDestination() {
        this.body()
      }
      // **主题色实时同步**（2026-08-16：@StorageLink 引用依赖——version+1 → 骨架重建 →
      // body slot 重跑读新 ThemeManager.colors，覆盖所有子页；.key 变化强制重建）
      .key('tv_' + this.themeColorsVersion)
      // 透明滚动蒙层（无色块）+ maskExtraHeight 28（对齐媒体库）——保留 Hds 滚动模糊效果，
      // 只去掉 80% 不透明白/黑色块的遮挡
      .titleBar(this.buildTitleBar())
      .hideBackButton(false)
      .titleMode(100) // HdsNavDestinationTitleMode.MINI（Hds 枚举 release 打包无导出，用数值 100）
      .ignoreLayoutSafeArea([0], [0]) // LayoutSafeAreaType.SYSTEM=0 / LayoutSafeAreaEdge.TOP=0（枚举传 Hds 同样 release 解析失败）
      .onReady((ctx: NavDestinationContext) => {
        this.onPathStack(ctx.pathStack);
      })
      // **子页返回拦截点（预留）**：需要"返回手势先关浮层/收面板再 pop"时挂
      // .onBackPressed((): boolean => {...})——返回 true 吞掉本次返回、false 交回 Hds 栈
      // 默认 pop。子页（NavDestination）返回由 HdsNavigation 栈自动处理，不冒泡到 App.onBackPress。
    }
  }
}
