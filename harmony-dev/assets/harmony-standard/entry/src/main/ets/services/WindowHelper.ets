/// 窗口/系统栏助手（纯静态，吃 context）
/// 状态栏字色、屏幕方向、屏幕常亮、状态栏显隐（沉浸页用）、设备圆角。
/// ⚠️ 全 App **唯一**的状态栏内容色出口——别处直接 setWindowSystemBarProperties 会互相覆盖。
import { window, display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import common from '@ohos.app.ability.common';
import { SettingsManager } from '../model/SettingsManager';
import { SafeArea } from '../model/SafeArea';

const TAG = 'WindowHelper';

export class WindowHelper {
  /// **「屏幕方向」设置**（全局唯一出口）
  ///
  /// | 选项 | Orientation 值 | 系统旋转锁定 |
  /// |---|---|---|
  /// | 0 跟随系统 | `AUTO_ROTATION_RESTRICTED` | **受控**（系统锁了就锁住） |
  /// | 1 始终自动旋转 | `AUTO_ROTATION` | **忽略**（只看传感器） |
  /// | 2 固定竖屏 | `PORTRAIT` | 忽略（恒竖） |
  /// | 3 固定横屏 | `AUTO_ROTATION_LANDSCAPE` | 忽略（恒横，左右横屏都跟随） |
  ///
  /// ⚠️ 0 用 `AUTO_ROTATION_RESTRICTED` 而不是 `UNSPECIFIED`：与 module.json5 的
  /// `orientation: auto_rotation_restricted` 完全同义，任何模式下重设都不会意外锁竖屏。
  /// ⚠️ `LANDSCAPE` 只锁单一横屏方向，设备反转 180° 会倒置——锁横屏一律用 AUTO_ROTATION_LANDSCAPE。
  /// ⚠️ module.json5 的 `orientation` **绝不能用 `auto_rotation`**（无视系统旋转锁定开关）。
  static applyScreenOrientation(win: window.Window, mode: number): void {
    let target: window.Orientation = window.Orientation.AUTO_ROTATION_RESTRICTED;
    if (mode === 1) {
      target = window.Orientation.AUTO_ROTATION;
    } else if (mode === 2) {
      target = window.Orientation.PORTRAIT;
    } else if (mode === 3) {
      target = window.Orientation.AUTO_ROTATION_LANDSCAPE;
    }
    win.setPreferredOrientation(target).catch((e: object) => {
      hilog.error(0x0000, TAG, `setPreferredOrientation(${mode}) failed: ${JSON.stringify(e)}`);
    });
  }

  /// 设置窗口常亮：on=true 时按 settings_keepScreenOn 设，off=false 时强制关
  /// （页面进入时开、退出时关，不管设置——"只有当前场景才常亮"）
  static setKeepScreenOn(context: common.UIAbilityContext, on: boolean): void {
    try {
      window.getLastWindow(context).then((win: window.Window) => {
        const keep = on && SettingsManager.keepScreenOn;
        win.setWindowKeepScreenOn(keep);
      }).catch((e: object) => {
        hilog.error(0x0000, TAG, `setKeepScreenOn failed: ${JSON.stringify(e)}`);
      });
    } catch (e) {
      hilog.error(0x0000, TAG, `getLastWindow failed: ${JSON.stringify(e)}`);
    }
  }

  /// 设置状态栏字色（'#000000'=深色字 / '#FFFFFF'=浅色字）。⚠️ 全 App 唯一出口。
  static setStatusBarContentColor(context: common.UIAbilityContext, color: string): void {
    try {
      window.getLastWindow(context).then((win: window.Window) => {
        const props: window.SystemBarProperties = { statusBarContentColor: color };
        win.setWindowSystemBarProperties(props).catch((e: object) => {
          hilog.error(0x0000, TAG, `setStatusBarContentColor failed: ${JSON.stringify(e)}`);
        });
      }).catch((e: object) => {
        hilog.error(0x0000, TAG, `getLastWindow for statusbar failed: ${JSON.stringify(e)}`);
      });
    } catch (e) {
      hilog.error(0x0000, TAG, `setStatusBarContentColor init failed: ${JSON.stringify(e)}`);
    }
  }

  /// 状态栏 + 底部手势条字色一起设（全屏布局后深色模式下系统栏图标需手动设，否则看不清）。
  /// ⚠️ 只改字色；底部手势条颜色不受 alpha 影响（statusBarContentColor 不吃 alpha——设透明想
  /// "隐形"是无效路线，Icey 实证）。
  static setSystemBarContentColor(context: common.UIAbilityContext, color: string): void {
    try {
      window.getLastWindow(context).then((win: window.Window) => {
        const props: window.SystemBarProperties = {
          statusBarContentColor: color,
          navigationBarContentColor: color,
        };
        win.setWindowSystemBarProperties(props).catch((e: object) => {
          hilog.error(0x0000, TAG, `setSystemBarContentColor failed: ${JSON.stringify(e)}`);
        });
      }).catch((e: object) => {
        hilog.error(0x0000, TAG, `getLastWindow for systembar failed: ${JSON.stringify(e)}`);
      });
    } catch (e) {
      hilog.error(0x0000, TAG, `setSystemBarContentColor init failed: ${JSON.stringify(e)}`);
    }
  }

  /// 隐藏/显示**仅状态栏**（保留下方手势指示条）——全屏沉浸页进入时隐藏、退出时显示。
  ///
  /// ## ⚠️ 细粒度 API（`setSpecificSystemBarEnabled`）才是正解
  /// 旧白名单式 `setWindowSystemBarEnable(['navigation'])` 里 `'navigation'` 是**三键导航栏**，
  /// 手势指示条对应 `'navigationIndicator'`——旧写法会把手势条一起藏掉（"整个全屏"）。
  /// 正解 = 逐条控制：关 `'status'` + **显式打开** `'navigationIndicator'`。
  ///
  /// ## 布局稳定性（"隐藏后布局塌陷"的正解在 `SafeArea`，不在本方法）
  /// 显隐触发系统 `avoidAreaChange(top=0)`，由 `SafeArea` 在隐藏期间丢弃该回报 ⇒ 全 App
  /// 一次重排都没有。调用顺序固定：**先 `SafeArea.markBarsHidden()`，再发隐藏指令**。
  ///
  /// ⚠️ 不要 `setWindowLayoutFullScreen`——破坏 EntryAbility 的恒全屏布局。
  static setStatusBarVisible(context: common.UIAbilityContext, statusVisible: boolean): void {
    WindowHelper.applySpecificBar(context, 'status', statusVisible, 0);
    WindowHelper.applySpecificBar(context, 'navigationIndicator', true, 0);
  }

  /// 真·隐藏状态栏（带布局稳定标记）：先 markBarsHidden 再发指令——顺序不可颠倒
  static hideStatusBar(context: common.UIAbilityContext): void {
    SafeArea.markBarsHidden();
    WindowHelper.setStatusBarVisible(context, false);
  }

  /// 恢复状态栏（带"等真值回来"标记 + 乐观写回，见 SafeArea）
  static showStatusBar(context: common.UIAbilityContext): void {
    SafeArea.markBarsVisible();
    SafeArea.restoreTopOptimistic();
    WindowHelper.setStatusBarVisible(context, true);
  }

  /// 单条系统栏显隐 + 失败重试（120/300ms×2）+ 旧 API 回退（仅 'status'）
  private static applySpecificBar(context: common.UIAbilityContext,
                                  name: 'status' | 'navigation' | 'navigationIndicator',
                                  enable: boolean, retry: number): void {
    try {
      window.getLastWindow(context).then((win: window.Window) => {
        win.setSpecificSystemBarEnabled(name, enable, false).catch((e: object) => {
          hilog.error(0x0000, TAG,
            `setSpecificSystemBarEnabled(${name},${enable}) failed retry=${retry}: ${JSON.stringify(e)}`);
          WindowHelper.retrySpecificBar(context, name, enable, retry);
        });
      }).catch((e: object) => {
        hilog.error(0x0000, TAG, `getLastWindow for specific bar failed: ${JSON.stringify(e)}`);
        WindowHelper.retrySpecificBar(context, name, enable, retry);
      });
    } catch (e) {
      hilog.error(0x0000, TAG, `setSpecificSystemBarEnabled init failed: ${JSON.stringify(e)}`);
      WindowHelper.retrySpecificBar(context, name, enable, retry);
    }
  }

  private static retrySpecificBar(context: common.UIAbilityContext,
                                  name: 'status' | 'navigation' | 'navigationIndicator',
                                  enable: boolean, retry: number): void {
    if (retry >= 2) {
      hilog.error(0x0000, TAG, `setSpecificSystemBarEnabled(${name}) gave up after ${retry} retries`);
      if (name === 'status') {
        // 旧 API 回退（'navigation' = 三键导航栏白名单 → 状态栏被隐藏的最低保证）
        WindowHelper.applyBars(context, enable ? ['status', 'navigation'] : ['navigation'], 0);
      }
      return;
    }
    const delay = retry === 0 ? 120 : 300;
    setTimeout(() => {
      WindowHelper.applySpecificBar(context, name, enable, retry + 1);
    }, delay);
  }

  /// 白名单式旧 API（仅作细粒度 API 的回退）：names = 要显示的栏
  private static applyBars(context: common.UIAbilityContext,
                           names: Array<'status' | 'navigation'>, retry: number): void {
    try {
      window.getLastWindow(context).then((win: window.Window) => {
        win.setWindowSystemBarEnable(names).catch((e: object) => {
          hilog.error(0x0000, TAG,
            `setWindowSystemBarEnable(${JSON.stringify(names)}) failed retry=${retry}: ${JSON.stringify(e)}`);
          if (retry < 2) {
            setTimeout(() => { WindowHelper.applyBars(context, names, retry + 1); }, retry === 0 ? 120 : 300);
          }
        });
      }).catch((e: object) => {
        hilog.error(0x0000, TAG, `getLastWindow for system bar enable failed: ${JSON.stringify(e)}`);
      });
    } catch (e) {
      hilog.error(0x0000, TAG, `setWindowSystemBarEnable init failed: ${JSON.stringify(e)}`);
    }
  }

  /// 设备屏幕圆角半径（vp）：display.getRoundedCorner() 取 TOP_LEFT 转 vp。
  /// 无圆角/获取失败返回 0。物理圆角与旋转无关，启动获取一次即可。
  static getDeviceCornerRadiusVp(): number {
    try {
      const corners: display.RoundedCorner[] = display.getDefaultDisplaySync().getRoundedCorner();
      if (corners && corners.length > 0) {
        for (const c of corners) {
          if (c.type === display.CornerType.TOP_LEFT) {
            return px2vp(c.radius);
          }
        }
        return px2vp(corners[0].radius);
      }
    } catch (e) {
      hilog.error(0x0000, TAG, `getDeviceCornerRadius failed: ${JSON.stringify(e)}`);
    }
    return 0;
  }
}
