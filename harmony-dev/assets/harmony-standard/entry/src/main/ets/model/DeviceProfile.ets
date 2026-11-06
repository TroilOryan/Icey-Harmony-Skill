/// 设备形态档案（2026-09-23 沉淀）：华为官方阔折叠/阔直板屏幕规格集中在此，
/// 供下沉判据 / 紧凑模式 / 导航栏收敛等各处形态判定引用——后续针对性适配直接查表。
/// 数据来源：华为最佳实践《阔折叠/阔直板应用开发》bpta-purax-guide（2026-09 版），
/// 分辨率 vp 为官方"向下取整"值，px 供密度换算参考。
import { deviceInfo } from '@kit.BasicServicesKit';
import { SafeArea } from './SafeArea';
///
/// 形态判定口径（2026-09-23 用户定案）：
/// - **短屏（宽扁形态）判定 = 窗口高宽比 h/w < 1.9**——阔直板/折叠展开态全部落在
///   1.4~1.7 区间，普通直板机 2.1~2.2，一刀切干净分离（绝对高阈值会误判：Pura X View
///   高 744vp 过 700 线但纵向明显更矮，PlayHomePage 封面下沉曾因此误判）
/// - **紧凑屏（小方形）判定 = 窗口宽 ≤ 360vp**——Pura X 外屏 326×326 / 窄小窗
export class DeviceProfile {
  /// ===== 官方屏幕规格（宽×高，vp 向下取整 / px / 断点）=====
  /// Pura X View（阔直板，16:9.5）：440×744vp，1320×2232px，断点 sm*lg
  static readonly PURA_X_VIEW_W: number = 440;
  static readonly PURA_X_VIEW_H: number = 744;
  /// Pura X 折叠态（横向方形 1:1）：326×326vp，980×980px，断点 sm*md
  static readonly PURA_X_FOLDED_W: number = 326;
  static readonly PURA_X_FOLDED_H: number = 326;
  /// Pura X 展开态（竖向 16:10）：440×707vp，1320×2120px，断点 sm*lg
  static readonly PURA_X_EXPANDED_W: number = 440;
  static readonly PURA_X_EXPANDED_H: number = 707;
  /// Pura X Max 折叠态（竖向 14:10）：459×672vp，1264×1848px，断点 sm*lg
  static readonly PURA_X_MAX_FOLDED_W: number = 459;
  static readonly PURA_X_MAX_FOLDED_H: number = 672;
  /// Pura X Max 展开态（横向 10:14）：939×664vp，2584×1828px，断点 lg*sm
  static readonly PURA_X_MAX_EXPANDED_W: number = 939;
  static readonly PURA_X_MAX_EXPANDED_H: number = 664;

  /// ===== 判定阈值 =====
  /// 短屏（宽扁形态）高宽比上限：h/w < 1.9 → 不下沉/纵向紧凑布局
  static readonly SHORT_SCREEN_ASPECT: number = 1.9;
  /// 紧凑屏（小方形/窄小窗）宽度上限：w ≤ 360vp → 播放页极简布局
  static readonly COMPACT_SCREEN_WIDTH: number = 360;
  /// HdsTabs barWidth 档位断点（SDK @hms.hds.hdsBaseComponent.d.ets 官方注释）：
  /// small = tabs 宽 < 600vp；medium = 600~840vp 且 w/h < 0.8（比值取 w/h）；
  /// large = > 840vp 或 600~840 且 w/h > 0.8。
  /// **窄平板竖屏并排风险窗口**（2026-09-23 v3 用户定案）= medium 档
  /// （TABS_MEDIUM_MIN < w ≤ TABS_LARGE_MIN 且 w/h < 0.8）：展开态播放条与导航
  /// 并排（284×2≈568+边距）放不下 → 重叠。处理方式**不改宽度**（v1 收窄误伤
  /// Pura X View 教训），行为收敛：播放条保持默认折叠态，不进入并排展开态
  static readonly TABS_MEDIUM_MIN: number = 600;
  static readonly TABS_LARGE_MIN: number = 840;

  /// 窗口是否短屏（宽扁形态）：折叠开合/分屏拖动传入实时窗口尺寸即可
  static isShortScreen(winW: number, winH: number): boolean {
    if (winW <= 0 || winH <= 0) return false;
    return winH / winW < DeviceProfile.SHORT_SCREEN_ASPECT;
  }

  /// 窗口是否紧凑屏（Pura X 外屏 326×326 / 窄小窗）
  static isCompactScreen(winW: number): boolean {
    return winW > 0 && winW <= DeviceProfile.COMPACT_SCREEN_WIDTH;
  }

