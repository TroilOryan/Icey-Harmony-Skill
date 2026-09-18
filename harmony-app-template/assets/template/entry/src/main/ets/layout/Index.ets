/// 主布局（HdsNavigation + HdsTabs barFloatingStyle.miniBar 占位 + 系统深浅色）
/// 结构铁律（生产项目实战）：
/// 1. Hds 枚举可用枚举名（compatibility 23+ 正常导出）；若兼容更低 API 设备闪退，
///    退回数值（GRADIENT_BLUR=2、HdsNavigationTitleMode.MINI=2、HdsNavDestinationTitleMode.MINI=100、
///    LayoutSafeAreaType.SYSTEM=0/LayoutSafeAreaEdge.TOP=0）
/// 2. TabContent/HdsTabs/HdsNavigation 逐层显式透明：Hds 默认背景层会压暗透出的自定义背景图
/// 3. animationDuration(0)：tab 瞬时切换（Hds 默认 ~300ms 动画用户感知"点了要等"）
/// 4. cachedMaxCount 预加载全部 tab：启动时构建各页，切换无首次构建闪烁
/// 5. titleBar 走 buildHomeTitleBar（本文件 TitleBarStyles）：GRADIENT_BLUR 滚动渐变模糊
/// 6. 子页 push/pop 走 AppRouter 单例 + navDestinationBuilder 按 name 分发
import {
  HdsNavigation,
  HdsTabs,
  HdsTabsController,
  HdsTabsFloatingStyle,
  HdsBarStyle,
  HdsTabsBarChangeMode,
  HdsNavigationTitleBarOptions,
  hdsMaterial,
} from '@kit.UIDesignKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HomeTab } from '../pages/HomeTab';
import { SettingsTab } from '../pages/SettingsTab';
import { HomeDetailPage } from '../pages/subPages/HomeDetailPage';
import { SettingsSubPage } from '../pages/subPages/SettingsSubPage';
import { AboutPage } from '../pages/subPages/AboutPage';
import { ThemeManager } from '../model/ThemeManager';
import { AppRouter, ROUTE_HOME_DETAIL, ROUTE_SETTINGS_SUB, ROUTE_ABOUT } from '../model/AppRouter';
import { AppSheet } from '../components/AppSheet/AppSheet';
import { SheetContainer } from '../components/SheetContainer/SheetContainer';
import { SafeArea } from '../model/SafeArea';
import { buildHomeTitleBar } from '../model/TitleBarStyles';

const TAG = 'Index';
const TAB_COUNT = 2;

@Component
export struct Index {
  @State currentIndex: number = 0;
  /// 主题版本信号：ThemeManager.applyThemeMode 每次 +1；@StorageLink 触发重建 → 所有 tab/子组件重读 colors
  @StorageLink('themeColorsVersion') themeColorsVersion: number = 0;
  /// 沉浸光感材质挡位（0强/1平衡/2弱/10自适应）：设置项联动，@StorageLink 驱动实时生效
  @StorageLink('settings_materialLevel') materialLevel: number = 10;
  /// 智感握姿（设置项）：开 = 底部导航栏跟随握持手方向镜像
  @StorageLink('settings_handedness') handedness: boolean = false;
  /// 数据加载完成（EntryAbility startupReady 恢复完打标）：列表页据此避免启动闪空态
  @StorageLink('dataLoaded') dataLoaded: boolean = false;
  /// tabBar 折叠态（Hds 自动折叠——小窗/展开 miniBar 时只显图标不显文字）
  @State tabBarCollapsed: boolean = false;
  /// 示例弹窗状态
  @State showDemoSheet: boolean = false;
  /// 路由栈：HdsNavigation 注入，子页 push/pop 走它（自带转场动画）
  private pathStack: NavPathStack = new NavPathStack();
  private hdsTabsController: HdsTabsController = new HdsTabsController();
  private readonly tabTitles: string[] = ['首页', '设置'];
  /// 悬浮底栏宽度（折叠态）：屏宽 - 96，最小 264（照抄 MusicHome 规范）
  private floatingBarSmallWidthVp(): number {
    const winW = AppStorage.get<number>('windowWidth') ?? 0;
    return winW > 0 ? winW - 96 : 264;
  }

