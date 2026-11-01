/// 主题管理（支持跟随系统 / 手动深浅色 / 自定义背景双壁纸）
/// 2026-09-09 改造：废弃"壁纸亮度自动判定强制颜色模式"机制——深浅色纯由用户主题模式
/// （含跟随系统）决定；自定义背景改为 开关 + 浅色壁纸 + 深色壁纸 双槽位，
/// 应用处于哪个深浅模式就显示对应槽位的壁纸（本文件按 AppStorage 键直接解析，避免与
/// SettingsManager 相互 import 成环）。
import { AppLogger } from '../services/AppLogger';

/// **2026-10-01 用户定案：全局配色重订（中性灰阶，去 iOS 系统灰）**
///
/// | 语义 | 浅色 | 深色 |
/// |---|---|---|
/// | 页面背景 | `#F2F3F5` | `#010101` |
/// | 卡片 | `#FFFFFF` | `#191919` |
/// | **普通按钮**（非 primary，如弹窗「取消」） | `#E7E8EA` | `#191919` |
/// | 主文字 | `#000000` | `#FFFFFF` |
/// | 次级文字 | `#666666` | `#A3A3A3` |
///
/// 设计意图：旧色板是 iOS 系统灰族（`#F2F3F4 / #F2F2F7 / #E5E5EA / #8E8E93 / #1C1C1E /
/// #212121 / #2C2C2E`），各色之间只有"系统默认"关系、没有统一灰阶。新色板收敛为
/// **单一条中性灰阶**：背景色只分"页面 / 卡片 / 按钮"三档，文字只分"主 / 次"两档，
/// 深浅色一一对应（浅色 `F2F3F5→FFFFFF→E7E8EA` / 深色 `010101→191919→191919`）。
/// 次级文字由 `#99FFFFFF`（半透明白）改为**实色 `#A3A3A3`**——半透明文字在毛玻璃/
/// 光感材质上会与背后的模糊内容混色，实色才能保证恒定对比度。
export class ThemeColors {
  background: string = '#F2F3F5';
  surface: string = '#FFFFFF';
  textPrimary: string = '#000000';
  textSecondary: string = '#666666';
  accent: string = '#E60012';
  tabBarBg: string = '#F2F3F5';
  tabBarActive: string = '#E60012';
  /// 底部导航**未选中**图标/文字色（2026-10-01 用户定案：纯黑 / 纯白）。
  /// 旧值 `#8E8E93`（系统灰）在光感悬浮底栏上半透明材质底上发灰、辨识度低；
  /// 改纯黑（浅色）/ 纯白（深色）——选中仍是主题色，未选中走最高对比中性色。
  /// 两态同时消费本 token（TabItemBuilder 的 SFIcon + 文字），改一处全局生效
  tabBarInactive: string = '#000000';
  divider: string = '#E7E8EA';
  /// **卡片内部分割线**：比 `divider` 淡一档（浅色 5% 黑 / 深色 8% 白）。
  /// 卡片底是半透明材质/毛玻璃，用 20% 级的 divider 会"一条条线压在玻璃上"（用户实测反馈）
  /// → 卡片**内部**的行分隔线只走本档（口径参考 Icey-Days，2026-09-13）。
  /// 例外：搜索框/输入框自身描边、弹窗卡片描边、Slider.trackColor 仍用 `divider`，别误改
  cardDivider: string = '#0D000000';
  cardBg: string = '#FFFFFF';
  /// **普通按钮底色**（2026-10-01 新增）——**非 primary 按钮**（弹窗「取消」、
  /// 次级圆形图标按钮等）专用；primary 仍走 `accent`（红底白字）。
  /// 语义：按钮是"可点击的浅色块"，需要与卡片（`cardBg`）区分出**一档**灰
  /// ——浅色下卡片纯白、按钮 `#E7E8EA`；深色下二者同为 `#191919`（深色模式
  /// 靠文字色与描边区分层级，不再叠灰度，否则暗部层次糊成一团）。
  buttonBg: string = '#E7E8EA';
  miniPlayerBg: string = '#E6F2F2F2';
  /// 占位封面/卡片背景色（无封面时的默认色块）。比页面背景深一档，列表里能看出边界
  placeholderBg: string = '#E7E8EA';
  /// 输入框/搜索框边框色（深浅适配：浅色用半透明黑、深色用半透明白，参考 MusicHome 搜索框带边框）
  fieldBorder: string = '#1A000000';
  /// **输入类容器底色（2026-10-07 新增）**：搜索框 / 分段控件轨道 / 标签胶囊未选中态
  /// 的统一灰档。语义对齐 Icey-Reader 同名 token（`ThemeColors.inputFill`）——
  /// 半透明灰（浅色 20% 黑 / 深色 20% 白），半透明是为了让下层的光感材质透出来
  /// （材质可用时底色必须 `Color.Transparent`，本档只在材质不可用时兜底）。
  /// ⚠️ 与 `buttonBg` 的区别：`buttonBg` 是**按钮**（有边框/可点语义、实色）；
  /// 本档是**输入类容器**（内凹感、无边框、半透明）。
  inputFill: string = '#33000000';
  /// **分段控件「选中药丸」底色（2026-10-07 新增，明度差方案）**：
  /// 与轨道（`inputFill`）拉开**一档明度**表达选中，不用高亮色——`accent` 的语义是
  /// 主行动色（primary 按钮 / 选中导航），分段控件是"视图切换"不是"行动"
  /// （Icey-Reader 2026-10-06 用户定案「不要用高亮色」，本工程同步该口径）。
  /// 浅色 `#E7E8EA`（比半透明灰轨道实一档）/ 深色 `#3A3A3A`（比轨道亮一档）。
  segmentSelectedBg: string = '#E7E8EA';

