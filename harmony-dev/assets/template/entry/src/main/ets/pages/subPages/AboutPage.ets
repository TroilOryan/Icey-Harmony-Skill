/// 关于页模板：版本号 + 更新日志入口 + 运行日志（调试模式）入口
import { SafeArea } from '../../model/SafeArea';
import { ThemeManager } from '../../model/ThemeManager';
import { SubPageScaffold } from '../../components/SubPageScaffold/SubPageScaffold';
import { SettingItem } from '../../components/SettingItem/SettingItem';
import { GlassCard } from '../../components/GlassCard/GlassCard';
import { AppLogger, LogEntry } from '../../services/AppLogger';
import { ChangelogManager } from '../../services/ChangelogManager';
import { SheetContainer } from '../../components/SheetContainer/SheetContainer';
import { bundleManager } from '@kit.AbilityKit';

@Component
export struct AboutPage {
  @State versionName: string = '';
  /// 运行日志弹窗
  @State showLogSheet: boolean = false;
  /// 日志实时刷新（subscribe 返回取消函数）
  private unsubLog: (() => void) | null = null;
  @State logText: string = '';

  aboutToAppear(): void {
    try {
      const data = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      this.versionName = data.versionName || '';
    } catch (_) {}
    // 日志订阅（弹窗打开时实时刷新；LogViewer 简化为文本展示，复杂需求参考同类实现）
    this.unsubLog = AppLogger.subscribe((entries: LogEntry[]) => {
      const lines: string[] = [];
      for (const e of entries.slice(-50)) {
        const t = new Date(e.time);
        const ts = `${t.getHours().toString().padStart(2, '0')}:${t.getMinutes().toString().padStart(2, '0')}:${t.getSeconds().toString().padStart(2, '0')}`;
        lines.push(`[${ts}][${e.level}][${e.tag}] ${e.msg}`);
      }
      this.logText = lines.join('\n');
    });
  }

  aboutToDisappear(): void {
    if (this.unsubLog) {
      this.unsubLog();
      this.unsubLog = null;
    }
  }

  build() {
    // Stack 承载 bindSheet：bindSheet 是原生组件方法，挂在自定义组件（SubPageScaffold）上
    // 会被解析成两个根节点 / 找不到成员，编译报错（LSN-024 同批实证）
    Stack() {
    SubPageScaffold({ title: '关于' }) {
      List({ space: 16 }) {
        ListItem() {
          Row() {}.height(SafeArea.top + 64)
        }

        ListItem() {
          GlassCard() {
            Column() {
              SettingItem({
                title: '版本',
                value: this.versionName || '1.0.0',
                hasChevron: false,
              })
              SettingItem({
                title: '更新日志',
                subtitle: ChangelogManager.changelogEntries.length > 0
                  ? ChangelogManager.changelogEntries[0] : '暂无更新日志',
                onTap: () => {
                  // TODO: 接 ChangelogSheetHost 展示完整更新日志（Index 级弹窗）
                },
              })
              SettingItem({
                title: '运行日志',
                subtitle: AppLogger.fileLogLocation || '开启调试模式后实时落盘',
                onTap: () => {
                  this.showLogSheet = true;
                },
              })
            }
            .width('100%')
          }
        }
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.Transparent)
    }
    }
    // 运行日志弹窗（bindSheet 挂在上面的原生 Stack 上）
    .bindSheet(this.showLogSheet, this.logSheetBuilder, {
        detents: [SheetSize.FIT_CONTENT, SheetSize.LARGE],
        dragBar: false,
        showClose: true,
        backgroundColor: ThemeManager.opaqueBackground,
        shouldDismiss: (d: SheetDismiss) => {
          this.showLogSheet = false;
          d.dismiss();
        },
      })
  }

  @Builder
  logSheetBuilder() {
    SheetContainer({ title: '运行日志' }) {
      Scroll() {
        Text(this.logText || '暂无日志')
          .fontSize(12)
          .fontColor(ThemeManager.colors.textSecondary)
          .width('100%')
          .padding(12)
      }
      .constraintSize({ maxHeight: 400 })
      .scrollBar(BarState.Auto)
    }
  }
}
