/// 应用内运行日志（内存环形缓冲 + 手动导出，零运行时 IO）
/// - 记录关键业务事件（info）+ 错误（error），环形限容（MAX_ENTRIES 条，默认 500）
/// - 内存追加 O(1) 无锁，导出时才一次性写文件——**不影响播放/滚动性能**
/// - 同时透传 hilog（开发期 adb / DevEco Log 仍可查）
/// - 导出：DocumentSavePicker 让用户选保存位置（取消/失败回退应用 filesDir，返回实际路径）
/// - **调试模式（2026-08-20）**：开启后每条日志实时追加到公共 Download 目录
///   （Download/包名/app_run_log.txt，DOWNLOAD 模式跳过选择界面）——卡死/崩溃/重启
///   内存缓冲会丢，磁盘日志不丢；失败降级应用 filesDir/logs/
import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo, picker, fileUri } from '@kit.CoreFileKit';
import { bundleManager } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import common from '@ohos.app.ability.common';

const DOMAIN = 0x0000;
const MAX_ENTRIES = 500;
/// 文件日志条目上限（超限 TRUNC 重写当前内存缓冲，防无限膨胀）
const FILE_LOG_MAX_ENTRIES = 3000;

export interface LogEntry {
  /// 时间戳 ms
  time: number;
  /// I / W / E
  level: string;
  tag: string;
  msg: string;
}

export class AppLogger {
  private static entries: LogEntry[] = [];
  private static listeners: Array<(entries: LogEntry[]) => void> = [];

  /// 调试模式开关（UI 状态；启动默认关，会话内有效）
  static debugOn: boolean = false;
  /// 当前文件日志落盘 URI/路径（''=未开启）
  private static fileLogPath: string = '';
  /// 文件日志已写条目数（超限重写）
  private static fileEntryCount: number = 0;
  /// 持久化键（与 SettingsManager 同库 'settings_db'）：调试模式开关，重启保持
  private static readonly DEBUG_PREF_KEY: string = 'debugModeFileLog';
  private static pref: preferences.Preferences | null = null;
  /// 启动恢复标记：onCreate 读到的持久化开状态（picker 页面显示后才可用，延后拉起）
  private static pendingRestore: boolean = false;
  private static appContext: common.Context | null = null;

  /// 启动时读持久化开关：上次开启 → 标记待恢复（页面显示后 applyPendingRestore 拉起）。
  /// 不 await（后台完成）；EntryAbility.onCreate 调用
  static async init(context: common.Context): Promise<void> {
    AppLogger.appContext = context;
    try {
      const p = await preferences.getPreferences(context, 'settings_db');
      AppLogger.pref = p;
      AppLogger.pendingRestore = (p.getSync(AppLogger.DEBUG_PREF_KEY, false) as boolean);
    } catch (_) {}
  }

  /// 页面显示后调用（Index.aboutToAppear 延迟）：恢复上次的调试模式（picker 已可用）
  static applyPendingRestore(): void {
    if (AppLogger.debugOn) return;
    if (AppLogger.pref === null) {
      // init 异步未完成：延迟重试一次
      setTimeout(() => { AppLogger.applyPendingRestore(); }, 1000);
      return;
    }
    if (!AppLogger.pendingRestore) return;
    AppLogger.pendingRestore = false;
    const ctx = AppLogger.appContext;
    if (ctx) {
      AppLogger.startFileLog(ctx).then(() => {}).catch(() => {});
    }
  }

  /// 持久化调试模式开关（重启后保持；写失败静默）
  private static persistDebug(on: boolean): void {
    try {
      if (AppLogger.pref) {
        AppLogger.pref.putSync(AppLogger.DEBUG_PREF_KEY, on);
        AppLogger.pref.flush().catch((e: Error) => {
          console.error('AppLogger persistDebug flush failed: ' + JSON.stringify(e));
        });
      }
    } catch (_) {}
  }

  static info(tag: string, msg: string): void {
    AppLogger.log('I', tag, msg);
  }

  static warn(tag: string, msg: string): void {
    AppLogger.log('W', tag, msg);
  }

  static error(tag: string, msg: string): void {
    AppLogger.log('E', tag, msg);
  }

