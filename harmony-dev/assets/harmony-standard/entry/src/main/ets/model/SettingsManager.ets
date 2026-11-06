/// 设置管理（preferences 持久化：增量写 + 300ms 防抖 + flush；启动异步加载 + waitReady 门闸）
///
/// ## 新增一个设置项 = **七件套**（缺任何一件 = 静默失效，编译器不报错）
///   ① 键常量 `const XXX_KEY = 'settings_xxx';`
///   ② `SettingsRecord` 加字段
///   ③ `init()` 里 `AppStorage.setOrCreate(XXX_KEY, 默认值)`（**键不存在时 applyRecord 的 set 无效**，
///      且 @StorageLink 初值时序不可靠——必须先 setOrCreate）
///   ④ `readFromPrefs()` 读盘（`num/bool/str(k, 默认值)`）
///   ⑤ `applyRecord()` 回填 AppStorage（`!== undefined` 守卫）
///   ⑥ `flushToPrefs()` 里 `p.putSync(XXX_KEY, ...)` 落盘
///   ⑦ static getter/setter（setter 内 `this.save()`；**低频但绝不能丢的项改调 saveNow()**）
///   UI 侧统一 `@StorageLink('settings_xxx')` 读；**渲染路径禁止读 static getter**（非响应式依赖，
///   键变化不触发组件重跑）——static getter 只能在事件回调/非渲染路径用。
///
/// ## 主题铁律（本文件是唯一出口）
/// - `applyColorMode()` 是**唯一** `context.setColorMode` 出口；**跟随系统必须 NOT_SET**，
///   显式 DARK/LIGHT 会固定应用色导致系统切换时 $r 资源不跟随。
/// - **onConfigurationUpdate 里绝不能再 setColorMode**（会再次触发 onConfigurationUpdate → 无限循环，
///   曾启动连续几百次回调）。回调里只刷 ThemeManager 色板 + 系统栏字色。
/// - `context.config.colorMode` 会被 app 自己的 setColorMode(0/1) **污染**；读系统真实色用
///   `resourceManager.getConfiguration().colorMode`（异步补正已内置）或 `noteSystemColorMode` 缓存。
import { preferences } from '@kit.ArkData';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import uiMaterial from '@ohos.arkui.uiMaterial';
import common from '@ohos.app.ability.common';
import { ThemeManager } from './ThemeManager';
import { AppLogger } from '../services/AppLogger';

const PREF_NAME = 'settings_db';

/// 主题模式：0=跟随系统(默认) / 1=浅色 / 2=深色
const THEME_MODE_KEY = 'settings_themeMode';
/// 屏幕常亮（窗口级 setWindowKeepScreenOn；WindowHelper 消费）
const KEEP_SCREEN_ON_KEY = 'settings_keepScreenOn';
/// 沉浸光感材质挡位（Hds systemMaterialEffect.materialLevel 数值：0=强EXQUISITE 1=平衡GENTLE
/// 2=弱SMOOTH 10=自适应ADAPTIVE；默认 10。release 打包 Hds 枚举可能无导出 → **存取一律用数值**）
const MATERIAL_LEVEL_KEY = 'settings_materialLevel';
/// 光感自动反色（ImmersiveOptions.colorInvert；默认开。反色有硬门槛：材质必须够薄 THIN 以内）
const MATERIAL_COLOR_INVERT_KEY = 'settings_materialColorInvert';
/// **示例开关（教学用七件套样板）**：演示"新增一个设置项"的完整链路，正式开发可整段删除
const EXAMPLE_SWITCH_KEY = 'settings_exampleSwitch';
/// ===== 自定义背景（双槽位壁纸，功能钩子已预埋；选图/落盘管线见 NEW_APP_CHECKLIST）=====
/// 开关（默认关）；浅/深色各一张槽位（base64 data URI 或文件 uri；空 = 该模式用主题实色）
const CUSTOM_BG_ENABLED_KEY = 'settings_customBgEnabled';
const CUSTOM_BG_LIGHT_URI_KEY = 'settings_customBgLightUri';
const CUSTOM_BG_DARK_URI_KEY = 'settings_customBgDarkUri';
/// 壁纸模糊 0~100（默认 50）
const CUSTOM_BG_BLUR_KEY = 'settings_customBgBlur';
/// **派生键**：resolveEffectiveCustomBg 按「开关 + 当前深浅模式槽位」解析后写入；
/// 全部 UI 层只 @StorageLink 这一个键（语义 = 此刻显示哪张图），不读槽位
const CUSTOM_BG_URI_KEY = 'settings_customBgUri';

