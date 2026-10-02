/// 子页面脚手架（HdsNavDestination + 标题栏 + 自定义背景图）
/// 统一子页面结构：HdsNavDestination(titleBar) 内 Stack{背景图 + 内容}
/// 复用：SearchPage / MediaLibrarySettings / AppearanceSettings 等设置子页
/// 用法：SubPageScaffold({ title: '界面' }) { 内容 }
///   .bindSheet(...) // 弹窗挂在 SubPageScaffold 返回的组件上（调用方链式）
/// embedded 嵌入模式（一多宽屏右栏）：不渲染 NavDestination 壳，只渲染内容区（背景），
/// 由 Settings 宽屏右栏提供标题/容器——子页组件原样复用，窄屏全屏/宽屏嵌入两套布局共用同一份内容
import { HdsNavDestination } from '@kit.UIDesignKit';
import { ThemeManager } from '../../model/ThemeManager';
import { buildSubPageTitleBar } from '../../model/TitleBarStyles';

@Component
export struct SubPageScaffold {
  @Prop title: string = '';
  @Prop embedded: boolean = false;
  @BuilderParam content: () => void;
  /// 子页路由栈回调（透传 HdsNavDestination onReady 的 pathStack，供需要 pop 的子页如 SearchPage 使用）
  onPathStack: (stack: NavPathStack) => void = () => {};
  @StorageLink('settings_customBgUri') @Watch('onCustomBgUriChange') customBgUri: string = '';
  /// 自定义背景图是否已解码完成（淡入过渡用：见 body() 背景 Image）
  @State bgReady: boolean = AppStorage.get<boolean>('customBgLoaded') ?? false;

  /// 换背景图 → 复位淡入状态（新图加载完成后重新淡入，避免复用旧图已淡入状态导致瞬变）
  onCustomBgUriChange(): void {
    this.bgReady = false;
  }
  /// 主题版本信号：系统深浅切换（onConfigurationUpdate）时已打开的子页也要刷新背景
  /// （Index tab 页订阅了会重建，但 push 的子页是独立路由页，不随 Index 重建——必须自己订阅）
  @StorageLink('themeColorsVersion') themeColorsVersion: number = 0;

  /// 内容主体（两种模式共用：背景图 + 内容）
  /// 顶部不做固定 Blank 避让——完全对齐设置主页/媒体库方案：List 视口顶到屏幕顶，
  /// 内容滚动时自然滑进标题栏区域（透明标题栏 + 滚动模糊渐变盖住，即"自然的滚动上去"）；
  /// 初始贴顶由调用方 List 第一个 ListItem 的 Blank（embedded ? 12 : 112）承担
  @Builder
  body() {
    Stack() {
      // 自定义背景图（页面内底层）。key 稳定，父重建时 Image 复用不重新加载（避免闪烁）
      if (this.customBgUri) {
        Image(this.customBgUri)
          .width('100%').height('100%')
          .objectFit(ImageFit.Cover)
          .key('subpage_custom_bg')
          // **淡入过渡（修复"首次进子页背景闪一下"）**：冷启动首次进子页
          // 时图片要现场解码 → 解码完成瞬间出现 = 闪。onComplete 后 300ms 淡入
          // （属性动画，不与 animateTo 同用）；换背景图 → bgReady 复位重新淡入
          .opacity(this.bgReady ? 1 : 0)
          .animation({ duration: 300, curve: Curve.EaseOut })
          .onComplete(() => {
            this.bgReady = true;
          })
      }
      Column() {
        this.content()
      }
      // 高度 calc(100% + 10vp) 补偿负 margin：margin top -10 让 Column 上移 10vp，
      // 若高度仍 100% 则底部露出 10vp 空隙透出 NavDestination 默认背景；增高后底部贴底不露出
      .width('100%')
      .height(this.embedded ? '100%' : 'calc(100% + 10vp)')
      // 补偿 HdsNavDestination 内容区顶部偏移：真机实测子页比主页（HdsTabs）内容低约 22vp，
      // 但 -22 全部抵消后内容(112)离标题栏底(104)仅 8vp、被滚动模糊带压顶（避免离标题栏太近）。
      // 折中 -10：内容 124（下去 12vp），与标题栏间距 20vp、模糊带不压内容。
      // embedded 宽屏右栏无 NavDestination 壳，无此偏移，不加。
      .margin({ top: this.embedded ? 0 : -10 })
      .backgroundColor(this.customBgUri ? Color.Transparent : ThemeManager.colors.background)
    }
    // Stack 背景色兜底（防负 margin 边缘/自定义背景加载间隙透出 NavDestination 默认背景）
    .backgroundColor(this.customBgUri ? Color.Transparent : ThemeManager.colors.background)
    .width('100%')
    .height('100%')
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
      .titleBar(buildSubPageTitleBar(this.title, true, 28, true))
      .hideBackButton(false)
      .titleMode(100) // HdsNavDestinationTitleMode.MINI（Hds 枚举 release 打包无导出，用数值 100）
      .ignoreLayoutSafeArea([0], [0]) // LayoutSafeAreaType.SYSTEM=0 / LayoutSafeAreaEdge.TOP=0（枚举传 Hds 同样 release 解析失败）
      .onReady((ctx: NavDestinationContext) => {
        this.onPathStack(ctx.pathStack);
      })
    }
  }
}
