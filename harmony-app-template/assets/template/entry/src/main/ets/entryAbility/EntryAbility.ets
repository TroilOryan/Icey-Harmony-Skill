/// UIAbility 入口——模板全链路：
/// onCreate 初始化（各模块独立 try-catch，一个失败不中断后续）→ onWindowStageCreate
/// 开全屏窗口 + 安全区计算 → 立即 loadContent（UI 优先，永不阻塞）→ 后台 startupReady 恢复数据
/// 铁律沉淀（生产项目实战）：
/// 1. SettingsManager.init 必须最先（其他模块依赖设置持久化；init 失败 → 所有设置静默丢失）
/// 2. 全屏布局后 UI 手动避让（SafeArea），窗口级 setWindowLayoutFullScreen 才是真全屏
///    （expandSafeArea 只让绘制溢出、不改布局尺寸）
/// 3. avoidAreaChange 必须监听：状态栏显隐不触发 windowSizeChange 但触发 avoidAreaChange
/// 4. 挖孔避让必须合并 TYPE_CUTOUT（TYPE_SYSTEM 不含挖孔，横屏挖孔在左右缘）
/// 5. onConfigurationUpdate 里禁止调 setColorMode（会再次触发回调 → 无限循环）
/// 6. applyColorMode 要调两次：onCreate 一次（全局配置）+ onWindowStageCreate 窗口就绪后一次
///    （窗口未建时 setColorMode 可能未作用于渲染，首帧 Hds 材质/sys.color 按错误模式解析）
import { AbilityConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { font, window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppGlobalContext } from '../services/AppGlobalContext';
import { AppLogger } from '../services/AppLogger';
import { ChangelogManager } from '../services/ChangelogManager';
import { SafeArea } from '../model/SafeArea';
import { WindowHelper } from '../services/WindowHelper';
import { SettingsManager } from '../model/SettingsManager';
import { ThemeManager } from '../model/ThemeManager';

const TAG = 'EntryAbility';
/// 启动就绪 Promise：数据恢复等耗时操作放这里（onCreate 启动，UI 可 await 或后台 .then）
/// 铁律：**UI 优先，永不阻塞**——loadContent 不等 startupReady，数据恢复后台完成后
/// AppStorage 响应式刷新 UI
let startupReady: Promise<void> | null = null;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, 'onCreate');
    // 全局 context 注入（service 层/后台任务随时可取，不依赖组件树）
    try {
      AppGlobalContext.setContext(this.context);
    } catch (e) {
      hilog.error(0x0000, TAG, `AppGlobalContext.setContext failed: ${JSON.stringify(e)}`);
    }
    // 初始化加固：各模块 init 独立 try-catch——任何一个 init 抛异常都不能中断后续初始化。
    // 否则 SettingsManager.init 不执行时所有 setXxx 的 save() 静默失败 → 重启后全部设置丢失。
    try {
      // 必须最先 init：设置持久化优先级最高，不依赖其他模块
      SettingsManager.init(this.context);
    } catch (e) {
      hilog.error(0x0000, TAG, `SettingsManager.init failed: ${JSON.stringify(e)}`);
    }
    try {
      // 运行日志（调试模式开关持久化恢复在 App.ets 页面显示后拉起）
      AppLogger.init(this.context);
    } catch (e) {
      hilog.error(0x0000, TAG, `AppLogger.init failed: ${JSON.stringify(e)}`);
    }
    try {
      // 更新日志：预加载 preferences + 当前版本号（Index.aboutToAppear 延迟弹窗检查）
      ChangelogManager.init(this.context);
    } catch (e) {
      hilog.error(0x0000, TAG, `ChangelogManager.init failed: ${JSON.stringify(e)}`);
    }
    // 应用主题颜色模式（强制 app 整体深浅色，让 $r 系统资源/状态栏跟随）
    SettingsManager.applyColorMode(this.context);

    // ===== 启动恢复链路（UI 优先，永不阻塞）=====
    // 把你的数据恢复/初始化放这里：waitReady（设置就绪）→ 恢复数据 → 填 AppStorage →
    // mediaLoaded 等完成标记。UI 立即展示（空态/加载态），恢复完成后响应式刷新。
    startupReady = (async (): Promise<void> => {
      try {
        const t0 = Date.now();
        // 先等 SettingsManager 异步加载完成（持久化设置回填 AppStorage）再做依赖设置的事
        await SettingsManager.waitReady();
        AppLogger.info('Startup', `waitReady ${Date.now() - t0}ms`);
        // TODO: 在这里做你的数据恢复（读库/文件/网络），完成后打完成标记。
        // ⚠️ 必须用 setOrCreate，不要用 set：**AppStorage.set 对「尚不存在的键」是静默空操作**。
        // 本链路可能快于 UI 构建（实测 34ms 恢复 vs 55ms 建树），此时 App.ets 还没来得及
        // setOrCreate 出 'dataLoaded' 键 → set 直接落空 → 标志位永远为 true 不了 →
        // 列表页永久停在「加载中…」（2026-09-17 实机踩到）。setOrCreate 则与先后顺序无关。
        // AppStorage.setOrCreate<boolean>('dataLoaded', true);
        AppLogger.info('Startup', `启动恢复总耗时 ${Date.now() - t0}ms`);
      } catch (e) {
        hilog.error(0x0000, TAG, `startup restore failed: ${JSON.stringify(e)}`);
        // 兜底：恢复失败也要打完成标记，避免 UI 永远停在加载态（同样用 setOrCreate）
        AppStorage.setOrCreate<boolean>('dataLoaded', true);
      }
    })();
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 被再次拉起（卡片/router/意图）走这里：按需解析 want.parameters
  }

  onDestroy(): void {
    hilog.info(0x0000, TAG, 'onDestroy');
    // 设置落盘兜底（防抖定时器未到期的设置不丢）
    SettingsManager.saveNow();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, TAG, 'onWindowStageCreate');
    // 开窗口全屏布局：根布局区延伸到状态栏/导航栏区。
    // expandSafeArea 只让组件绘制溢出安全区、不改布局尺寸，必须靠窗口级全屏才能真正撑满。
    // 全屏后 UI 需手动避让，避让高度存 AppStorage 供 UI 读（SafeArea.top/bottom/left/right）。
    SafeArea.init();
    windowStage.getMainWindow().then((mainWin: window.Window) => {
      // 窗口创建后再强制一次颜色模式：onCreate 时窗口未建，setColorMode 可能未作用于窗口渲染，
      // 首帧的 Hds 材质/sys.color 资源会按错误模式解析。窗口就绪后重设保证首帧即正确。
      SettingsManager.applyColorMode(this.context);
      // 取避让区域：TYPE_SYSTEM(状态栏/导航条) + TYPE_NAVIGATION_INDICATOR(导航条)。
      // 挖孔合并：TYPE_SYSTEM 不含挖孔——横屏摄像头/挖孔在左右缘时合并 TYPE_CUTOUT 取 max
      const sysArea = mainWin.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const cutArea = mainWin.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      const navArea = mainWin.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const top = px2vp(sysArea.topRect.height);
      const bottom = px2vp(navArea.bottomRect.height);
      const left = px2vp(Math.max(sysArea.leftRect.width, cutArea.leftRect.width));
      const right = px2vp(Math.max(sysArea.rightRect.width, cutArea.rightRect.width));
      SafeArea.set(top, bottom, left, right);
      hilog.info(0x0000, TAG, `safeArea top=${top} bottom=${bottom} left=${left} right=${right}`);
      // 旋转/尺寸变化时安全区随之变化（横屏状态栏在左右），动态更新
      try {
        mainWin.on('windowSizeChange', () => {
          const sa = mainWin.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
          const cut = mainWin.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
          const na = mainWin.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
          SafeArea.set(
            px2vp(sa.topRect.height),
            px2vp(na.bottomRect.height),
            px2vp(Math.max(sa.leftRect.width, cut.leftRect.width)),
            px2vp(Math.max(sa.rightRect.width, cut.rightRect.width)));
        });
      } catch (e) {
        hilog.error(0x0000, TAG, 'windowSizeChange listen failed: %{public}s', JSON.stringify(e));
      }
      // avoidAreaChange 必须监听：状态栏显隐不触发 windowSizeChange，但触发 avoidAreaChange
      // （沉浸隐藏状态栏 → avoidArea 变小；取消显示 → 恢复。不监听则 SafeArea.top 残留旧值）
      try {
        mainWin.on('avoidAreaChange', () => {
          try {
            const sa = mainWin.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
            const cut = mainWin.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
            const na = mainWin.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
            SafeArea.set(
              px2vp(sa.topRect.height),
              px2vp(na.bottomRect.height),
              px2vp(Math.max(sa.leftRect.width, cut.leftRect.width)),
              px2vp(Math.max(sa.rightRect.width, cut.rightRect.width)));
          } catch (e2) {
            hilog.error(0x0000, TAG, 'avoidAreaChange refresh failed: %{public}s', JSON.stringify(e2));
          }
        });
      } catch (e) {
        hilog.error(0x0000, TAG, 'avoidAreaChange listen failed: %{public}s', JSON.stringify(e));
      }
      mainWin.setWindowLayoutFullScreen(true).then(() => {
        hilog.info(0x0000, TAG, 'setWindowLayoutFullScreen ok');
        // **立即 loadContent（UI 优先，永不阻塞）**：不等 startupReady——数据恢复耗时可观，
        // await 会让 splash 停留。主界面秒开（空态/加载态），startupReady 后台完成后
        // AppStorage 响应式自动刷新
        this.loadContent(windowStage);
      }).catch((e: object) => {
        hilog.error(0x0000, TAG, 'setWindowLayoutFullScreen failed: %{public}s', JSON.stringify(e));
        this.loadContent(windowStage);
      });
    }).catch((e: object) => {
      hilog.error(0x0000, TAG, 'getMainWindow failed: %{public}s', JSON.stringify(e));
      this.loadContent(windowStage);
    });
  }

  private loadContent(windowStage: window.WindowStage): void {
    windowStage.loadContent('App', (err) => {
      if (err.code) {
        hilog.error(0x0000, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(0x0000, TAG, 'Content loaded successfully');
      // 自定义字体注册（如需）：必须在 loadContent 回调里注册，否则页面用不上
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, TAG, 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, TAG, 'onForeground');
    // 回前台布尔信号复位：需要"当前是否在后台"语义的场景（如动画暂停/恢复）用这个。
    // ⚠️ appBackgrounded 版本号只增不减、不可判态——版本号（事件触发）与布尔（状态查询）
    // 双信号并存，语义不同勿混用（曾因复位版本号导致依赖 +1 增量的 @Watch 永不再触发）
    AppStorage.set<boolean>('appInBackground', false);
    // 回前台校正主题：系统 picker 弹窗打开/取消可能触发 onConfigurationUpdate 误报 colorMode
    // → ThemeManager 色板跳浅。applyColorMode 按当前模式重设（幂等安全）
    try {
      SettingsManager.applyColorMode(this.context);
    } catch (e) {
      hilog.error(0x0000, TAG, 'onForeground applyColorMode failed: ' + JSON.stringify(e));
    }
  }

  onBackground(): void {
    hilog.info(0x0000, TAG, 'onBackground');
    // 设置立即落盘兜底：300ms 防抖未到期的设置在杀进程前保证持久化
    SettingsManager.saveNow();
    // 退后台布尔信号置位（onForeground 复位 false）——与 appBackgrounded 版本号并存
    AppStorage.set<boolean>('appInBackground', true);
    // 广播退后台信号（版本号 +1 保证变化触发 @Watch）：AppSheet 据此自动关闭打开的弹窗
    // （宽屏窗口级 dialog 退后台不自动关、回前台残留）
    AppStorage.set<number>('appBackgrounded', (AppStorage.get<number>('appBackgrounded') ?? 0) + 1);
  }

  /// 系统配置变化（含深浅色实时切换）——UIAbility 生命周期回调。
  /// 注意：页面组件（@Entry）里的 onConfigurationUpdate 不是标准回调、不会被调用，
  /// 必须在 Ability 级实现。
  /// **不能在这里调 setColorMode**——setColorMode 会再次触发 onConfigurationUpdate → 无限循环！
  /// 只刷新 ThemeManager + 系统栏字色；$r 系统资源靠 COLOR_MODE_NOT_SET 自动跟随系统。
  onConfigurationUpdate(newConfig: Configuration): void {
    hilog.info(0x0000, TAG, `onConfigurationUpdate colorMode=${newConfig.colorMode}`);
    try {
      // colorMode 可能 undefined/枚举类型，统一转 number；NOT_SET(-1)/undefined 时不覆盖
      const cmVal = newConfig.colorMode;
      const cm: number = cmVal === undefined ? -1 : (cmVal as number);
      if (cm === 0 || cm === 1) {
        ThemeManager.updateFromConfig(cm);
        // 系统栏字色随主题同步（全屏后系统栏图标需手动设置）
        try {
          WindowHelper.setSystemBarContentColor(this.context, ThemeManager.isDark ? '#FFFFFF' : '#000000');
        } catch (_) {}
      }
    } catch (e) {
      hilog.error(0x0000, TAG, `onConfigurationUpdate failed: ${JSON.stringify(e)}`);
    }
  }
}