  private static log(level: string, tag: string, msg: string): void {
    // hilog 透传（保持 adb 可查）
    if (level === 'E') {
      hilog.error(DOMAIN, tag, '%{public}s', msg);
    } else if (level === 'W') {
      hilog.warn(DOMAIN, tag, '%{public}s', msg);
    } else {
      hilog.info(DOMAIN, tag, '%{public}s', msg);
    }
    // 内存环形缓冲（新日志在尾部）
    AppLogger.entries.push({ time: Date.now(), level, tag, msg });
    if (AppLogger.entries.length > MAX_ENTRIES) {
      AppLogger.entries.splice(0, AppLogger.entries.length - MAX_ENTRIES);
    }
    // 通知日志页实时刷新
    for (const l of AppLogger.listeners) {
      try {
        l(AppLogger.entries);
      } catch (_) {}
    }
    // 调试模式：实时落盘（进程被杀不丢；写失败静默不影响主流程）
    if (AppLogger.debugOn && AppLogger.fileLogPath.length > 0) {
      AppLogger.appendFileLog(level, tag, msg);
    }
  }

  /// 开启调试模式：日志实时自动保存到公共下载目录（Download/包名/app_run_log_时间戳.txt）。
  /// **每次启动（startFileLog 调用）都新建时间戳文件**——一次启动→结束一个文件，
  /// 新启动是另一个文件，互不覆盖（重启不沿用旧文件）
  /// 返回落盘位置（''=开启失败，错误已记入内存缓冲，运行日志可见）
  /// **2026-08-20 path 直写方案（绕开 DOWNLOAD save 13900002 限制）**：
  /// Download/<bundleName>/ 的 path 可由 @ohos.file.fs 直接 mkdir/读写（pickDownloadFolder
  /// 已证明），完全不需要 DOWNLOAD save 授权——静默、无系统弹窗、无 13900002
  static async startFileLog(context: common.Context): Promise<string> {
    if (AppLogger.debugOn) return AppLogger.fileLogPath;
    const name = AppLogger.timestampName();
    try {
      const dirPath = AppLogger.downloadDirPath();
      if (!dirPath) {
        AppLogger.error('AppLogger', '调试模式开启失败：无法获取 Download/<包名>/ 路径');
        return '';
      }
      // 幂等建目录（启动时 ensureDownloadDir 已建；这里兜底一次）
      try {
        fileIo.mkdirSync(dirPath, true);
      } catch (_) { /* 已存在 */ }
      const filePath = `${dirPath}/${name}`;
      AppLogger.fileLogPath = filePath;
      AppLogger.fileEntryCount = 0;
      AppLogger.debugOn = true;
      AppLogger.writeText(filePath, AppLogger.buildText());
      AppLogger.appendFileLog('I', 'AppLogger', `调试模式开启，日志实时保存: ${filePath}`);
      AppLogger.persistDebug(true);
      return filePath;
    } catch (e) {
      AppLogger.error('AppLogger', `调试模式开启失败：写入 Download 目录异常 ${JSON.stringify(e)}`);
      AppLogger.debugOn = false;
      return '';
    }
  }

  /// Download/<bundleName>/logs 路径（FileUri('file://docs/...').path = /storage/Users/currentUser/
  /// Download/<bundleName>，@ohos.file.fs 可直接访问——无需 DOWNLOAD save 授权）；
  /// 日志文件统一放 logs 子目录（不平铺在包名根目录）
  private static downloadDirPath(): string {
    try {
      const flags = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
        | bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_METADATA;
      const data = bundleManager.getBundleInfoForSelfSync(flags);
      const uri = 'file://docs/storage/Users/currentUser/Download/' + data.name;
      return new fileUri.FileUri(uri).path + '/logs';
    } catch (e) {
      AppLogger.error('AppLogger', `downloadDirPath failed: ${JSON.stringify(e)}`);
      return '';
    }
  }

  /// 带时间戳的文件名：app_run_log_20260820_103200.txt（每次启动/导出独立文件，避免覆盖）
  private static timestampName(): string {
    const d = new Date();
    const p2 = (n: number): string => n.toString().padStart(2, '0');
    return `app_run_log_${d.getFullYear()}${p2(d.getMonth() + 1)}${p2(d.getDate())}_${p2(d.getHours())}${p2(d.getMinutes())}${p2(d.getSeconds())}.txt`;
  }

