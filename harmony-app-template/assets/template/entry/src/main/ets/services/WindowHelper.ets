/// 窗口/系统栏助手（纯静态）
/// 全屏布局后系统状态栏/导航条不再自动避让、字色不自动跟随主题——统一在这里手动管理
import { window, display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import common from '@ohos.app.ability.common';

const TAG = 'WindowHelper';

export class WindowHelper {
  /// 设置窗口常亮（阅读/播放页等场景）
  static setKeepScreenOn(context: common.UIAbilityContext, on: boolean): void {
    try {
      window.getLastWindow(context).then((win: window.Window) => {
        win.setWindowKeepScreenOn(on);
      }).catch((e: object) => {
        hilog.error(0x0000, TAG, `setKeepScreenOn failed: ${JSON.stringify(e)}`);
      });
    } catch (e) {
      hilog.error(0x0000, TAG, `getLastWindow failed: ${JSON.stringify(e)}`);
    }
  }

  /// 设置状态栏字色（深浅）。color: '#000000'=深色字（浅底用）, '#FFFFFF'=浅色字（深底用）
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

  /// 设置状态栏 + 系统导航条字色（深浅）：全屏布局后导航条（手势条/三键）图标颜色需手动设，
  /// 否则深色模式下仍是深色图标看不清。context 可传 null（getLastWindow(null) 取当前窗口）
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

  /// 隐藏/显示系统状态栏（沉浸模式）。注意：显隐会触发 avoidAreaChange（EntryAbility
  /// 已监听并刷新 SafeArea，UI 布局自动适配，无需额外补偿）
  static setStatusBarVisible(context: common.UIAbilityContext, statusVisible: boolean): void {
    try {
      window.getLastWindow(context).then((win: window.Window) => {
        const names: Array<'status' | 'navigation'> = statusVisible
          ? ['status', 'navigation'] : ['navigation'];
        win.setWindowSystemBarEnable(names).catch((e: object) => {
          hilog.error(0x0000, TAG, `setStatusBarVisible failed: ${JSON.stringify(e)}`);
        });
      }).catch((e: object) => {
        hilog.error(0x0000, TAG, `getLastWindow for bar visible failed: ${JSON.stringify(e)}`);
      });
    } catch (e) {
      hilog.error(0x0000, TAG, `setStatusBarVisible init failed: ${JSON.stringify(e)}`);
    }
  }

  /// 设备屏幕圆角半径（vp）：display.getRoundedCorner() 返回四角圆角信息（px），
  /// 取左上角 TOP_LEFT 的 radius 转 vp。无圆角/获取失败返回 0。
  /// 物理圆角与旋转无关，启动获取一次即可。
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