export const DEFAULT_CUSTOM_BG_BLUR: number = 50;
export const MAX_CUSTOM_BG_BLUR_RADIUS: number = 32;

/// 主题模式取值（class 静态常量，ArkTS 下比 enum 字面量兼容面更稳）
export class ThemeMode {
  static readonly Follow: number = 0;
  static readonly Light: number = 1;
  static readonly Dark: number = 2;
}

/// 沉浸光感材质场景（《组件适配沉浸光感》官方建议档位）：
///   search 浮动工具栏/搜索框（THIN~ULTRA_THIN）；menu 菜单/Toast/卡片（THICK）；
///   sheet 弹窗（ULTRA_THICK）；system 浮在列表上的小组件（对齐底栏 THIN）
/// ⚠️ ArkTS 禁止在 class 内 export type → 类型定义放文件头部 module 级
export type MaterialScope = 'search' | 'menu' | 'sheet' | 'system';

/// 设置快照（readFromPrefs 构建对象字面量必须对应显式 interface——arkts-no-untyped-obj-literals）
export interface SettingsRecord {
  themeMode: number;
  keepScreenOn: boolean;
  materialLevel: number;
  materialColorInvert: boolean;
  exampleSwitch: boolean;
  customBgEnabled: boolean;
  customBgLightUri: string;
  customBgDarkUri: string;
  customBgBlur: number;
}

export class SettingsManager {
  private static instance: SettingsManager;
  /// 持 UIAbilityContext（applyColorMode 需要 setColorMode/config；init 参数即 UIAbilityContext）
  private context: common.UIAbilityContext | null = null;
  private pref: preferences.Preferences | null = null;
  /// 防抖定时器：滑杆等高频变更合并为一次 flush，避免频繁 IO
  private saveTimer: number = -1;
  /// preferences 异步加载完成信号（waitReady await 用）：启动时序中依赖持久化值的场景必须先
  /// await——否则读到 setOrCreate 默认值（Icey 实证 bug：恢复比 getPreferences 快，排序恒为默认）
  private readyResolve: (() => void) | null = null;
  private readonly readyPromise: Promise<void> = new Promise<void>((resolve: () => void) => {
    this.readyResolve = resolve;
  });
  /// 上次 setColorMode 入参（-2=从未调用；-1=NOT_SET 跟随系统；0/1=app 强制 DARK/LIGHT）。
  /// 用于判断 context.config.colorMode 是否被 app 自身覆盖（污染判定，见 applyColorMode）
  private static lastSetColorMode: number = -2;
  /// 系统真实深浅色缓存（0=深 1=浅 -1=未知）：只在 app **未被** setColorMode(0/1) 污染时更新
  private static lastSystemColor: number = -1;

  private constructor() {}

  static getInstance(): SettingsManager {
    if (!SettingsManager.instance) {
      SettingsManager.instance = new SettingsManager();
    }
    return SettingsManager.instance;
  }