  static dark(): ThemeColors {
    const c = new ThemeColors();
    c.background = '#010101';
    c.surface = '#191919';
    c.textPrimary = '#FFFFFF';
    c.textSecondary = '#A3A3A3';
    c.accent = '#E60012';
    c.tabBarBg = '#010101';
    c.tabBarActive = '#E60012';
    c.tabBarInactive = '#FFFFFF';
    c.divider = '#2A2A2A';
    c.cardDivider = '#14FFFFFF';
    c.cardBg = '#191919';
    c.buttonBg = '#191919';
    c.miniPlayerBg = '#CC191919';
    c.placeholderBg = '#262626';
    c.fieldBorder = '#33FFFFFF';
    // 分段控件：轨道半透明白（材质透出）+ 药丸亮一档灰（深色下若同值则选中态看不见）
    c.inputFill = '#33FFFFFF';
    c.segmentSelectedBg = '#3A3A3A';
    return c;
  }

  static light(): ThemeColors {
    return new ThemeColors();
  }
}

export class ThemeManager {
  static isDark: boolean = false;
  static colors: ThemeColors = ThemeColors.light();

  /// （业务色常量放这里：如会员金、品牌金等。模板不预置——加色前先问"是不是全局语义"。）

  /// 不透明主题背景（弹窗等需要纯色不透明背景的场景专用）。
  /// 注意：colors.background 在有自定义背景时会被 applyThemeMode 改成半透明（#B3...）
  /// 让首页背景图透出——弹窗若直接引用它会出现"弹窗背景透明"（用户反馈的问题）。
  /// 此处按 isDark 返回原始不透明背景色（浅 #F2F3F5 / 深 #010101）
  static get opaqueBackground(): string {
    return ThemeManager.isDark ? '#010101' : '#F2F3F5';
  }

  /// colorMode: 兼容 number（resourceManager/ConfigurationConstant：DARK=0, LIGHT=1, NOT_SET=-1）
  /// 和 string('dark'/'light'/'DARK'/'LIGHT')
  /// 注意：旧代码用 colorMode===2 判深色是错的（DARK 实际=0），已修正为 ===0
  static updateFromConfig(colorMode: number | string): void {
    if (typeof colorMode === 'string') {
      ThemeManager.isDark = colorMode === 'dark' || colorMode === 'DARK';
    } else {
      ThemeManager.isDark = colorMode === 0; // DARK=0
    }
    ThemeManager.colors = ThemeManager.isDark ? ThemeColors.dark() : ThemeColors.light();
  }