  /// **窄平板竖屏（medium 档）判定**（2026-09-23 v3 并排重叠修复）：
  /// tabs 宽 600~840vp 且 w/h < 0.8（SDK 官方 medium 档口径，比值取 w/h）——
  /// 此窗口下悬浮 bar 并排（展开态播放条 + 导航）宽度放不下会重叠。
  /// 行为收敛用（播放条保持折叠态），不改 barWidth。
  /// winH ≤ 0（未广播/异常）时按宽度档位兜底判定
  static isMediumPortraitTabs(winW: number, winH: number): boolean {
    if (winW <= DeviceProfile.TABS_MEDIUM_MIN || winW > DeviceProfile.TABS_LARGE_MIN) {
      return false;
    }
    if (winH <= 0) return true;
    return winW / winH < 0.8;
  }

  /// **2in1（PC/一体机形态）判定**（2026-09-24 用户定案：接入 PC 级导航）：
  /// deviceInfo.deviceType === '2in1'——设备物理形态常量，一次读取缓存。
  /// 用途：2in1 上底部栏**锁定样式二（垂直两行，PC 级导航观感）**，设置页隐藏
  /// 样式切换配置（鼠标/键盘形态下样式一折叠手势无意义）。
  private static twoInOne: boolean = deviceInfo.deviceType === '2in1';

  static is2in1(): boolean {
    return DeviceProfile.twoInOne;
  }

  /// ===== 宽屏居中 dialog 判定（2026-10-07 收敛，**唯一口径**）=====
  /// 窗口短边阈值（vp）：≥ 本值 ⇒ 视为宽屏（走 `promptAction.openCustomDialog` 居中卡片）。
  /// ⚠️ **取值依据**（原在 `AppSheet` 内）：原实现用 `px2vp(display.getDefaultDisplaySync().width)`
  ///   —— `display.width` 是**屏幕当前方向**的宽，手机**横屏**时随旋转变成 ~744vp ⇒ 误判宽屏。
  ///   改用**窗口短边**后：手机竖屏 440×744 / 横屏 744×440 → 短边恒 440 → 恒窄屏 ✓；
  ///   Pura X Max 展开 939×664 → 664 → 宽屏 ✓；分屏窄窗 400×700 → 400 → 窄屏 ✓。
  ///   取值 600 = Hds 官方 `HdsBarWidthRangeOptions` 的 small↔medium 断点。
  static readonly WIDE_SHORT_SIDE_MIN: number = 600;

  /// 设备物理形态是否平板/PC（读取一次缓存）
  private static wideDeviceKnown: boolean = false;
  private static wideDevice: boolean = false;

  /// **当前是否走宽屏居中 dialog**（`AppSheet` 与 `SheetContainer` **共用同一判定**）。
  ///
  /// ⚠️ 必须唯一口径：`AppSheet` 用它决定 `bindSheet` / `openCustomDialog` 走哪条；
  ///   `SheetContainer` 用它决定内容层要不要加 76vp 顶部留白（宽屏标题行**真实占位**，
  ///   再加留白就成了双份 ⇒ 真机读作「内容垂直居中」，2026-10-07 用户反馈）。
  ///   两处若各自判一次，一旦口径漂移就会出现"留白时有时无"的闪烁。
  static isWideDialog(): boolean {
    DeviceProfile.ensureWideDevice();
    if (DeviceProfile.wideDevice) return true;
    const w = AppStorage.get<number>('windowWidth') ?? 0;
    const h = AppStorage.get<number>('windowHeight') ?? 0;
    if (w <= 0 || h <= 0) return false;
    return (w < h ? w : h) >= DeviceProfile.WIDE_SHORT_SIDE_MIN;
  }

  private static ensureWideDevice(): void {
    if (DeviceProfile.wideDeviceKnown) return;
    DeviceProfile.wideDeviceKnown = true;
    try {
      const dt = deviceInfo.deviceType;
      DeviceProfile.wideDevice = (dt === 'tablet' || dt === '2in1');
    } catch (_) {
      DeviceProfile.wideDevice = false;
    }
  }

  /// ===== PC 播放页最小边距（2026-09-28）=====
  /// 2in1 无系统状态栏/导航条 → SafeArea.top/bottom 恒 0，播放页既有
  /// 「SafeArea.top + base」边距公式在 PC 上退化为 base（8~12vp）观感贴窗口边缘
  /// （顶部标题贴窗顶、底部四个操作按钮贴死窗底）。统一收敛：
  /// 手机 = SafeArea + mobileBase（**真机观感分毫不动**）；PC = SafeArea(=0) + pcBase。
  /// 消费点：PlayHeaderBar 顶部 / PlayScreen 关闭按钮 / PlayHomePage 封面·右区·控制行 /
  /// PlayLyricPage 底部按钮（所有 SafeArea.top/bottom 边距一律走这两个入口）
  static topGap(mobileBase: number, pcBase: number): number {
    return SafeArea.top + (DeviceProfile.twoInOne ? pcBase : mobileBase);
  }

  static bottomGap(mobileBase: number, pcBase: number): number {
    return SafeArea.bottom + (DeviceProfile.twoInOne ? pcBase : mobileBase);
  }
}
