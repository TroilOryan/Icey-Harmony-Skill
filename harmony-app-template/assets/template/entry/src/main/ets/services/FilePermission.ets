/// 文件授权管理（持久化 + 重启激活）
/// fileShare API 限制：单次 policies 上限 500 条，超过报错；
/// 部分 URI 失败时 API 返回 13900001 + err.data（逐 URI 错误详情），需分批 + 检查 err.data。
/// 之前一次性传全部 URI 且静默吞错 → 大量歌曲时 persist/activate 全失败 → 重启后 EPERM。
import { fileShare } from '@kit.CoreFileKit';
import { fileUri } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppLogger } from './AppLogger';

/// 单批最大条数（API 上限 500，留余量用 200）
const BATCH_SIZE = 200;
/// 失败明细最多打 N 条（359 首全失败曾刷 359 条 E 日志占满环形缓冲，淹没其他日志）
const MAX_FAIL_LOG = 5;

/// 直接路径 → 文档 URI（fileShare 需要 file://docs/... 格式；mediaList 存的是 /storage/... 直接路径，
/// 直接传会 code=3 Invalid path 全部失败——2026-08-21 日志定位：启动恢复 359 首 activate 全失败）
function toDocUri(uri: string): string {
  if (uri.startsWith('file://')) return uri;
  if (uri.startsWith('/storage/')) {
    try {
      return fileUri.getUriFromPath(uri);
    } catch (_) {
      return uri;
    }
  }
  return uri;
}

export class FilePermission {
  /// **启动全量激活完成标志（2026-08-27 播控意图续播等待用）**：executor 后台冷启动续播可能
  /// 早于 FilePermission.activate（restoreEnrichment fire-and-forget）完成 → openSync 401
  /// SetSource failed（日志实证）→ 续播失败。resumePlaybackForIntent 等此标志再播。
  /// MediaScanner.restoreEnrichment 调 setActivateDonePromise(activate(uris))。
  private static activateDonePromise: Promise<void> | null = null;

  static setActivateDonePromise(p: Promise<void>): void {
    FilePermission.activateDonePromise = p;
  }

  /// 等待启动全量激活完成（未开始则立即返回——由调用方结合 restorePlayDone 保证时序）
  static waitActivateDone(): Promise<void> {
    return FilePermission.activateDonePromise ?? Promise.resolve();
  }

  /// 持久化 URI 列表的读权限（分批）
  static async persist(uris: string[]): Promise<void> {
    if (uris.length === 0) return;
    if (!canIUse('SystemCapability.FileManagement.AppFileService.FolderAuthorization')) {
      AppLogger.error('FilePermission', 'persist 跳过: 设备不支持 FolderAuthorization');
      return;
    }
    let success = 0;
    const failed: string[] = [];
    for (let i = 0; i < uris.length; i += BATCH_SIZE) {
      const batch = uris.slice(i, i + BATCH_SIZE);
      const policies: fileShare.PolicyInfo[] = [];
      for (const uri of batch) {
        const p: fileShare.PolicyInfo = {
          uri: toDocUri(uri),
          operationMode: fileShare.OperationMode.READ_MODE,
        };
        policies.push(p);
      }
      try {
        await fileShare.persistPermission(policies);
        success += batch.length;
      } catch (e) {
        const err = e as BusinessError<Array<fileShare.PolicyErrorResult>>;
        const batchNum = Math.floor(i / BATCH_SIZE) + 1;
        if (err.code === 13900001 && err.data && err.data.length > 0) {
          // 部分失败：err.data 列出失败 URI，其余已成功持久化；明细限量（防刷屏）
          const failedSet = new Set<string>();
          const detail = err.data.slice(0, MAX_FAIL_LOG);
          for (const item of detail) {
            failedSet.add(item.uri);
            AppLogger.error('FilePermission',
              `persist#${batchNum} 失败 uri=${item.uri} code=${item.code} msg=${item.message}`);
          }
          if (err.data.length > MAX_FAIL_LOG) {
            AppLogger.error('FilePermission',
              `persist#${batchNum} 另有 ${err.data.length - MAX_FAIL_LOG} 条失败（明细省略）`);
          }
          success += batch.length - err.data.length;
          failed.push(...err.data.map((d: fileShare.PolicyErrorResult) => d.uri));
        } else {
          // 整批失败
          AppLogger.error('FilePermission',
            `persist#${batchNum} 整批失败 code=${err.code} msg=${err.message}`);
          failed.push(...batch);
        }
      }
    }
    AppLogger.info('FilePermission',
      `persist 完成: ${success}/${uris.length} 成功${failed.length > 0 ? `, ${failed.length} 失败` : ''}`);
  }

