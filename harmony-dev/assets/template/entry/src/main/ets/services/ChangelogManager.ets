/// 更新日志弹窗管理（2026-08-28）
/// 机制：**每次版本更新弹一次**——用 preferences 存「已查看的 versionCode」，
/// 当前 versionCode 有更新日志 且 未查看过 → 弹窗；用户点击「知道了」→ 记录已查看；
/// 下次版本更新（versionCode 变化）→ 再次弹出。
/// **更新内容外置（外置配置，改日志不改代码）**：读 rawfile/changelog.txt（每次发布前
/// 覆盖写内容，不按版本新增文件）。格式：每行一条，空行/`#` 注释跳过。
import { preferences } from '@kit.ArkData';
import { bundleManager } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import common from '@ohos.app.ability.common';

const PREF_NAME = 'changelog_db';
/// 已查看版本判定：**versionCode（数字递增，比 versionName 可靠）**
const LAST_SEEN_KEY = 'lastSeenVersionCode';
/// 更新日志内容文件（resources/rawfile/changelog.txt，发布前覆盖写）
const CHANGELOG_FILE = 'changelog.txt';

export class ChangelogManager {
  private static pref: preferences.Preferences | null = null;
  /// 当前版本名（UI 显示 v1.0.1 用）
  private static curVersionName: string = '';
  /// 当前 versionCode（弹窗判定用）
  private static curVersionCode: number = 0;
  /// 更新日志条目（init 时从 rawfile 读入，打包内置不变）
  private static entries: string[] = [];

  /// 异步初始化（EntryAbility.onCreate 调用；幂等——pref 已建则跳过）
  static async init(context: common.Context): Promise<void> {
    if (ChangelogManager.pref) return;
    try {
      ChangelogManager.pref = await preferences.getPreferences(context, PREF_NAME);
    } catch (_) {}
    try {
      const flags = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION;
      const data = bundleManager.getBundleInfoForSelfSync(flags);
      ChangelogManager.curVersionName = data.versionName || '';
      ChangelogManager.curVersionCode = data.versionCode || 0;
    } catch (_) {}
    // 读更新日志内容（rawfile/changelog.txt：每行一条，空行/# 注释跳过）
    try {
      const buf = await context.resourceManager.getRawFileContent(CHANGELOG_FILE);
      const decoder = util.TextDecoder.create('utf-8');
      const text = decoder.decodeWithStream(new Uint8Array(buf));
      const list: string[] = [];
      const lines = text.split('\n');
      for (const ln of lines) {
        const t = ln.trim();
        if (!t || t.startsWith('#')) continue;
        list.push(t);
      }
      ChangelogManager.entries = list;
    } catch (_) {}
  }

  /// 当前版本名（UI 显示；init 前调用返回 ''）
  static get currentVersion(): string {
    return ChangelogManager.curVersionName;
  }

  /// 是否应弹更新日志：有更新内容 且 未查看过（markSeen 后同 versionCode 不再弹）
  static shouldShow(): boolean {
    if (ChangelogManager.curVersionCode <= 0) return false;
    if (!ChangelogManager.pref) return false;
    if (ChangelogManager.entries.length === 0) return false;
    const seen = ChangelogManager.pref.getSync(LAST_SEEN_KEY, 0) as number;
    return seen !== ChangelogManager.curVersionCode;
  }

  /// 标记当前版本已查看（点击「知道了」后调用）——下次 versionCode 变化再弹
  static markSeen(): void {
    if (!ChangelogManager.pref || ChangelogManager.curVersionCode <= 0) return;
    try {
      ChangelogManager.pref.putSync(LAST_SEEN_KEY, ChangelogManager.curVersionCode);
      ChangelogManager.pref.flush().catch((e: Error) => {
        console.error('ChangelogManager flush failed: ' + JSON.stringify(e));
      });
    } catch (_) {}
  }

  /// 更新日志条目（rawfile 读取结果；空 = 无内容不弹）
  static get changelogEntries(): string[] {
    return ChangelogManager.entries;
  }
}
