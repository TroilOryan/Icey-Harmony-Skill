/// 设置管理（持久化到 @kit.ArkData preferences——系统级键值存储，增量写 + 原子性）
/// 通用骨架：新增设置项三步——
///   ① 加 KEY 常量 + SettingsRecord 字段 + 默认值
///   ② init 的 waitReady 后回填 AppStorage（UI @StorageLink 响应式）
///   ③ 加 setter（set + save() 防抖落盘）
/// 落盘策略：save() 防抖 300ms 合并高频变更；onBackground/onDestroy 调 saveNow() 强制落盘
/// （防抖未到期就杀进程 → 设置丢失，必须双保险）
import { preferences } from '@kit.ArkData';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import common from '@ohos.app.ability.common';
import uiMaterial from '@ohos.arkui.uiMaterial';
import { ThemeManager } from './ThemeManager';
import { AppLogger } from '../services/AppLogger';

const PREF_NAME = 'settings_db';
/// 示例键（按需增删）
const EXAMPLE_SWITCH_KEY = 'settings_exampleSwitch';
const HANDEDNESS_KEY = 'settings_handedness';
const MATERIAL_LEVEL_KEY = 'settings_materialLevel';
const MATERIAL_COLOR_INVERT_KEY = 'settings_materialColorInvert';
const THEME_MODE_KEY = 'settings_themeMode';
const VERSION_KEY = 'version';

/// 主题模式枚举
export enum ThemeMode {
  Follow = 0,
  Light = 1,
  Dark = 2,
}

/// 材质场景：搜索框 / 菜单卡片 / 弹窗 / 跟随系统策略
/// 每个场景在官方建议的 ImmersiveStyle 区间内浮动（见 systemMaterialStyleFor）
export type MaterialScope = 'search' | 'menu' | 'sheet' | 'system';

interface SettingsRecord {
  exampleSwitch: boolean;
  /// 智感握姿（底部导航栏跟随握持手方向镜像）
  handedness: boolean;
  /// 沉浸光感材质挡位（0强/1平衡/2弱/10自适应，Hds systemMaterialEffect.materialLevel）
  materialLevel: number;
  /// 材质自动反色（由系统按背景亮度自动决定前景色）
  materialColorInvert: boolean;
  themeMode: number;
}

export class SettingsManager {
  private static dir: string = '';
  private static pref: preferences.Preferences | null = null;
  /// init 异步完成信号（EntryAbility await waitReady 后再做依赖设置的事）
  private static ready: Promise<void> = Promise.resolve();
  /// 内存态（同步读）
  private static rec: SettingsRecord = {
    exampleSwitch: false,
    handedness: false,
    materialLevel: 10,
    materialColorInvert: true,
    themeMode: 0,
  };
  /// 防抖定时器
  private static saveTimer: number = -1;

  // ===== 内存态 getter（同步；UI 响应式读 AppStorage 键，UI 层用 @StorageLink）=====

  static get exampleSwitch(): boolean { return SettingsManager.rec.exampleSwitch; }
  static get materialLevel(): number { return SettingsManager.rec.materialLevel; }
  static get materialColorInvert(): boolean { return SettingsManager.rec.materialColorInvert; }
  static get themeMode(): number { return SettingsManager.rec.themeMode; }
  /// init 是否就绪（异步加载完成）
  static get isReady(): boolean { return SettingsManager.pref !== null; }

  /// 启动初始化（EntryAbility.onCreate 调用，不 await）：建 pref → 异步读全量 → 回填 AppStorage
  /// 必须最先 init（其他模块依赖设置持久化）
  static init(context: common.Context): void {
    SettingsManager.dir = context.filesDir;
    SettingsManager.ready = (async (): Promise<void> => {
      try {
        SettingsManager.pref = await preferences.getPreferences(context, PREF_NAME);
        // 读全量回内存
        const r = SettingsManager.rec;
        r.exampleSwitch = SettingsManager.pref.getSync(EXAMPLE_SWITCH_KEY, r.exampleSwitch) as boolean;
        r.themeMode = SettingsManager.pref.getSync(THEME_MODE_KEY, r.themeMode) as number;
        r.materialColorInvert = SettingsManager.pref.getSync(MATERIAL_COLOR_INVERT_KEY, r.materialColorInvert) as boolean;
        // 回填 AppStorage（UI @StorageLink 响应式）
        SettingsManager.fillAppStorage();
      } catch (e) {
        AppLogger.error('SettingsManager', `init failed: ${JSON.stringify(e)}`);
      }
    })();
  }

