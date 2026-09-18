/// 设置管理（持久化到 @kit.ArkData preferences——系统级键值存储，增量写 + 原子性）
/// 通用骨架：新增设置项三步——
///   ① 加 KEY 常量 + SettingsRecord 字段 + 默认值
///   ② init 的 waitReady 后回填 AppStorage（UI @StorageLink 响应式）
///   ③ 加 setter（set + save() 防抖落盘）
/// 落盘策略：save() 防抖 300ms 合并高频变更；onBackground/onDestroy 调 saveNow() 强制落盘
/// （防抖未到期就杀进程 → 设置丢失，必须双保险）
import { preferences } from '@kit.ArkData';
import { ConfigurationConstant } from '@kit.AbilityKit';
import common from '@ohos.app.ability.common';
import { ThemeManager } from './ThemeManager';
import { AppLogger } from '../services/AppLogger';

const PREF_NAME = 'settings_db';
/// 示例键（按需增删）
const EXAMPLE_SWITCH_KEY = 'settings_exampleSwitch';
const HANDEDNESS_KEY = 'settings_handedness';
const MATERIAL_LEVEL_KEY = 'settings_materialLevel';
const THEME_MODE_KEY = 'settings_themeMode';
const VERSION_KEY = 'version';

/// 主题模式枚举
export enum ThemeMode {
  Follow = 0,
  Light = 1,
  Dark = 2,
}

interface SettingsRecord {
  exampleSwitch: boolean;
  /// 智感握姿（底部导航栏跟随握持手方向镜像）
  handedness: boolean;
  /// 沉浸光感材质挡位（0强/1平衡/2弱/10自适应，Hds systemMaterialEffect.materialLevel）
  materialLevel: number;
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
    themeMode: 0,
  };
  /// 防抖定时器
  private static saveTimer: number = -1;

  // ===== 内存态 getter（同步；UI 响应式读 AppStorage 键，UI 层用 @StorageLink）=====

  static get exampleSwitch(): boolean { return SettingsManager.rec.exampleSwitch; }
  static get materialLevel(): number { return SettingsManager.rec.materialLevel; }
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
}