  aboutToAppear(): void {
    // 注入真实路由栈（AppRouter 单例；Tab 页/深层组件一律 AppRouter.push）
    AppRouter.getInstance().setPathStack(this.pathStack);
    // 更新日志检查（版本更新首次启动自动弹一次；AboutPage 里也可手动查看）
    // TODO: 接 ChangelogSheetHost 或在此处按 ChangelogManager.shouldShow() 弹窗
  }

  build() {
    Stack() {
      Column() {
        HdsNavigation(this.pathStack) {
          HdsTabs({ controller: this.hdsTabsController }) {
            TabContent() {
              HomeTab({ themeVersion: this.themeColorsVersion })
            }
            // TabContent 透明：Hds 默认背景会压暗透出的自定义背景图
            .backgroundColor(Color.Transparent)
            .tabBar(this.TabItemBuilder(0, $r('sys.symbol.house'),
              $r('sys.symbol.house_fill'), '首页'))

            TabContent() {
              SettingsTab({ themeVersion: this.themeColorsVersion })
            }
            .backgroundColor(Color.Transparent)
            .tabBar(this.TabItemBuilder(1, $r('sys.symbol.gearshape'), $r('sys.symbol.gearshape_fill'), '设置'))
          }
          .onChange((index: number) => { this.currentIndex = index; })
          .barMode(BarMode.Fixed)
          .barHeight(56)
          .barOverlap(true)
          .barPosition(BarPosition.End)
          .vertical(false)
          .scrollable(false)
          // 0 = 瞬时切换（Hds 默认 ~300ms，用户感知"点了要等"）
          .animationDuration(0)
          .barFloatingStyle({
            // 折叠态悬浮条宽度（屏宽-96），展开 284/328（MusicHome 规范）
            barWidth: { smallWidth: this.floatingBarSmallWidthVp(), mediumWidth: 284, largeWidth: 328 },
            // 智感握姿：底部导航栏跟随握持手方向镜像（设置项实时开关）
            adaptToHandedness: this.handedness,
            // 全屏布局后导航条不再自动避让，barBottomMargin 补导航条高度 + 2vp 间距
            barBottomMargin: 2 + SafeArea.bottom,
            // ADAPTIVE 材质；挡位可调（0强/1平衡/2弱/10自适应）
            systemMaterialEffect: {
              materialType: hdsMaterial.MaterialType.ADAPTIVE,
              materialLevel: this.materialLevel,
            },
            // miniBar：迷你播放条占位（音乐/视频类应用参考同类实现；普通应用可整段删除）
            miniBar: {
              miniBarBuilder: () => { this.miniBarPlaceholder(); },
              onBarStyleChange: (miniBarStyle: HdsBarStyle, tabBarStyle: HdsBarStyle,
                                 miniBarWidth: number, tabBarWidth: number,
                                 mode: HdsTabsBarChangeMode) => {
                // tabBar 折叠态追踪（小窗/展开 miniBar 时只显图标）
                this.tabBarCollapsed = tabBarStyle !== HdsBarStyle.EXPAND;
              },
            },
          } as HdsTabsFloatingStyle)
          // tab 页预加载：启动时构建全部 tab（各页背景/图片启动阶段完成加载，切换无闪烁）
          .cachedMaxCount(TAB_COUNT, TabsCacheMode.CACHE_BOTH_SIDE)
          // HdsTabs 自身透明（默认材质/背景层会压暗透出的背景图）
          .backgroundColor(Color.Transparent)
        }
        .zIndex(1)
        .width('100%').height('100%')
        .backgroundColor(Color.Transparent)
        .mode(NavigationMode.Stack)
        .titleBar(this.homeTitleBar())
        .hideBackButton(true)
        .titleMode(2) // HdsNavigationTitleMode.MINI（Hds 枚举若低 API 闪退，用数值 2）
        .navDestination(this.navDestinationBuilder)
        // 标题栏背景延伸到状态栏区（渐变模糊铺满状态栏）
        .ignoreLayoutSafeArea([0], [0]) // LayoutSafeAreaType.SYSTEM=0 / Edge.TOP=0
        .backgroundColor(ThemeManager.colors.background)
      }
      .width('100%').height('100%')

      // 根级示例弹窗（AppSheet：手机 bindSheet / 宽屏窗口级 dialog 自适应）
      AppSheet({ show: this.showDemoSheet, group: 'index' }) {
        SheetContainer({ title: '示例弹窗' }) {
          Column() {
            Text('底部弹窗 + 宽屏自动切换窗口级居中 dialog；同 group 互斥防叠加。')
              .fontSize(14)
              .fontColor(ThemeManager.colors.textSecondary)
              .padding(16)
          }
          .width('100%')
        }
      }
    }
    .width('100%')
    .height('100%')
    // 状态栏区背景色（HdsNavigation 整体在避让区内，顶部露出区域由此填充）
    .backgroundColor(ThemeManager.colors.background)
    // 根容器绘制延伸到状态栏/导航条区（布局仍全屏窗口——EntryAbility 已 setWindowLayoutFullScreen，
    // expandSafeArea 让 Stack 背景（含自定义背景图）铺满状态栏后面，不留白条）
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  /// 首页标题栏（滚动渐变模糊；tab 标题随 currentIndex 切换；右上角菜单演示）
  private homeTitleBar(): HdsNavigationTitleBarOptions {
    // 需要右上角操作按钮时（媒体库"随机播放/更多"等）：menu.value 加 icon+action 项。
    // icon 用**官方符号** `$r('sys.symbol.xxx')`（下方示例即如此）
    const opts = buildHomeTitleBar(this.tabTitles[this.currentIndex], this.materialLevel);
    // ⚠️ content 是可选字段（possibly undefined），先判空再挂菜单
    if (opts.content) {
      opts.content.menu = {
      value: [
        {
          content: {
            icon: $r('sys.symbol.gearshape'),
            action: () => {
              // 演示：标题栏按钮打开底部弹窗
              this.showDemoSheet = true;
            },
          },
        },
      ],
      };
    }
    return opts;
  }

  /// tabBar 项（**官方符号**选中态两套 + 折叠态只显图标）
  /// 符号用 Resource 传入（`$r('sys.symbol.xxx')` 是编译期字面量，不能拼接字符串）；
  /// 选中态读 `this.currentIndex`（Builder 内直接读状态，可正常刷新）
  @Builder
  TabItemBuilder(index: number, normalSymbol: Resource, activeSymbol: Resource, label: string) {
    Column({ space: 4 }) {
      SymbolGlyph(this.currentIndex === index ? activeSymbol : normalSymbol)
        .fontSize(22)
        .fontColor([this.currentIndex === index
          ? ThemeManager.colors.tabBarActive : ThemeManager.colors.tabBarInactive])
      if (!this.tabBarCollapsed) {
        Text(label).fontSize(11)
          .fontColor(this.currentIndex === index
            ? ThemeManager.colors.tabBarActive : ThemeManager.colors.tabBarInactive)
      }
    }
    .width('100%').height(56)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .borderRadius(16)
    .padding({ bottom: 4 })
  }

  /// miniBar 占位（音乐/视频类应用参考同类应用：封面+标题+播放控制+上滑展开播放页；
  /// 普通应用整段删除 miniBar 配置即可）
  @Builder
  miniBarPlaceholder() {
    Row() {
      SymbolGlyph($r('sys.symbol.play_fill'))
        .fontSize(20)
        .fontColor([ThemeManager.colors.textPrimary])
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  /// 子页分发（AppRouter.push 的 name 对应；子页用 SubPageScaffold 承载标题栏）
  @Builder
  navDestinationBuilder(name: string, param: Object) {
    if (name === ROUTE_HOME_DETAIL) {
      HomeDetailPage()
    } else if (name === ROUTE_SETTINGS_SUB) {
      SettingsSubPage()
    } else if (name === ROUTE_ABOUT) {
      AboutPage()
    }
  }
}
