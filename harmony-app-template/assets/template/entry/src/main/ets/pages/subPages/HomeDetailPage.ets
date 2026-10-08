/// 组件演示子页（SubPageScaffold 模板：HdsNavDestination + 标题栏滚动模糊 + 设置组件全家桶）
///
/// ⚠️ 子页卡片一律用 `SettingsGroupCard`（**自带左右 16**），因此：
///   · List **不设左右 padding**（否则双倍内缩 32vp）
///   · 顶部留白 `SafeArea.top + 72`
///   · 卡内分割线用 `cardDivider`，末项之后不插 Divider
/// 主页的 `SettingsGroup` 反过来：左右边距**由父容器 padding 控制**，两者不要混用。
///
/// ⚠️ 图标契约：新的 `SettingItem` / `SettingsGroupEntry` 用 **SFIcon SVG 名**（`icon: string`，
///   如 `SFIcons.sf_tab_settings`），**不是** 旧的 `iconSymbol: $r('sys.symbol.*')`。
///   SVG 资源在 `resources/base/media/*.svg`，由 `SFIcon` 组件 `Image($r('app.media.<name>'))` 渲染。
import { SafeArea } from '../../model/SafeArea';
import { ThemeManager } from '../../model/ThemeManager';
import { SubPageScaffold } from '../../components/SubPageScaffold/SubPageScaffold';
import { SettingItem } from '../../components/SettingItem/SettingItem';
import { SettingsGroupCard } from '../../components/SettingsGroupCard/SettingsGroupCard';
import { SFIcons } from '../../components/SFIcon/SFIcon';
import { AppSwitch } from '../../components/AppSwitch/AppSwitch';

@Component
export struct HomeDetailPage {
  @State demoSwitch: boolean = true;
  @State demoValue: string = '选项一';

  build() {
    SubPageScaffold({ title: '组件演示' }) {
      List({ space: 16 }) {
        // 子页顶部留白：SafeArea.top + 72（状态栏 + MINI 标题栏 + 间距）
        ListItem() {
          Row() {}.height(SafeArea.top + 72)
        }

        // 分组一：导航项（图标 + chevron）
        ListItem() {
          SettingsGroupCard({ title: '导航' }) {
            Column() {
              SettingItem({
                title: '导航项 A',
                subtitle: '点击跳转子页（AppRouter.push）',
                icon: SFIcons.sf_music_note_square_stack,
                iconBg: '#0A59F7',
                onTap: () => {
                  // TODO: AppRouter.getInstance().push(ROUTE_XXX);
                },
              })

              Divider()
                .strokeWidth(0.5)
                .color(ThemeManager.colors.cardDivider)
                .margin({ left: 12, right: 8 })

              SettingItem({
                title: '导航项 B',
                subtitle: '无副标题的项',
                icon: SFIcons.sf_opticaldisc,
                iconBg: '#34C759',
              })
            }
            .width('100%')
          }
        }

        // 分组二：开关（自绘 AppSwitch：系统 Toggle 在本 SDK 有滑块渲染偏移 bug）
        ListItem() {
          SettingsGroupCard({ title: '开关' }) {
            Column() {
              SettingItem({
                title: '示例开关',
                subtitle: 'AppSwitch 自绘开关（200ms 滑动动画）',
                isSwitch: true,
                switchValue: this.demoSwitch,
                onSwitch: (v: boolean) => {
                  this.demoSwitch = v;
                },
              })
            }
            .width('100%')
          }
        }

        // 分组三：值 + 独立开关行混合
        ListItem() {
          SettingsGroupCard({ title: '混合' }) {
            Column() {
              SettingItem({
                title: '当前选择',
                subtitle: 'label/value 模式（点击弹 OptionSheet 选择）',
                value: this.demoValue,
                hasChevron: false,
                onTap: () => {
                  // TODO: this.optionSheetController.open()
                },
              })

              Divider()
                .strokeWidth(0.5)
                .color(ThemeManager.colors.cardDivider)
                .margin({ left: 12, right: 8 })

              Row() {
                Text('独立 AppSwitch 行')
                  .fontSize(16)
                  .fontColor(ThemeManager.colors.textPrimary)
                  .layoutWeight(1)
                AppSwitch({
                  isOn: this.demoSwitch,
                  onToggle: (v: boolean) => { this.demoSwitch = v; },
                })
              }
              .width('100%')
              .constraintSize({ minHeight: 48 })
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            }
            .width('100%')
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      // ⚠️ List 不设左右 padding（SettingsGroupCard 自带 16）
      .backgroundColor(Color.Transparent)
    }
  }
}