  /// 播放前按需确保单 URI 权限（2026-08-12 兜底：导入 >500 首时批量 persist/activate 可能部分失败，
  /// 播放时 13900001 EPERM——播放路径（AudioEngine.setSource 的 openSync）加此确保，
  /// activate 失败（如从未持久化）则重新 persist+activate）
  static async ensureActive(uri: string): Promise<void> {
    if (!canIUse('SystemCapability.FileManagement.AppFileService.FolderAuthorization')) return;
    try {
      await FilePermission.activate([uri]);
      return;
    } catch (e) {
      // activate 失败（如 PERMISSION_NOT_PERSISTED=4 从未持久化）→ 重新 persist + activate 兜底
      try {
        await FilePermission.persist([uri]);
        await FilePermission.activate([uri]);
      } catch (e2) {
        AppLogger.error('FilePermission', `ensureActive 失败 uri=${uri}: ${String(e2)}`);
      }
    }
  }

  /// 重启后激活持久化权限（分批）
  static async activate(uris: string[]): Promise<void> {
    if (uris.length === 0) return;
    if (!canIUse('SystemCapability.FileManagement.AppFileService.FolderAuthorization')) {
      AppLogger.error('FilePermission', 'activate 跳过: 设备不支持 FolderAuthorization');
      return;
    }
    let success = 0;
    const failed: string[] = [];
    for (let i = 0; i < uris.length; i += BATCH_SIZE) {
      const batch = uris.slice(i, i + BATCH_SIZE);
      const policies: fileShare.PolicyInfo[] = [];
      for (const uri of batch) {
        const p: fileShare.PolicyInfo = {
          uri: toDocUri(uri),
          operationMode: fileShare.OperationMode.READ_MODE,
        };
        policies.push(p);
      }
      try {
        await fileShare.activatePermission(policies);
        success += batch.length;
      } catch (e) {
        const err = e as BusinessError<Array<fileShare.PolicyErrorResult>>;
        const batchNum = Math.floor(i / BATCH_SIZE) + 1;
        if (err.code === 13900001 && err.data && err.data.length > 0) {
          // 部分失败：err.data 列出失败 URI（如 PERMISSION_NOT_PERSISTED=4 表示从未持久化）；
          // 明细限量（防刷屏——359 首全失败曾刷 359 条 E 日志）
          const detail = err.data.slice(0, MAX_FAIL_LOG);
          for (const item of detail) {
            AppLogger.error('FilePermission',
              `activate#${batchNum} 失败 uri=${item.uri} code=${item.code} msg=${item.message}`);
          }
          if (err.data.length > MAX_FAIL_LOG) {
            AppLogger.error('FilePermission',
              `activate#${batchNum} 另有 ${err.data.length - MAX_FAIL_LOG} 条失败（明细省略）`);
          }
          success += batch.length - err.data.length;
          failed.push(...err.data.map((d: fileShare.PolicyErrorResult) => d.uri));
        } else {
          // 整批失败
          AppLogger.error('FilePermission',
            `activate#${batchNum} 整批失败 code=${err.code} msg=${err.message}`);
          failed.push(...batch);
        }
      }
    }
    AppLogger.info('FilePermission',
      `activate 完成: ${success}/${uris.length} 成功${failed.length > 0 ? `, ${failed.length} 失败` : ''}`);
  }
}
