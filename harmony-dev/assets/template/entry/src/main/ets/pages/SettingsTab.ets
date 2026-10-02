/// 设置 tab（分组卡片样式，对齐官方 NavigationSettings：分组圆角卡片 + 项间分隔线 +
/// 圆形图标 + chevron 箭头；含开关/值选择/子页路由三类交互模板）
import { SafeArea } from '../model/SafeArea';
import { ThemeManager } from '../model/ThemeManager';
import { SettingsManager, ThemeMode } from '../model/SettingsManager';
import { AppRouter, ROUTE_SETTINGS_SUB, ROUTE_ABOUT } from '../model/AppRouter';
import { SettingsGroup, SettingsGroupEntry } from '../components/SettingsGroup/SettingsGroup';
import { SettingItem } from '../components/SettingItem/SettingItem';
import { GlassCard } from '../components/GlassCard/GlassCard';

@Component
export struct SettingsTab {
  @Prop themeVersion: number = 0;
  /// 示例开关（SettingsManager 持久化 → AppStorage 响应式）
  @StorageLink('settings_exampleSwitch') exampleSwitch: boolean = false;
  /// 沉浸光感材质挡位（0强/1平衡/2弱/10自适应）
  @StorageLink('settings_materialLevel') materialLevel: number = 10;
  private scroller: Scroller = new Scroller();

  /// aboutToAppear 复位到顶部：Hds GRADIENT_BLUR 滚动模糊对内容短的设置页，
  /// 若停留在非顶部位置模糊带会常显（"没滚动也模糊"）——切回本页时复位
  aboutToAppear(): void {
    try {
      this.scroller.scrollToIndex(0, true);
    } catch (_) {}
  }

  /// 材质挡位显示文本
  private materialLabel(): string {
    switch (this.materialLevel) {
      case 0: return '强';
      case 1: return '平衡';
      case 2: return '弱';
      default: return '自适应';
    }
  }

  build() {
    Column() {
      List({ scroller: this.scroller, space: 16 }) {
        // 顶部留白（避让标题栏；内容滚动后自然滑进模糊带）
        ListItem() {
          Row() {}.height(SafeArea.top + 64)
        }

        // 通用组（子页路由模板）
        ListItem() {
          SettingsGroup({
            entries: [
              { id: 'sub', title: '子页设置模板', subtitle: 'SubPageScaffold + 设置项全家桶',
                iconSymbol: $r('sys.symbol.paintpalette'), iconBg: '#0A59F7' },
              { id: 'about', title: '关于', subtitle: '版本 / 更新日志 / 运行日志',
                iconSymbol: $r('sys.symbol.info_circle'), iconBg: '#8E8E93' },
            ] as SettingsGroupEntry[],
            onEntryTap: (id: string) => {
              if (id === 'sub') {
                AppRouter.getInstance().push(ROUTE_SETTINGS_SUB);
              } else if (id === 'about') {
                AppRouter.getInstance().push(ROUTE_ABOUT);
              }
            },
          })
        }

        // 开关组（持久化模板：set → 防抖落盘 → AppStorage 响应式）
        ListItem() {
          GlassCard() {
            Column() {
              SettingItem({
                title: '示例开关',
                subtitle: '持久化设置模板（重启保持）',
                isSwitch: true,
                switchValue: this.exampleSwitch,
                onSwitch: (v: boolean) => {
                  SettingsManager.setExampleSwitch(v);
                },
              })
            }
            .width('100%')
          }
        }

        // 值选择组（label/value 模板）
        ListItem() {
          GlassCard() {
            Column() {
              SettingItem({
                title: '沉浸光感材质',
                subtitle: '导航栏/标题栏材质挡位',
                value: this.materialLabel(),
                hasChevron: false,
                onTap: () => {
                  // 演示：循环切换挡位（实际项目用 OptionSheet 弹窗选择）
                  const next = this.materialLevel >= 10 ? 0 : this.materialLevel + 1;
                  SettingsManager.setMaterialLevel(next);
                },
              })
            }
            .width('100%')
          }
        }

        // 尾部留白：滚到底不裁切（barOverlap 悬浮 tabBar 遮挡底部内容，多留一屏余量）
        ListItem() {
          Row() {}.height(SafeArea.bottom + 80).width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor(Color.Transparent)
      // ListItem 左右 padding（SettingsGroup margin 由父容器控制）
      .padding({ left: 16, right: 16 })
    }
    .layoutWeight(1)
    .width('100%')
    .backgroundColor(Color.Transparent)
  }
}