  /// 等待异步加载完成（EntryAbility startupReady 第一步 await）
  static waitReady(): Promise<void> {
    return SettingsManager.ready;
  }

  /// 内存回填 AppStorage（UI 响应式源头）
  private static fillAppStorage(): void {
    AppStorage.setOrCreate<boolean>('settings_exampleSwitch', SettingsManager.rec.exampleSwitch);
    AppStorage.setOrCreate<boolean>('settings_handedness', SettingsManager.rec.handedness);
    AppStorage.setOrCreate<number>('settings_materialLevel', SettingsManager.rec.materialLevel);
    AppStorage.setOrCreate<boolean>('settings_materialColorInvert', SettingsManager.rec.materialColorInvert);
    AppStorage.setOrCreate<number>('settings_themeMode', SettingsManager.rec.themeMode);
  }

  // ===== setter（set 内存 + AppStorage + save 防抖落盘）=====

  static setExampleSwitch(v: boolean): void {
    SettingsManager.rec.exampleSwitch = v;
    AppStorage.setOrCreate<boolean>('settings_exampleSwitch', v);
    SettingsManager.save(EXAMPLE_SWITCH_KEY, v);
  }

  /// 智感握姿（底部导航栏 adaptToHandedness 实时切换）
  static setHandedness(v: boolean): void {
    SettingsManager.rec.handedness = v;
    AppStorage.setOrCreate<boolean>('settings_handedness', v);
    SettingsManager.save(HANDEDNESS_KEY, v);
  }

  /// 沉浸光感材质挡位（0强/1平衡/2弱/10自适应；Hds barFloatingStyle/titleBar 实时生效）
  static setMaterialLevel(v: number): void {
    SettingsManager.rec.materialLevel = v;
    AppStorage.setOrCreate<number>('settings_materialLevel', v);
    SettingsManager.save(MATERIAL_LEVEL_KEY, v);
  }

  /// 材质自动反色（系统按背景亮度自定前景色；关闭后前景色由调用方按亮度自控）
  static setMaterialColorInvert(v: boolean): void {
    SettingsManager.rec.materialColorInvert = v;
    AppStorage.setOrCreate<boolean>('settings_materialColorInvert', v);
    SettingsManager.save(MATERIAL_COLOR_INVERT_KEY, v);
  }

  /// 主题模式：0=跟随系统 1=浅色 2=深色（配合 ThemeManager.applyThemeMode 使用）
  static setThemeMode(v: number): void {
    SettingsManager.rec.themeMode = v;
    AppStorage.setOrCreate<number>('settings_themeMode', v);
    SettingsManager.save(THEME_MODE_KEY, v);
  }