  /// 按用户主题模式 + 系统深浅色计算 isDark（深浅色**纯由用户决定**，壁纸不再干预）
  /// themeMode: 0=跟随系统 1=浅色 2=深色
  /// systemColorMode: 跟随系统分支用的系统真实色（DARK=0 / LIGHT=1；仅 Follow 时有意义）
  /// **自定义背景生效判定**：开关开 + 当前深浅模式对应槽位壁纸非空 → background 半透明让壁纸透出。
  /// 有壁纸但槽位空（如只设了浅色壁纸、当前是深色模式）→ 回落主题实色（不是半透明黑）。
  static applyThemeMode(themeMode: number, systemColorMode: number | string): void {
    let isDark: boolean;
    if (themeMode === 1) {
      isDark = false; // 浅色
    } else if (themeMode === 2) {
      isDark = true; // 深色
    } else {
      // 跟随系统：DARK=0
      if (typeof systemColorMode === 'string') {
        isDark = systemColorMode === 'dark' || systemColorMode === 'DARK';
      } else {
        isDark = systemColorMode === 0;
      }
    }
    ThemeManager.isDark = isDark;
    ThemeManager.colors = isDark ? ThemeColors.dark() : ThemeColors.light();
    // 自定义背景开启且当前模式槽位有壁纸 → background 半透明，让根 Stack 底层的壁纸透出
    // （cardBg 等保持实色保证可读；opaqueBackground 提供弹窗等场景的不透明背景）
    if (ThemeManager.customBgEffective()) {
      // 70% 主题色覆盖在壁纸图上：图清晰可见，文字仍可读
      ThemeManager.colors.background = isDark ? '#B3010101' : '#B3F2F3F5';
    }
    // 写 AppStorage themeIsDark：各页面 @StorageLink('themeIsDark') 据此重建，重新读 ThemeManager.colors
    // （ThemeManager.colors 是 static 非响应式，必须靠 AppStorage 信号触发组件重绘）
    AppStorage.setOrCreate<boolean>('themeIsDark', isDark);
    // 额外写 themeColorsVersion：每次 applyThemeMode 都 +1，强制各 tab 页重建。
    // 因为 isDark 值可能不变（如浅色→浅色），themeIsDark 相同值不触发重建，
    // 但自定义背景开/关时 background 从不透明变半透明，需重建才能用新值。version 永远递增保证触发。
    AppStorage.setOrCreate<number>('themeColorsVersion',
      (AppStorage.get<number>('themeColorsVersion') ?? 0) + 1);
  }

  /// 自定义背景是否生效（2026-09-09 双壁纸改造）：
  /// 开关开 + 当前深浅模式对应槽位壁纸非空。壁纸键直接读 AppStorage（避免 SettingsManager↔ThemeManager import 环）；
  /// 深浅由**调用 applyThemeMode 后刚写入的 this.isDark** 决定（与当前生效主题一致）。
  static customBgEffective(): boolean {
    if (!(AppStorage.get<boolean>('settings_customBgEnabled') ?? false)) return false;
    const uri = ThemeManager.isDark
      ? (AppStorage.get<string>('settings_customBgDarkUri') ?? '')
      : (AppStorage.get<string>('settings_customBgLightUri') ?? '');
    return uri.length > 0;
  }

  /// 当前深浅模式应显示的壁纸 uri（空串 = 无壁纸/未设该槽位）。
  /// UI 显示层（12 处 settings_customBgUri 消费点）零改动的前提：**生效 uri 统一由
  /// SettingsManager.resolveEffectiveCustomBg() 解析后写入 settings_customBgUri**，
  /// UI 只读这一个键；本方法供该解析函数复用。
  static customBgSlotUri(isDark: boolean): string {
    return isDark
      ? (AppStorage.get<string>('settings_customBgDarkUri') ?? '')
      : (AppStorage.get<string>('settings_customBgLightUri') ?? '');
  }
}