  /// 启动初始化（EntryAbility.onCreate **第一个**调用——设置持久化优先级最高，不依赖其他模块）：
  /// 先同步 setOrCreate 全部默认值（UI 立即可用），再异步读盘覆盖
  init(context: common.UIAbilityContext): void {
    this.context = context;
    AppStorage.setOrCreate<number>(THEME_MODE_KEY, ThemeMode.Follow);
    AppStorage.setOrCreate<boolean>(KEEP_SCREEN_ON_KEY, false);
    AppStorage.setOrCreate<number>(MATERIAL_LEVEL_KEY, 10);
    AppStorage.setOrCreate<boolean>(MATERIAL_COLOR_INVERT_KEY, true);
    AppStorage.setOrCreate<boolean>(EXAMPLE_SWITCH_KEY, false);
    AppStorage.setOrCreate<boolean>(CUSTOM_BG_ENABLED_KEY, false);
    AppStorage.setOrCreate<string>(CUSTOM_BG_LIGHT_URI_KEY, '');
    AppStorage.setOrCreate<string>(CUSTOM_BG_DARK_URI_KEY, '');
    AppStorage.setOrCreate<number>(CUSTOM_BG_BLUR_KEY, DEFAULT_CUSTOM_BG_BLUR);
    AppStorage.setOrCreate<string>(CUSTOM_BG_URI_KEY, '');
    // 异步读盘 → applyRecord → 再应用一次颜色模式（启动首次 applyColorMode 早于持久化回填，
    // themeMode 与盘里不一致时这里纠正；"重启后主题模式没记住"的根因就是缺这一步）
    preferences.getPreferences(context, PREF_NAME).then((p: preferences.Preferences) => {
      this.pref = p;
      try {
        this.applyRecord(this.readFromPrefs(p));
        SettingsManager.applyColorMode(context);
      } catch (e) {
        console.error('SettingsManager applyLoaded failed: ' + JSON.stringify(e));
      }
      // 加载完成（无论成功失败都放行 waitReady，避免启动卡死）
      if (this.readyResolve) {
        this.readyResolve();
        this.readyResolve = null;
      }
    }).catch((e: Error) => {
      console.error('SettingsManager getPreferences failed: ' + JSON.stringify(e));
      if (this.readyResolve) {
        this.readyResolve();
        this.readyResolve = null;
      }
    });
  }

  /// 等待 preferences 异步加载完成（启动时序依赖持久化值的场景必须 await）
  async waitReady(): Promise<void> {
    await this.readyPromise;
  }

  /// 从 preferences 读全部设置项，构建 record（不存在的 key 取默认值）
  private readFromPrefs(p: preferences.Preferences): SettingsRecord {
    const num = (k: string, d: number): number => p.getSync(k, d) as number;
    const bool = (k: string, d: boolean): boolean => p.getSync(k, d) as boolean;
    const str = (k: string, d: string): string => p.getSync(k, d) as string;
    return {
      themeMode: num(THEME_MODE_KEY, ThemeMode.Follow),
      keepScreenOn: bool(KEEP_SCREEN_ON_KEY, false),
      materialLevel: num(MATERIAL_LEVEL_KEY, 10),
      materialColorInvert: bool(MATERIAL_COLOR_INVERT_KEY, true),
      exampleSwitch: bool(EXAMPLE_SWITCH_KEY, false),
      customBgEnabled: bool(CUSTOM_BG_ENABLED_KEY, false),
      customBgLightUri: str(CUSTOM_BG_LIGHT_URI_KEY, ''),
      customBgDarkUri: str(CUSTOM_BG_DARK_URI_KEY, ''),
      customBgBlur: num(CUSTOM_BG_BLUR_KEY, DEFAULT_CUSTOM_BG_BLUR),
    };
  }

  /// 把 record 回填 AppStorage（字段为 undefined 的跳过，保留默认值）
  private applyRecord(record: SettingsRecord | null): void {
    if (!record) return;
    if (record.themeMode !== undefined) {
      AppStorage.set<number>(THEME_MODE_KEY, record.themeMode);
    }
    if (record.keepScreenOn !== undefined) {
      AppStorage.set<boolean>(KEEP_SCREEN_ON_KEY, record.keepScreenOn);
    }
    if (record.materialLevel !== undefined) {
      AppStorage.set<number>(MATERIAL_LEVEL_KEY, record.materialLevel);
    }
    if (record.materialColorInvert !== undefined) {
      AppStorage.set<boolean>(MATERIAL_COLOR_INVERT_KEY, record.materialColorInvert);
    }
    if (record.exampleSwitch !== undefined) {
      AppStorage.set<boolean>(EXAMPLE_SWITCH_KEY, record.exampleSwitch);
    }
    if (record.customBgEnabled !== undefined) {
      AppStorage.set<boolean>(CUSTOM_BG_ENABLED_KEY, record.customBgEnabled);
    }
    if (record.customBgLightUri !== undefined) {
      AppStorage.set<string>(CUSTOM_BG_LIGHT_URI_KEY, record.customBgLightUri);
    }
    if (record.customBgDarkUri !== undefined) {
      AppStorage.set<string>(CUSTOM_BG_DARK_URI_KEY, record.customBgDarkUri);
    }
    if (record.customBgBlur !== undefined) {
      AppStorage.set<number>(CUSTOM_BG_BLUR_KEY, record.customBgBlur);
    }
    SettingsManager.resolveEffectiveCustomBg();
  }

