/// 应用根（@Entry）——全局宿主
/// 职责：
/// 1. 窗口尺寸监听广播（windowWidth/windowHeight/windowIsLandscape → AppStorage，
///    弹窗横竖屏适配/一多布局订阅）
/// 2. 主题初始化（按用户主题模式 + 系统色计算 isDark）+ 系统栏字色同步
/// 3. 全局键初始化 + 启动兜底（数据恢复竞态时补恢复）
/// 4. 返回手势处理：子页由 HdsNavigation 栈自动 pop 不冒泡到这里；
///    顶层返回 = 最小化应用（moveAbilityToBackground，符合系统习惯）
/// Index 只负责全局布局（HdsNavigation + HdsTabs）
import { Index } from './layout/Index';
import { AppLogger } from './services/AppLogger';
import { ThemeManager } from './model/ThemeManager';
import { SettingsManager } from './model/SettingsManager';
import { WindowHelper } from './services/WindowHelper';
import common from '@ohos.app.ability.common';
import { display, window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'App';

@Entry
@Component
struct App {
  /// 主窗口引用（窗口监听注销用）
  private mainWindow: window.Window | null = null;

  /// 窗口尺寸监听回调（小窗/分屏/平板旋转）：广播窗口尺寸到 AppStorage（订阅方：
  /// SheetContainer 横竖屏限高、一多布局、播放页方向等）
  private onWindowResize: (sz: window.Size) => void = (sz: window.Size) => {
    const w = px2vp(sz.width);
    const h = px2vp(sz.height);
    AppStorage.set<number>('windowWidth', w);
    AppStorage.set<number>('windowHeight', h);
    // 横竖屏布尔单独广播：避免 windowWidth 先 set 触发 @Watch 时 windowHeight 未 set 的竞态
    AppStorage.setOrCreate<boolean>('windowIsLandscape', w > h);
  };

  aboutToAppear(): void {
    // 全局键初始化（@StorageLink 首次读取前必须已存在，否则读默认值不响应后续 set）。
    //
    // ⚠️ 绝不能无条件 setOrCreate(false)：EntryAbility 的启动恢复链路与本回调存在**竞态**，
    // 若恢复先完成，此处会把已置的 true 覆写回 false，而 true 的唯一写入方就是那条
    // 已跑完的链路 → 标志位从此永远为 false，列表页永久停在「加载中…」。
    // 只在该键**尚不存在**时初始化，保证「一旦恢复完成就不可能被回退」。
    // （配合 EntryAbility 侧用 setOrCreate 打标记，两侧都与先后顺序无关）
    if (AppStorage.get<boolean>('dataLoaded') === undefined) {
      AppStorage.setOrCreate<boolean>('dataLoaded', false);
    }
    // 调试模式：上次开启 → 自动恢复实时落盘（picker 已可用）
    AppLogger.applyPendingRestore();
    // 启动兜底：startupReady 恢复链路竞态/异常导致标志位未置时的检查。
    // ⚠️ 这里只打日志是**不够的**——数据源已就绪却仍显示「加载中…」是致命 UX（整页不可用）。
    // 实项目请在此**真正补标记**：判断你的数据仓库是否已就绪（如提供一个静态 isReady()），
    // 就绪则强行 AppStorage.setOrCreate('dataLoaded', true) 自愈，未就绪才等待链路完成。
    setTimeout(() => {
      const loaded = AppStorage.get<boolean>('dataLoaded') ?? false;
      if (!loaded) {
        hilog.warn(0x0000, TAG, 'launch fallback: dataLoaded false after 300ms');
      }
    }, 300);
    // 主题初始化：按用户主题模式 + 系统色计算 isDark
    getContext(this).resourceManager.getConfiguration().then((value: object) => {
      const cm = (value as Record<string, number>)['colorMode'];
      hilog.info(0x0000, TAG, `App colorMode=${cm} themeMode=${SettingsManager.themeMode}`);
      // cm 仅 0(DARK)/1(LIGHT) 时应用；undefined/NOT_SET(-1) 不覆盖（保留 EntryAbility 已算主题）
      if (cm === 0 || cm === 1) {
        ThemeManager.applyThemeMode(SettingsManager.themeMode, cm);
        // 首页系统栏字色随主题：深色→浅字，浅色→深字
        WindowHelper.setSystemBarContentColor(
          getContext(this) as common.UIAbilityContext,
          ThemeManager.isDark ? '#FFFFFF' : '#000000');
      }
    });
    // 窗口尺寸监听（小窗/分屏/平板旋转）：广播窗口尺寸到 AppStorage
    const wctx = getContext(this) as common.UIAbilityContext;
    window.getLastWindow(wctx).then((win: window.Window) => {
      this.mainWindow = win;
      win.on('windowSizeChange', this.onWindowResize);
      // 初始窗口尺寸（windowSizeChange 不回调初始值）
      const rect = win.getWindowProperties().windowRect;
      this.onWindowResize({ width: rect.width, height: rect.height } as window.Size);
    }).catch(() => {});
    // 旋转备用触发：手机旋转时若 windowSizeChange 未及时回调，display 'change' 直接读
    // 窗口 rect 补广播（display.getDefaultDisplaySync() 是自然方向不随窗口旋转，不可用作尺寸源）
    try {
      display.on('change', () => {
        try {
          if (this.mainWindow) {
            const rect = this.mainWindow.getWindowProperties().windowRect;
            this.onWindowResize({ width: rect.width, height: rect.height } as window.Size);
          }
        } catch (_) {}
      });
    } catch (_) {}
  }

  aboutToDisappear(): void {
    if (this.mainWindow) {
      try { this.mainWindow.off('windowSizeChange', this.onWindowResize); } catch (_) {}
      this.mainWindow = null;
    }
    try { display.off('change'); } catch (_) {}
  }

  /// 系统返回手势/按键（@Entry 页面回调）：子页返回由 HdsNavigation 栈自动 pop 不冒泡到这里；
  /// 顶层返回 = 最小化应用（不退出进程，符合系统习惯）。
  /// ⚠️ 非 @Entry 的组件（如本模板的 layout/Index）onBackPress **不会被系统调用**——
  /// 有"返回键收起某个覆盖层"需求时，由这里判断状态后广播 AppStorage 版本号信号
  /// （如 appBackRequest +1），目标组件 @Watch 消费（参考主项目 Icey-Player 播放页收起）
  onBackPress(): boolean {
    try {
      (getContext(this) as common.UIAbilityContext).moveAbilityToBackground();
    } catch (_) {}
    return true;
  }

  build() {
    // @Entry 根必须为容器组件——包一层 Stack
    Stack() {
      Index()
    }
    .width('100%')
    .height('100%')
  }
}
