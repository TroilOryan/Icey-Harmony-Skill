/// 设置子页标准模板（SubPageScaffold + SettingsGroupCard 分组卡片 + 三类设置项示例）
/// 设置页基础设计逻辑（对齐原工程实战结构）：
/// - 主页（SettingsTab）：SettingsGroup 分组导航卡（点击 AppRouter.push 进子页）+ 少量快捷开关
/// - 子页（本文件）：SubPageScaffold 承载标题栏滚动模糊；内容用 SettingsGroupCard
///   分组（**标题在卡片上方**，区别于 SettingsGroup 的无标题纯导航卡）；
///   项间分割线由调用方手动插入（Divider 0.5 + 左缩进 12）
/// - 开关值链路：@StorageLink 读 AppStorage → onSwitch 调 SettingsManager.setXxx →
///   set 内存 + AppStorage + 防抖落盘（重启保持）
/// - 尾部留白 SafeArea.bottom + 40：List 滚到底不裁切（expandSafeArea 底部延伸配套）
import { SafeArea } from '../../model/SafeArea';
import { ThemeManager } from '../../model/ThemeManager';
import { SettingsManager } from '../../model/SettingsManager';
import { SettingItem } from '../../components/SettingItem/SettingItem';
import { SettingsGroupCard } from '../../components/SettingsGroupCard/SettingsGroupCard';
import { SubPageScaffold } from '../../components/SubPageScaffold/SubPageScaffold';

@Component
export struct SettingsSubPage {
  /// 开关值：@StorageLink 读 AppStorage（SettingsManager 回填/更新，响应式）
  @StorageLink('settings_exampleSwitch') exampleSwitch: boolean = false;
  @StorageLink('settings_handedness') handedness: boolean = false;
  /// 值选择（演示用 @State；持久化值同上用 @StorageLink）
  @State demoValue: string = '选项一';

  build() {
    SubPageScaffold({ title: '设置子页' }) {
      List({ space: 0 }) {
        // 顶部留白：SafeArea.top + 64（状态栏 + MINI 标题栏 + 间距；禁硬编码 112）
        ListItem() {
          Row() {}.height(SafeArea.top + 64).width('100%')
        }

        // 分组一：开关组（带分组标题；项间手动插 Divider）
        ListItem() {
          SettingsGroupCard({ title: '通用' }) {
            Column() {
              SettingItem({
                title: '示例开关',
                subtitle: '持久化开关模板（重启保持）',
                isSwitch: true,
                switchValue: this.exampleSwitch,
                onSwitch: (v: boolean) => {
                  SettingsManager.setExampleSwitch(v);
                },
              })

              Divider()
                .strokeWidth(0.5)
                .color(ThemeManager.colors.divider)
                .margin({ left: 12, right: 8 })

              SettingItem({
                title: '智感握姿',
                subtitle: '底部导航栏跟随握持手自动换边',
                isSwitch: true,
                switchValue: this.handedness,
                onSwitch: (v: boolean) => {
                  SettingsManager.setHandedness(v);
                },
              })
            }
            .width('100%')
          }
        }

        // 分组二：值选择组（label/value 模式，点击弹 OptionSheet/弹窗选择）
        ListItem() {
          SettingsGroupCard({ title: '偏好' }) {
            Column() {
              SettingItem({
                title: '示例选择项',
                subtitle: '点击弹窗选择，当前值显示在右侧',
                value: this.demoValue,
                hasChevron: false,
                onTap: () => {
                  // TODO: OptionSheet / AppSheet 弹窗选择后 set 状态
                  this.demoValue = this.demoValue === '选项一' ? '选项二' : '选项一';
                },
              })
            }
            .width('100%')
          }
        }

        // 分组三：导航组（跳更深层子页/外链）
        ListItem() {
          SettingsGroupCard({ title: '更多' }) {
            Column() {
              SettingItem({
                title: '深层子页',
                subtitle: 'AppRouter.push 再进一层',
                onTap: () => {
                  // TODO: AppRouter.getInstance().push(ROUTE_XXX);
                },
              })
            }
            .width('100%')
          }
        }

        // 尾部留白：滚到底不裁切（List expandSafeArea 底部延伸配套）
        ListItem() {
          Row() {}.height(SafeArea.bottom + 40).width('100%')
        }
      }
      .layoutWeight(1).width('100%')
      .scrollBar(BarState.Off)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor(Color.Transparent)
    }
  }
}
