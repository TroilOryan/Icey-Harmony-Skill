/// 组件演示子页（SubPageScaffold 模板：HdsNavDestination + 标题栏滚动模糊 + 设置组件全家桶）
import { SafeArea } from '../../model/SafeArea';
import { ThemeManager } from '../../model/ThemeManager';
import { SubPageScaffold } from '../../components/SubPageScaffold/SubPageScaffold';
import { SettingItem } from '../../components/SettingItem/SettingItem';
import { SettingsGroup, SettingsGroupEntry } from '../../components/SettingsGroup/SettingsGroup';
import { GlassCard } from '../../components/GlassCard/GlassCard';
import { AppSwitch } from '../../components/AppSwitch/AppSwitch';

@Component
export struct HomeDetailPage {
  @State demoSwitch: boolean = true;
  @State demoValue: string = '选项一';

  build() {
    SubPageScaffold({ title: '组件演示' }) {
      List({ space: 16 }) {
        // 子页内容顶部直接是卡片：第一个 ListItem 留白 112（SubPageScaffold 约定）
        ListItem() {
          Row() {}.height(SafeArea.top + 64)
        }

        // 分组导航卡（图标 + chevron）
        ListItem() {
          SettingsGroup({
            entries: [
              { id: 'a', title: '导航项 A', subtitle: '点击跳转子页（AppRouter.push）',
                iconSymbol: $r('sys.symbol.music_note_list'), iconBg: '#0A59F7' },
              { id: 'b', title: '导航项 B', subtitle: '',
                iconSymbol: $r('sys.symbol.speaker_wave_2'), iconBg: '#34C759' },
            ] as SettingsGroupEntry[],
            onEntryTap: (id: string) => {
              // TODO: 分发到对应路由/动作
            },
          })
        }

        // 开关卡（自绘 AppSwitch：系统 Toggle 在本 SDK 有滑块渲染偏移 bug）
        ListItem() {
          GlassCard() {
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

        // 值 + 自定义开关行混合卡
        ListItem() {
          GlassCard() {
            Column({ space: 4 }) {
              SettingItem({
                title: '当前选择',
                subtitle: 'label/value 模式（点击弹 OptionSheet 选择）',
                value: this.demoValue,
                hasChevron: false,
                onTap: () => {
                  // TODO: this.optionSheetController.open()
                },
              })
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
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.Transparent)
    }
  }
}