  /// 应用颜色模式（EntryAbility onCreate + onWindowStageCreate 各调一次；onForeground 校正）：
  /// 强制 app 整体深浅色，让 $r 系统资源/状态栏跟随；0=跟随系统不设置
  static applyColorMode(context: common.Context): void {
    try {
      const mode = SettingsManager.rec.themeMode;
      if (mode === 1) {
        context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else if (mode === 2) {
        context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else {
        context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
      ThemeManager.applyThemeMode(mode, ThemeManager.isDark ? 0 : 1);
    } catch (e) {
      AppLogger.error('SettingsManager', `applyColorMode failed: ${JSON.stringify(e)}`);
    }
  }

  // ===== 落盘 =====

  /// 防抖落盘（300ms 合并高频变更；崩溃只丢最后一次，不影响既有值）
  private static save(key: string, value: preferences.ValueType): void {
    if (SettingsManager.pref === null) {
      AppLogger.error('SettingsManager', `save(${key}) pref 未初始化——检查 init 顺序！`);
      return;
    }
    try {
      SettingsManager.pref.putSync(key, value);
    } catch (e) {
      AppLogger.error('SettingsManager', `putSync(${key}) failed: ${JSON.stringify(e)}`);
      return;
    }
    if (SettingsManager.saveTimer >= 0) {
      clearTimeout(SettingsManager.saveTimer);
    }
    SettingsManager.saveTimer = setTimeout(() => {
      SettingsManager.saveTimer = -1;
      SettingsManager.saveNow();
    }, 300) as number;
  }

  /// 立即落盘（onBackground/onDestroy 兜底 + 模式切换重启前必须调）
  static saveNow(): void {
    if (SettingsManager.saveTimer >= 0) {
      clearTimeout(SettingsManager.saveTimer);
      SettingsManager.saveTimer = -1;
    }
    try {
      SettingsManager.pref?.flush().catch(() => {});
    } catch (_) {}
  }

  // ===== 沉浸光感材质（ImmersiveMaterial，API ≥ 26）=====
  //
  // 三个铁律（详见 skills/harmony-material-layer）：
  //  ① 材质视觉层级在 backgroundColor / backgroundBlurStyle **之下**
  //     ⇒ 承载材质的那一层必须显式 `Color.Transparent`，否则材质被实色盖住（"放了没反应"）。
  //  ② `systemMaterial` 属性必须放在属性链**最末**。
  //  ③ 材质**不采样同一 Stack 的兄弟节点** —— 想让背景图透进材质，背景图不能与材质层同 Stack。

  /// 沉浸光感是否可用：API ≥ 26（HarmonyOS 6.0 起提供 ImmersiveMaterial）
  static materialAvailable(): boolean {
    return deviceInfo.sdkApiVersion >= 26;
  }

  /// 按场景取 ImmersiveStyle 数值，跟随全局挡位并在该场景建议区间内浮动
  /// ImmersiveStyle：0=ULTRA_THIN 1=THIN 2=REGULAR 3=THICK 4=ULTRA_THICK
  /// 挡位：0=强（材质最薄最透） 1=平衡 2=弱（最厚最磨砂） 10=自适应
  static systemMaterialStyleFor(scope: MaterialScope): number {
    const lv = SettingsManager.materialLevel;
    if (scope === 'sheet') {
      // 弹窗：REGULAR(2) ~ ULTRA_THICK(4)，官方默认 ULTRA_THICK
      return lv === 0 ? 2 : (lv === 1 ? 3 : (lv === 2 ? 4 : 4));
    }
    if (scope === 'menu') {
      // 菜单 / Toast / 卡片：THIN(1) ~ THICK(3)，官方默认 THICK
      return lv === 0 ? 1 : (lv === 1 ? 2 : (lv === 2 ? 3 : 3));
    }
    // 搜索框：ULTRA_THIN(0) ~ REGULAR(2)
    const base = lv === 0 ? 0 : (lv === 1 ? 1 : (lv === 2 ? 2 : 1));
    return SettingsManager.materialColorInvert ? Math.min(base, 1) : base;
  }

  /// 安全构造「指定场景」的材质对象（API<26 返回 undefined）
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

  /// 跟随系统策略的薄材质（官方默认：Navigation 标题栏 ULTRA_THIN、底部页签 THIN）
  static materialSystem(style: number = 1): uiMaterial.ImmersiveMaterial | undefined {
    if (!SettingsManager.materialAvailable()) return undefined;
    return new uiMaterial.ImmersiveMaterial({
      style: style,
      materialColor: Color.Transparent,
      applyShadow: true,
    });
  }

  /// 主色着色材质：用指定主色半透明替代系统深浅着色，让光感底色跟随页面主色调。
  /// 关闭自动反色（前景色由调用方按亮度自控，避免反色门槛与方向不可控）。
  static materialTinted(scope: MaterialScope, tintColor: string): uiMaterial.ImmersiveMaterial | undefined {
    if (!SettingsManager.materialAvailable()) return undefined;
    if (!tintColor || tintColor.length < 7) return SettingsManager.materialFor(scope);
    // 着色透明度 24%（#3D）：太浓像实色块盖住模糊，太淡失去主色辨识度
    const rgb = tintColor.substring(0, 7);
    const a = Math.floor(0.24 * 255).toString(16).padStart(2, '0');
    return new uiMaterial.ImmersiveMaterial({
      style: SettingsManager.systemMaterialStyleFor(scope),
      materialColor: `#${a}${rgb.substring(1)}`,
      colorInvert: false,
      applyShadow: true,
    });
  }

  /// 材质着色（按挡位 + 深浅色）：强=22%（最透） 平衡=35% 弱=50%（最实） 自适应=42%
  static systemMaterialColor(): string {
    const lv = SettingsManager.materialLevel;
    let alpha: string = '6B';
    if (lv === 0) alpha = '38';
    else if (lv === 1) alpha = '59';
    else if (lv === 2) alpha = '80';
    return ThemeManager.isDark ? `#${alpha}000000` : `#${alpha}FFFFFF`;
  }
}
