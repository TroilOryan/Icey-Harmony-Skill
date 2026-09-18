/// 主题管理（跟随系统 / 手动深浅色；自定义背景时按背景亮度自动判定）
/// 用法铁律：
/// - ThemeManager.colors 是 static 非响应式——组件重绘靠 AppStorage 信号驱动：
///   组件 @StorageLink('themeColorsVersion')，版本号 +1 触发重建后重读 colors
/// - colors.background 在有自定义背景时是半透明（背景图透出用）——弹窗等需要
///   纯色不透明背景的场景用 opaqueBackground
export class ThemeColors {
  background: string = '#F2F3F4';
  surface: string = '#F5F5F5';
  textPrimary: string = '#000000';
  textSecondary: string = '#666666';
  accent: string = '#0A59F7';
  tabBarBg: string = '#F2F2F7';
  tabBarActive: string = '#0A59F7';
  tabBarInactive: string = '#8E8E93';
  divider: string = '#E5E5EA';
  cardBg: string = '#FFFFFF';
  /// 占位色块（无图时的默认色块，比页面背景深一档能看出边界）
  placeholderBg: string = '#E5E5EA';
  /// 输入框/搜索框边框色（浅色半透明黑、深色半透明白）
  fieldBorder: string = '#1A000000';

  static dark(): ThemeColors {
    const c = new ThemeColors();
    c.background = '#000000';
    c.surface = '#1C1C1E';
    c.textPrimary = '#FFFFFF';
    c.textSecondary = '#99FFFFFF';
    c.accent = '#0A59F7';
    c.tabBarBg = '#1C1C1E';
    c.tabBarActive = '#0A59F7';
    c.tabBarInactive = '#8E8E93';
    c.divider = '#33FFFFFF';
    c.cardBg = '#212121';
    c.placeholderBg = '#2C2C2E';
    c.fieldBorder = '#33FFFFFF';
    return c;
  }

  static light(): ThemeColors {
    return new ThemeColors();
  }
}

export class ThemeManager {
  static isDark: boolean = false;
  static colors: ThemeColors = ThemeColors.light();
  /// 是否有自定义背景（CustomBgManager 维护；无背景 = false）
  static hasCustomBg: boolean = false;

  /// 不透明主题背景（弹窗等纯色不透明场景专用）。
  /// 注意：colors.background 有自定义背景时是半透明——弹窗直接引用会"弹窗背景透明"
  static get opaqueBackground(): string {
    return ThemeManager.isDark ? '#000000' : '#F2F3F4';
  }

  /// colorMode: 兼容 number（DARK=0, LIGHT=1, NOT_SET=-1）和 string('dark'/'light')
  /// 注意：DARK 实际=0（不是 2）
  static updateFromConfig(colorMode: number | string): void {
    if (typeof colorMode === 'string') {
      ThemeManager.isDark = colorMode === 'dark' || colorMode === 'DARK';
    } else {
      ThemeManager.isDark = colorMode === 0; // DARK=0
    }
    ThemeManager.colors = ThemeManager.isDark ? ThemeColors.dark() : ThemeColors.light();
    ThemeManager.bumpVersion();
  }

  /// 按主题模式 + 系统深浅色计算 isDark 并广播重建
  /// themeMode: 0=跟随系统 1=浅色 2=深色
  /// hasCustomBg + customBgIsLight: 有自定义背景时，主题由背景亮度决定（覆盖用户选择）
  static applyThemeMode(themeMode: number, systemColorMode: number | string,
    hasCustomBg: boolean = false, customBgIsLight: boolean = false): void {
    let isDark: boolean;
    if (hasCustomBg) {
      // 自定义背景：深色背景→深色模式，浅色背景→浅色模式
      isDark = !customBgIsLight;
    } else if (themeMode === 1) {
      isDark = false;
    } else if (themeMode === 2) {
      isDark = true;
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
    // 有自定义背景时 background 设半透明，根 Stack 底层背景图透出（cardBg 保持实色保证可读）
    if (hasCustomBg) {
      ThemeManager.colors.background = isDark ? '#B3000000' : '#B3F1F3F5';
    }
    // version 每次 +1：保证 isDark 值不变（浅→浅）时也能触发重建（如 background 半透明变化）
    ThemeManager.bumpVersion();
  }

  /// 广播主题版本信号：组件 @StorageLink('themeColorsVersion') 触发重建重读 colors
  static bumpVersion(): void {
    AppStorage.setOrCreate<boolean>('themeIsDark', ThemeManager.isDark);
    AppStorage.setOrCreate<number>('themeColorsVersion',
      (AppStorage.get<number>('themeColorsVersion') ?? 0) + 1);
  }
}