  /// 关闭调试模式：停止落盘（文件保留），持久化关闭
  static stopFileLog(): void {
    AppLogger.debugOn = false;
    AppLogger.fileLogPath = '';
    AppLogger.fileEntryCount = 0;
    AppLogger.persistDebug(false);
  }

  /// 当前落盘位置（UI 展示用）
  static get fileLogLocation(): string {
    return AppLogger.fileLogPath;
  }

  /// 追加一条到文件日志；条目超限 → TRUNC 重写当前内存缓冲（防无限膨胀）
  private static appendFileLog(level: string, tag: string, msg: string): void {
    try {
      if (AppLogger.fileEntryCount >= FILE_LOG_MAX_ENTRIES) {
        AppLogger.writeText(AppLogger.fileLogPath, AppLogger.buildText());
        AppLogger.fileEntryCount = AppLogger.entries.length;
      }
      const line = `[${new Date().toLocaleTimeString()}] [${level}] [${tag}] ${msg}\n`;
      const file = fileIo.openSync(AppLogger.fileLogPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.APPEND);
      try {
        fileIo.writeSync(file.fd, line);
        AppLogger.fileEntryCount++;
      } finally {
        fileIo.closeSync(file);
      }
    } catch (_) {
      // 写失败静默（不影响主流程；下次开启时重新初始化）
    }
  }

  /// 全部缓冲日志（新→旧遍历倒序展示）
  static getEntries(): LogEntry[] {
    return AppLogger.entries;
  }

  /// 订阅日志变化（日志页实时刷新；返回取消函数）
  static subscribe(l: (entries: LogEntry[]) => void): () => void {
    AppLogger.listeners.push(l);
    return () => {
      const i = AppLogger.listeners.indexOf(l);
      if (i >= 0) AppLogger.listeners.splice(i, 1);
    };
  }

  /// 清空缓冲（调试用）
  static clear(): void {
    AppLogger.entries = [];
    for (const l of AppLogger.listeners) {
      try {
        l(AppLogger.entries);
      } catch (_) {}
    }
  }

  /// 导出日志：DocumentViewPicker.save 选保存位置 → 写文本文件；取消/失败回退 filesDir。
  /// 文件名带时间戳（避免重复导出覆盖）。返回导出路径（空串=失败）
  static async exportToFile(context: common.Context): Promise<string> {
    try {
      const text = AppLogger.buildText();
      const name = AppLogger.timestampName();
      // 用户选保存位置（SDK 无 DocumentSavePicker 类，DocumentViewPicker 自带 save()）
      const savePicker = new picker.DocumentViewPicker(context as common.UIAbilityContext);
      const result = await savePicker.save({ newFileNames: [name] });
      if (!result || result.length === 0) return '';
      const uri = result[0];
      AppLogger.writeText(uri, text);
      return uri;
    } catch (e) {
      // 回退：写应用 filesDir（路径可后续 adb pull / 用户自行查看）
      try {
        const ctx = context as common.UIAbilityContext;
        const path = `${ctx.filesDir}/${AppLogger.timestampName()}`;
        AppLogger.writeText(path, AppLogger.buildText());
        return path;
      } catch (e2) {
        console.error('AppLogger export fallback failed: ' + JSON.stringify(e2));
        return '';
      }
    }
  }

  private static buildText(): string {
    let text = '应用运行日志\n';
    text += `导出时间: ${new Date().toLocaleString()}\n`;
    text += `条目数: ${AppLogger.entries.length}（环形缓冲上限 ${MAX_ENTRIES}，旧日志会被覆盖）\n`;
    text += `${'='.repeat(48)}\n`;
    for (const e of AppLogger.entries) {
      const t = new Date(e.time);
      const ts = `${t.getHours().toString().padStart(2, '0')}:${t.getMinutes().toString().padStart(2, '0')}:${t.getSeconds().toString().padStart(2, '0')}.${t.getMilliseconds().toString().padStart(3, '0')}`;
      text += `[${ts}] [${e.level}] [${e.tag}] ${e.msg}\n`;
    }
    return text;
  }

  private static writeText(uriOrPath: string, text: string): void {
    const file = fileIo.openSync(uriOrPath,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    fileIo.writeSync(file.fd, text);
    fileIo.closeSync(file);
  }
}