  /// 设置变更落盘：防抖 300ms 合并高频变更，一次 flush 写盘（preferences 增量写，原子）
  private save(): void {
    if (!this.pref) return;
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer);
    }
    this.saveTimer = setTimeout(() => {
      this.saveTimer = -1;
      this.flushToPrefs();
    }, 300) as number;
  }

  /// 立即落盘（清防抖定时器 + 同步 flush）：低频但**必须保证持久化**的场景（切档位/模式类
  /// 菜单项、退后台/销毁兜底）——防抖 300ms 内杀进程会丢（Icey 实证：排序丢 → "重启没生效"）
  public saveNow(): void {
    if (!this.pref) return;
    if (this.saveTimer !== -1) {
      clearTimeout(this.saveTimer);
      this.saveTimer = -1;
    }
    this.flushToPrefs();
  }

  /// 全量 putSync + flush（新增设置项时这里要同步加一行——见文件头七件套⑥）
  private flushToPrefs(): void {
    const p = this.pref;
    if (!p) return;
    try {
      p.putSync(THEME_MODE_KEY, SettingsManager.themeMode);
      p.putSync(KEEP_SCREEN_ON_KEY, SettingsManager.keepScreenOn);
      p.putSync(MATERIAL_LEVEL_KEY, SettingsManager.materialLevel);
      p.putSync(MATERIAL_COLOR_INVERT_KEY, SettingsManager.materialColorInvert);
      p.putSync(EXAMPLE_SWITCH_KEY, SettingsManager.exampleSwitch);
      p.putSync(CUSTOM_BG_ENABLED_KEY, SettingsManager.customBgEnabled);
      p.putSync(CUSTOM_BG_LIGHT_URI_KEY, SettingsManager.customBgLightUri);
      p.putSync(CUSTOM_BG_DARK_URI_KEY, SettingsManager.customBgDarkUri);
      p.putSync(CUSTOM_BG_BLUR_KEY, SettingsManager.customBgBlur);
      p.flush().catch((e: Error) => {
        console.error('SettingsManager flush failed: ' + JSON.stringify(e));
      });
    } catch (e) {
      console.error('SettingsManager flushToPrefs failed: ' + JSON.stringify(e));
    }
  }

  // ===== 通用读写小工具（新增项的 setter 长这样）=====

  private static setNumber(key: string, v: number, urgent: boolean = false): void {
    AppStorage.set<number>(key, v);
    if (urgent) {
      SettingsManager.getInstance().saveNow();
    } else {
      SettingsManager.getInstance().save();
    }
  }

  private static setBool(key: string, v: boolean, urgent: boolean = false): void {
    AppStorage.set<boolean>(key, v);
    if (urgent) {
      SettingsManager.getInstance().saveNow();
    } else {
      SettingsManager.getInstance().save();
    }
  }

  private static setString(key: string, v: string): void {
    AppStorage.set<string>(key, v);
    SettingsManager.getInstance().save();
  }

  // ===== 各设置项（七件套的⑦）=====

  /// 主题模式（0 跟随系统 / 1 浅色 / 2 深色）
  static get themeMode(): number {
    return AppStorage.get<number>(THEME_MODE_KEY) ?? ThemeMode.Follow;
  }

  static setThemeMode(mode: number): void {
    if (mode !== ThemeMode.Follow && mode !== ThemeMode.Light && mode !== ThemeMode.Dark) return;
    SettingsManager.setNumber(THEME_MODE_KEY, mode, true);
    const ctx = SettingsManager.getInstance().context;
    if (ctx) {
      SettingsManager.applyColorMode(ctx);
    }
  }

  /// 屏幕常亮（播放/阅读等场景由页面开、退页面关；全局默认关）
  static get keepScreenOn(): boolean {
    return AppStorage.get<boolean>(KEEP_SCREEN_ON_KEY) ?? false;
  }

  static setKeepScreenOn(v: boolean): void {
    SettingsManager.setBool(KEEP_SCREEN_ON_KEY, v, true);
  }

  /// 沉浸光感挡位（0=强 1=平衡 2=弱 10=自适应；数值口径见 KEY 注释）
  static get materialLevel(): number {
    return AppStorage.get<number>(MATERIAL_LEVEL_KEY) ?? 10;
  }

  static setMaterialLevel(lv: number): void {
    if (lv !== 0 && lv !== 1 && lv !== 2 && lv !== 10) return;
    SettingsManager.setNumber(MATERIAL_LEVEL_KEY, lv, true);
  }

  /// 光感自动反色开关
  static get materialColorInvert(): boolean {
    return AppStorage.get<boolean>(MATERIAL_COLOR_INVERT_KEY) ?? true;
  }

  static setMaterialColorInvert(v: boolean): void {
    SettingsManager.setBool(MATERIAL_COLOR_INVERT_KEY, v, true);
  }

  /// 示例开关（教学样板：展示 getter/setter 与 setBool 的标准接法）
  static get exampleSwitch(): boolean {
    return AppStorage.get<boolean>(EXAMPLE_SWITCH_KEY) ?? false;
  }

  static setExampleSwitch(v: boolean): void {
    SettingsManager.setBool(EXAMPLE_SWITCH_KEY, v);
  }

  // ===== 自定义背景（双槽位，功能钩子）=====

  static get customBgEnabled(): boolean {
    return AppStorage.get<boolean>(CUSTOM_BG_ENABLED_KEY) ?? false;
  }

  static get customBgLightUri(): string {
    return AppStorage.get<string>(CUSTOM_BG_LIGHT_URI_KEY) ?? '';
  }

  static get customBgDarkUri(): string {
    return AppStorage.get<string>(CUSTOM_BG_DARK_URI_KEY) ?? '';
  }

  static get customBgBlur(): number {
    return AppStorage.get<number>(CUSTOM_BG_BLUR_KEY) ?? DEFAULT_CUSTOM_BG_BLUR;
  }

  /// 0~100 → 0~32vp 模糊半径（0 不模糊）
  static customBgBlurRadius(v: number): number {
    return Math.max(0, Math.min(100, v)) / 100 * MAX_CUSTOM_BG_BLUR_RADIUS;
  }

  /// 解析「当前生效壁纸」写入 settings_customBgUri（UI 显示层唯一消费键）：
  /// 开关开 + 当前深浅模式槽位有壁纸 → 写该槽位 uri；否则写空串。
  /// 深浅模式变化（applyColorMode/onConfigurationUpdate）后必须重跑一次。
  static resolveEffectiveCustomBg(): void {
    let uri = '';
    if (SettingsManager.customBgEnabled) {
      uri = ThemeManager.isDark ? SettingsManager.customBgDarkUri : SettingsManager.customBgLightUri;
    }
    if (uri !== (AppStorage.get<string>(CUSTOM_BG_URI_KEY) ?? '')) {
      AppStorage.set<string>(CUSTOM_BG_URI_KEY, uri);
      // 生效壁纸变化 → 背景从实色 ↔ 半透明切换，强制全应用重建（themeColorsVersion 消费方见各页）
      AppStorage.setOrCreate<number>('themeColorsVersion',
        (AppStorage.get<number>('themeColorsVersion') ?? 0) + 1);
    }
  }

  // ===== 主题：应用颜色模式（唯一 setColorMode 出口）=====

  /// 缓存系统真实深浅色（onConfigurationUpdate 调用；app 已被 setColorMode(0/1) 污染时不更新）
  static noteSystemColorMode(cm: number): void {
    if (cm !== 0 && cm !== 1) return;
    if (SettingsManager.lastSetColorMode === 0 || SettingsManager.lastSetColorMode === 1) return;
    SettingsManager.lastSystemColor = cm;
  }

  /// 校正后的系统真实深浅色（0=深 1=浅 -1=未知）
  static get systemColor(): number {
    return SettingsManager.lastSystemColor;
  }

  /// 应用颜色模式到系统（让 $r 系统资源/状态栏也跟随）。EntryAbility 启动 / 主题设置变化 /
  /// onForeground 兜底 三处调用；onConfigurationUpdate **禁止**调它（无限循环）。
  static applyColorMode(context: common.UIAbilityContext): void {
    // 系统真实色：**setColorMode 之前**读 config（未干预时 = 系统色 0/1）
    let sysColor: number = -1;
    try {
      const cfg0 = context.config;
      if (cfg0) {
        const cm0 = cfg0.colorMode;
        if (cm0 !== undefined && cm0 !== null) sysColor = cm0 as number;
      }
    } catch (_) {}
    const polluted = SettingsManager.lastSetColorMode === 0 || SettingsManager.lastSetColorMode === 1;
    if (polluted) {
      // app 自己设过 0/1 → config.colorMode 是覆盖值不是系统真实色，用缓存
      sysColor = SettingsManager.lastSystemColor;
    } else if (sysColor === 0 || sysColor === 1) {
      // 只在"从未 setColorMode"（启动首次）时缓存——之后 config 可能被系统事件误报污染
      if (SettingsManager.lastSetColorMode === -2) {
        SettingsManager.lastSystemColor = sysColor;
      }
    }
    let colorMode: number;
    const tm = SettingsManager.themeMode;
    if (tm === ThemeMode.Light) {
      colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    } else if (tm === ThemeMode.Dark) {
      colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } else {
      // 跟随系统：NOT_SET（不干预，$r 系统资源自动跟随系统深浅切换）
      colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    }
    try {
      context.setColorMode(colorMode);
      SettingsManager.lastSetColorMode = colorMode;
    } catch (e) {
      console.error('SettingsManager.applyColorMode failed: ' + JSON.stringify(e));
    }
    // 幂等防抖（亮屏闪烁根因）：applyThemeMode 会 themeColorsVersion+1 强制全应用重建，
    // isDark 没变就跳过（onForeground 每次都调本方法）
    const nextDark: boolean = tm === ThemeMode.Light ? false
      : (tm === ThemeMode.Dark ? true : (sysColor === 0));
    if (nextDark !== ThemeManager.isDark) {
      if (tm === ThemeMode.Follow) {
        if (sysColor === 0 || sysColor === 1) {
          ThemeManager.applyThemeMode(ThemeMode.Follow, sysColor);
          SettingsManager.resolveEffectiveCustomBg();
        }
      } else {
        ThemeManager.applyThemeMode(tm, 1);
        SettingsManager.resolveEffectiveCustomBg();
      }
    }
    // **异步补正**：resourceManager.getConfiguration().colorMode 返回系统真实色、不受 app
    // setColorMode 污染——Follow 分支拿不到同步系统色时靠它兜底（"清除壁纸后主题回不到跟随系统"的根因修复）
    if (colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET) {
      context.resourceManager.getConfiguration().then((value: object) => {
        const cm = (value as Record<string, number>)['colorMode'];
        if ((cm === 0 || cm === 1) && ((cm === 0) !== ThemeManager.isDark)) {
          ThemeManager.applyThemeMode(ThemeMode.Follow, cm);
          SettingsManager.resolveEffectiveCustomBg();
          AppLogger.info('Theme', `applyColorMode 异步补正 cm=${cm} isDark=${ThemeManager.isDark}`);
        }
      }).catch((e: Error) => {
        console.error('SettingsManager async color correct failed: ' + JSON.stringify(e));
      });
    }
    AppLogger.info('Theme', `applyColorMode themeMode=${tm} sysColor=${sysColor} isDark=${ThemeManager.isDark}`);
  }

  // ===== 沉浸光感材质（安全构造；API<26 一律 undefined，UI 用 materialAvailable 兜底毛玻璃/实色）=====

  /// ImmersiveMaterial @since 26.0.0：API<26 类未导出 = undefined，直接 new 报
  /// "Constructor is false" 闪退（真机实证）——任何 new 前必须过本闸
  static materialAvailable(): boolean {
    return deviceInfo.sdkApiVersion >= 26;
  }

  /// 材质着色（systemMaterial materialColor，按挡位 + 深浅色）：
  /// **强=最透（22% 着色），弱=最实（50% 着色）**——「强」= 材质更薄更透，与 Hds EXQUISITE 同向
  static systemMaterialColor(): string {
    const lv = SettingsManager.materialLevel;
    let alpha: string = '6B'; // 42%（自适应）
    if (lv === 0) alpha = '38'; // 22%（强）
    else if (lv === 1) alpha = '59'; // 35%（平衡）
    else if (lv === 2) alpha = '80'; // 50%（弱）
    return ThemeManager.isDark ? `#${alpha}000000` : `#${alpha}FFFFFF`;
  }

  /// 按场景取 ImmersiveStyle 数值，跟随全局挡位并在该场景建议区间内浮动
  /// ImmersiveStyle：0=ULTRA_THIN 1=THIN 2=REGULAR 3=THICK 4=ULTRA_THICK
  /// sheet：REGULAR~ULTRA_THICK（官方默认 ULTRA_THICK）；menu：THIN~THICK（默认 THICK）；
  /// search：ULTRA_THIN~REGULAR（默认 THIN；开反色必须夹薄到 THIN 以内才够官方门槛）
  static systemMaterialStyleFor(scope: MaterialScope): number {
    const lv = SettingsManager.materialLevel;
    if (scope === 'sheet') {
      return lv === 0 ? 2 : (lv === 1 ? 3 : 4);
    }
    if (scope === 'menu') {
      return lv === 0 ? 1 : (lv === 1 ? 2 : 3);
    }
    const base = lv === 0 ? 0 : (lv === 1 ? 1 : 2);
    return SettingsManager.materialColorInvert ? Math.min(base, 1) : base;
  }

  /// 安全构造「指定场景」材质（API<26 返回 undefined；systemMaterial 属性接受 undefined 即忽略不崩）
  static materialFor(scope: MaterialScope): uiMaterial.ImmersiveMaterial | undefined {
    if (!SettingsManager.materialAvailable()) return undefined;
    if (scope === 'system') {
      return SettingsManager.materialSystem(1);
    }
    return new uiMaterial.ImmersiveMaterial({
      style: SettingsManager.systemMaterialStyleFor(scope),
      materialColor: SettingsManager.systemMaterialColor(),
      colorInvert: SettingsManager.materialColorInvert,
      applyShadow: true,
    });
  }

  /// 跟随系统策略的薄材质：裸 new ImmersiveMaterial 默认 REGULAR(2)，比标题栏系统策略厚两档
  /// （用户实测"自适应卡片明显比标题栏更不透明"的根因）。自适应卡片 materialSystem(0)、
  /// 浮列表小组件 materialSystem(1)，禁止回退"裸材质=跟随系统"的旧结论
  static materialSystem(style: number = 1): uiMaterial.ImmersiveMaterial | undefined {
    if (!SettingsManager.materialAvailable()) return undefined;
    return new uiMaterial.ImmersiveMaterial({
      style: style,
      materialColor: Color.Transparent,
      applyShadow: true,
    });
  }

  /// 弹窗面板的「实际观感底色」：材质可用时面板 = 材质提亮后的 surface（比背景亮一档）；
  /// 不可用时面板就是实色背景。给压在面板上的自绘浮层（标题带渐变等）取基色用
  static sheetSurfaceColor(): string {
    if (!SettingsManager.materialAvailable()) return ThemeManager.opaqueBackground;
    return ThemeManager.colors.surface;
  }
}
